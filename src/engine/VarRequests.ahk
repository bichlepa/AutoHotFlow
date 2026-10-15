#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include Executor.ahk
#Include vars\VarNames.ahk

; The variable requests cmd.engine.var.* (WI-0050, ARCHITECTURE R0004, doc/PROTOCOL.md 4.5 "Variable requests"). A worker
; element asks with the execId of its job, a client with an instanceId (and optionally a threadId). Every request is
; answered at once from the variable model of the engine: no waiting, no file I/O; a changed global or static variable
; is written later by VarWriter (write-behind, WI-0041).
;
; The operations are the functions of the element context (ExecContext): for an execId the context of the running
; element itself, so a worker element sees exactly what it would see inline; for an instanceId a context made for the
; request (Executor.ContextOf). An operation that fails the way it fails inline (an expression error, a hidden global
; variable, an unknown scope) is answered with ok and elementError, the text the inline function throws; the worker
; throws ElementError with it. Errors of the request itself (fields, gone, denied) are AhfErrors, answered with ok false.
;
; owner: the Engine (fields workers and executor).
class VarRequests {
    static OPS := Map("cmd.engine.var.get", "_Get", "cmd.engine.var.set", "_Set", "cmd.engine.var.delete", "_Delete"
        , "cmd.engine.var.list", "_List", "cmd.engine.var.import", "_Import", "cmd.engine.var.replace", "_Replace"
        , "cmd.engine.var.eval", "_Eval")

    __New(owner) {
        this._owner := owner
    }

    ; The handler of every cmd.engine.var.* request. Returns the payload of the answer.
    Handle(msg) {
        op := VarRequests.OPS.Get(msg.type, "")
        if (op = "")
            throw AhfError("unknown variable request " msg.type, ErrCode.UNKNOWN_TYPE)
        p := msg.payload
        ctx := this._Target(msg)
        argList := this._Args(op, p, ctx)          ; field checks first: their errors are errors of the request
        try {
            return this.%op%(ctx, argList)
        } catch as e {
            return Map("elementError", e.Message)
        }
    }

    ; The element context that the request names. Throws gone, denied or bad_payload.
    _Target(msg) {
        p := msg.payload
        execId := VarRequests._Scalar(p, "execId")
        instId := VarRequests._Scalar(p, "instanceId")
        if ((execId = "") = (instId = ""))
            throw AhfError("a variable request needs either execId or instanceId", ErrCode.BAD_PAYLOAD)
        if (execId != "") {
            jobRec := this._owner.workers.JobOf(execId)
            if (!IsObject(jobRec) || !IsObject(jobRec["ctx"]))
                throw AhfError("execution '" execId "' is not running (ended or stopped)", ErrCode.GONE)
            if (jobRec["slot"] != msg.from)
                throw AhfError("execution '" execId "' runs on " jobRec["slot"] ", not on " msg.from, ErrCode.DENIED)
            return jobRec["ctx"]
        }
        return this._owner.executor.ContextOf(instId, VarRequests._Scalar(p, "threadId"))
    }

    ; The checked fields of one operation, as a Map.
    _Args(op, p, ctx) {
        a := Map()
        switch op {
            case "_Get", "_Delete":
                a["name"] := VarRequests._Scalar(p, "name")
                a["hidden"] := VarRequests._Flag(p, "hidden")
            case "_Set":
                a["name"] := VarRequests._Scalar(p, "name")
                a["value"] := p.Get("value", "")
                a["scope"] := VarRequests._Scalar(p, "scope")
                a["hidden"] := VarRequests._Flag(p, "hidden")
                if (ctx.HasProp("noThread") && ctx.noThread && VarNames.IsA(a["name"]))
                    throw AhfError("setting the A_ variable '" a["name"] "' needs a threadId", ErrCode.BAD_PAYLOAD)
            case "_List":
                a["scope"] := VarRequests._Scalar(p, "scope")
                a["withValues"] := VarRequests._Flag(p, "withValues")
            case "_Import":
                vars := p.Get("vars", "")
                if (!(vars is Map))
                    throw AhfError("payload field 'vars' must be an object", ErrCode.BAD_PAYLOAD)
                a["vars"] := vars
            case "_Replace":
                a["text"] := VarRequests._Scalar(p, "text")
                a["convertObjects"] := VarRequests._Flag(p, "convertObjects")
            case "_Eval":
                a["text"] := VarRequests._Scalar(p, "text")
                kind := VarRequests._Scalar(p, "kind")
                if (kind = "")
                    kind := "expression"
                if (kind != "expression" && kind != "script")
                    throw AhfError("payload field 'kind' must be expression or script", ErrCode.BAD_PAYLOAD)
                a["kind"] := kind
        }
        return a
    }

    ; --- operations (ctx: ExecContext with its VarAccess) -------------------------------------------------------------

    _Get(ctx, a) {
        vars := ctx.vars
        location := vars.Location(a["name"], a["hidden"])
        exists := location != ""
        return Map("exists", Json.Bool(exists)
            , "value", exists ? Executor.ToWire(vars.GetVar(a["name"], "", a["hidden"])) : ""
            , "type", vars.VarType(a["name"], a["hidden"]), "location", location)
    }

    _Set(ctx, a) => Map("accepted", Json.Bool(ctx.SetVar(a["name"], a["value"], a["scope"], a["hidden"])))

    _Delete(ctx, a) => Map("existed", Json.Bool(ctx.DeleteVar(a["name"], a["hidden"])))

    _List(ctx, a) {
        names := ctx.ListVars(a["scope"])
        out := Map("names", names)
        if (a["withValues"]) {
            values := Map()
            for name in names
                values[name] := Executor.ToWire(ctx.GetVar(name))
            out["values"] := values
        }
        return out
    }

    _Import(ctx, a) {
        ctx.ImportInstanceVars(a["vars"])
        return Map()
    }

    _Replace(ctx, a) => Map("text", ctx.ReplaceVariables(a["text"], a["convertObjects"]))

    _Eval(ctx, a) {
        value := (a["kind"] = "script") ? ctx.EvaluateScript(a["text"]) : ctx.EvaluateExpression(a["text"])
        return Map("value", Executor.ToWire(value))
    }

    ; --- fields ---------------------------------------------------------------------------------------------------

    ; An optional text or number field as a text ("" when missing). An object is bad_payload.
    static _Scalar(p, key) {
        v := p.Get(key, "")
        if (IsObject(v))
            throw AhfError("payload field '" key "' must be a text or a number", ErrCode.BAD_PAYLOAD)
        return String(v)
    }

    ; An optional truth value: true/false (1/0 after parsing), also "true"/"false". Missing is false.
    static _Flag(p, key) {
        v := p.Get(key, 0)
        if (IsObject(v))
            throw AhfError("payload field '" key "' must be a truth value", ErrCode.BAD_PAYLOAD)
        return (v = 1 || v = "true") ? 1 : 0
    }
}
