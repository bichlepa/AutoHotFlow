#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Time.ahk
#Include ..\elements\base\ExecContext.ahk
#Include ..\elements\base\ParamEvaluator.ahk

; Context of one worker execution (WI-11, ELEMENT-API-V2 section 3). It is the ExecContext of the engine without the
; variables of the engine: the worker holds none. Finish, After, State, Log and CheckVarName work as in the engine.
;
; Parameters (E26, WI-42): the engine evaluated them before it sent the job (evaluated: an Array of Maps {id, value}
; or {id, error} in the order of Parameters()). EvalParams and EvalMoreParams return these values and throw at the
; first error of a parameter that is asked for.
;
; Variables (WI-50, ARCHITECTURE R4, doc/PROTOCOL.md 4.5 "Variable requests"): every variable function asks the engine
; (cmd.engine.var.*, with the execId of the job) and waits for the answer, blocking: the worker is its own process, it
; may wait; the engine answers at once and never waits for a worker. The engine runs the same function with the
; context of the element, so the result is the one the element would get inline. One request per call; nothing is
; cached, so a variable that another thread changes is seen at the next call (M-45). Without an answer within
; REQUEST_TIMEOUT_MS (or when the engine went away, peer_gone) the function throws ElementError "engine did not
; answer"; when the job has ended or was stopped (gone) it throws as well, which ends the element.
;
; Waiting: a loop of Sleep(WAIT_STEP_MS). AHK runs the wake-up message of the pipe and the timers of the peer in new
; threads during Sleep, so the answer arrives while this thread waits. That only works when the wait does not run
; inside the pump of the connection (its re-entry guard would hold the answer back): ctx.Request therefore calls its
; callback on a timer thread of its own, never from the pump (doc/HOW-TO.md).
;
; imports and exports: imports are an explicit import list (empty from the engine since WI-50, reserved for
; ctx.RunScript, S8) read with GetImport; Export sets a value that the engine stores when the job ends.
;
; requestFn(to, type, payload, callback, timeoutMs) sends a request (Peer.Request of the worker). onFinish(ctx, result,
; msg) is set by Worker (see ExecContext).
class WorkerContext extends ExecContext {
    static REQUEST_TIMEOUT_MS := 5000   ; the engine answers at once; this is the bound for a frozen or busy engine
    static WAIT_STEP_MS := 50           ; longest single wait for a message in the wait loop (_WaitForMessages)
    static WAIT_SLACK_MS := 2000        ; the loop gives up this long after the request timeout (the peer ends it first)

    __New(flowId, elementId, instanceId, threadId, imports, onFinish := "", evaluated := "", execId := "", requestFn := "") {
        super.__New(flowId, elementId, instanceId, threadId, onFinish)
        this.imports := WorkerContext._Map(imports)
        this.exports := WorkerContext._Map("")
        this.evaluated := (evaluated is Array) ? evaluated : []
        this.execId := execId
        this.stopped := false            ; set by Worker when the job is cancelled
        this._requestFn := requestFn
    }

    ; Reads an imported value (an explicit import list). Returns default when it was not imported.
    GetImport(name, default := "") {
        return this.imports.Get(name, default)
    }

    ; Sets an exported value. The engine receives it in evt.worker.done and stores it where its name says.
    Export(name, value) {
        if (IsObject(value))
            throw ElementError("Export: value of '" name "' must be a text or a number")
        this.exports[name] := value
    }

    ; The parameters that the engine evaluated (E26), without the ids in skipList. Throws ElementError at the first
    ; parameter with an error that is not skipped.
    EvalParams(params, skipList := "") {
        return this._FromEvaluated({}, ParamEvaluator.NameSet(skipList), "")
    }

    ; The parameters names (Array or text with commas) from what the engine evaluated, added to evaluated.
    EvalMoreParams(evaluated, params, names) {
        return this._FromEvaluated(IsObject(evaluated) ? evaluated : {}, ParamEvaluator.NameSet(""), ParamEvaluator.NameSet(names))
    }

    _FromEvaluated(out, skip, only) {
        for entry in this.evaluated {
            if (!(entry is Map) || !entry.Has("id"))
                continue
            id := String(entry["id"])
            if (skip.Has(id) || (IsObject(only) && !only.Has(id)))
                continue
            if (entry.Has("error"))
                throw ElementError(String(entry["error"]))
            out.%id% := WorkerContext.FromWire(entry.Has("value") ? entry["value"] : "")
        }
        return out
    }

    ; ---- variables through the engine (WI-50) ------------------------------------------------------------------------

    GetVar(name, default := "", hidden := false) {
        p := this._Ask("get", Map("name", String(name), "hidden", Json.Bool(hidden)))
        return p.Get("exists", 0) ? WorkerContext.FromWire(p.Get("value", "")) : default
    }

    GetVarType(name, hidden := false) {
        return String(this._Ask("get", Map("name", String(name), "hidden", Json.Bool(hidden))).Get("type", ""))
    }

    GetVarLocation(name, hidden := false) {
        return String(this._Ask("get", Map("name", String(name), "hidden", Json.Bool(hidden))).Get("location", ""))
    }

    SetVar(name, value, scope := "", hidden := false) {
        p := this._Ask("set", Map("name", String(name), "value", WorkerContext.ToWire(value), "scope", String(scope)
            , "hidden", Json.Bool(hidden)))
        return p.Get("accepted", 0) ? 1 : 0
    }

    DeleteVar(name, hidden := false) {
        return this._Ask("delete", Map("name", String(name), "hidden", Json.Bool(hidden))).Get("existed", 0) ? 1 : 0
    }

    ListVars(scope := "") {
        names := this._Ask("list", Map("scope", String(scope))).Get("names", "")
        return (names is Array) ? names : []
    }

    ReplaceVariables(text, convertObjects := false) {
        return String(this._Ask("replace", Map("text", String(text), "convertObjects", Json.Bool(convertObjects)))
            .Get("text", ""))
    }

    EvaluateExpression(text) {
        return WorkerContext.FromWire(this._Ask("eval", Map("text", String(text), "kind", "expression")).Get("value", ""))
    }

    EvaluateScript(text) {
        return WorkerContext.FromWire(this._Ask("eval", Map("text", String(text), "kind", "script")).Get("value", ""))
    }

    ExportInstanceVars() {
        p := this._Ask("list", Map("scope", "instance", "withValues", Json.True))
        values := p.Get("values", "")
        return WorkerContext._Map((values is Map) ? values : "")
    }

    ImportInstanceVars(vars) {
        if (!(vars is Map))
            throw ElementError("ImportInstanceVars needs a Map of name -> value")
        wire := Map()
        for name, value in vars
            wire[String(name)] := WorkerContext.ToWire(value)
        this._Ask("import", Map("vars", wire))
    }

    ; Sends a cmd.* request to the engine with the execId of the job (unless the payload has one) and returns at once.
    ; callback(answerPayload) runs later on a timer thread of its own (so it may call the variable functions), not at
    ; all when the element has ended or was stopped by then. An exception in the callback ends the element with
    ; "exception". Returns the id of the request.
    Request(type, payload, callback, timeoutMs := 5000) {
        fn := this._requestFn
        if (!IsObject(fn))
            throw ElementError("Request: this context has no connection to the engine")
        if (SubStr(type, 1, 4) != "cmd.")
            throw ElementError("Request: '" type "' is not a cmd.* request")
        if (!IsObject(callback))
            throw ElementError("Request: callback is not a function object")
        if (!(payload is Map))
            payload := Map()
        if (!payload.Has("execId"))
            payload["execId"] := this.execId
        try {
            return fn("engine", type, payload, ObjBindMethod(this, "_OnRequestAnswer", callback), timeoutMs)
        } catch as e {
            throw ElementError("Request: " type " could not be sent: " e.Message)
        }
    }

    _OnRequestAnswer(callback, res) {
        SetTimer(ObjBindMethod(this, "_RunRequestCallback", callback, res.payload), -1)
    }

    _RunRequestCallback(callback, payload) {
        if (this.finished || this.stopped)
            return
        try {
            callback(payload)
        } catch as e {
            this.Finish("exception", e.Message)
        }
    }

    ; One variable request to the engine, waiting for its answer. Returns the payload of an ok answer; throws
    ; ElementError for an error of the request, for no answer, and with the text of the engine for an error of the
    ; operation (elementError, the text the inline function throws).
    _Ask(op, payload) {
        fn := this._requestFn
        if (!IsObject(fn) || this.execId = "")
            throw ElementError("variables are not available here: the worker context has no connection to the engine")
        type := "cmd.engine.var." op
        payload["execId"] := this.execId
        timeoutMs := WorkerContext.REQUEST_TIMEOUT_MS
        box := {done: false, res: ""}
        try {
            fn("engine", type, payload, WorkerContext._Catcher(box), timeoutMs)
        } catch as e {
            throw ElementError("engine did not answer: " type " could not be sent (" Type(e) ": " e.Message ")")
        }
        limit := Time.NowMs() + timeoutMs + WorkerContext.WAIT_SLACK_MS
        while (!box.done) {
            if (Time.NowMs() > limit)
                throw ElementError("engine did not answer " type " within " timeoutMs " ms")
            WorkerContext._WaitForMessages(WorkerContext.WAIT_STEP_MS)
        }
        p := box.res.payload
        if (!p.Get("ok", false)) {
            err := p.Get("error", "")
            code := (err is Map) ? String(err.Get("code", "")) : ""
            text := (err is Map) ? String(err.Get("message", "")) : ""
            if (code = ErrCode.GONE)
                throw ElementError("the execution has ended or was stopped (" type ": gone)")
            if (code = ErrCode.TIMEOUT || code = ErrCode.PEER_GONE || code = ErrCode.SHUTTING_DOWN)
                throw ElementError("engine did not answer " type " (" code ": " text ")")
            throw ElementError(type " failed (" code ": " text ")")
        }
        if (p.Has("elementError"))
            throw ElementError(String(p["elementError"]))
        return p
    }

    ; Waits until a message is in the queue of this thread (at most ms), then lets AHK handle every queued message
    ; (Sleep -1): the wake-up of the pipe runs the pump in a new thread, the timers of the peer run. A plain Sleep(1)
    ; returned only at the next tick of the system timer, 15.6 ms (measured, WI-50).
    static _WaitForMessages(ms) {
        ; QS_ALLINPUT (0x4FF), MWMO_INPUTAVAILABLE (0x4): also return for a message that is already in the queue
        DllCall("MsgWaitForMultipleObjectsEx", "UInt", 0, "Ptr", 0, "UInt", ms, "UInt", 0x4FF, "UInt", 0x4, "UInt")
        Sleep(-1)
    }

    ; The callback of one request: stores the answer in box (a closure of its own per request).
    static _Catcher(box) => (res) => (box.res := res, box.done := true)

    ; Every other variable function of ExecContext needs the variable model of the engine (EvalSource).
    _Vars() {
        throw ElementError("this function has no worker form: the variables of the engine are reached through "
            . "GetVar, SetVar and the other variable functions")
    }

    ; A value as the engine has it (VarValues of the engine): JSON has no Integer keys, so a key of decimal digits
    ; becomes the Integer again (VarValues.NormKey); objects are Maps with case-insensitive keys; null is the empty
    ; text, true and false are 1 and 0. A copy.
    static FromWire(value) {
        if (value is Map) {
            m := Map()
            m.CaseSense := "Off"
            for k, v in value
                m[WorkerContext.NormKey(k)] := WorkerContext.FromWire(v)
            return m
        }
        if (value is Array) {
            m := Map()
            m.CaseSense := "Off"
            for v in value
                m[A_Index] := WorkerContext.FromWire(IsSet(v) ? v : "")
            return m
        }
        if (IsObject(value)) {
            if (value == Json.True)
                return 1
            if (value == Json.False)
                return 0
            return ""
        }
        return value
    }

    ; A value for a request to the engine: a copy that JSON can carry. A Map is copied (its Integer keys become texts on
    ; the wire and Integers again in the engine), an Array stays a list, a Float that is not finite becomes its text.
    ; Any other object is refused with the error that the variable model of the engine gives (VarValues.Import).
    static ToWire(value) {
        if (value is Map) {
            m := Map()
            for k, v in value
                m[k] := WorkerContext.ToWire(v)
            return m
        }
        if (value is Array) {
            a := []
            for v in value
                a.Push(WorkerContext.ToWire(IsSet(v) ? v : ""))
            return a
        }
        if (IsObject(value)) {
            if (value == Json.True || value == Json.False || value == Json.Null)
                return value
            throw ValueError("a variable cannot hold a value of type " Type(value))
        }
        if (Type(value) = "Float" && value - value != 0)
            return String(value)
        return value
    }

    ; The key of a member as the engine stores it (the rule of VarValues.NormKey, which lives in the engine and cannot
    ; be included by the worker role).
    static NormKey(key) {
        if (Type(key) = "Integer")
            return key
        k := String(key)
        return RegExMatch(k, "^-?[0-9]{1,18}$") ? Integer(k) : k
    }

    ; A case-insensitive copy of a Map (variable names are case-insensitive, as in v1), values as FromWire.
    static _Map(source) {
        m := Map()
        m.CaseSense := "Off"
        if (source is Map)
            for k, v in source
                m[k] := WorkerContext.FromWire(v)
        return m
    }
}
