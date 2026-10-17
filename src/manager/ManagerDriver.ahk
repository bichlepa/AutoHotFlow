#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\ipc\Deferred.ahk

; The headless driver of the manager (WI-0073, doc/PROTOCOL.md 4.8): the test commands cmd.test.* that call the operations of
; the ManagerModel and return its state, so the e2e tests of the manager (WI-0074 to WI-0081) run without a window in the normal
; tiers. It exists only with --headless: a product manager answers cmd.test.* with the unknown-type error of the peer.
;
;   cmd.test.command {type, payload}   a request of the user to the engine through model.Command; type from `allowed`
;   cmd.test.state {}                  the state of the model (model.State)
;   cmd.test.trace {since?}            the record of events and answers with a number above since (model.Trace)
;   cmd.test.op {op, ...}              a named operation of the model, see ops; the answer comes when the operation is done
;
; A package that adds an operation to the model adds it here too: ops[name] := (args, done) => ..., where done(result) answers
; with a Map; allowed[type] := 1 for a command that cmd.test.command may forward.
class ManagerDriver {
    __New(role, model) {
        this.role := role
        this.model := model
        this.allowed := Map("cmd.flow.start", 1, "cmd.flow.stop", 1, "cmd.flow.toggle", 1, "cmd.engine.snapshot", 1)
        this.ops := Map()
        this.ops["select"] := (args, done) => this._OpSelect(args, done)
        this.ops["run"] := (args, done) => model.RunOrStop(args.Get("flowId", ""), (ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["exit"] := (args, done) => model.Exit((ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["show"] := (args, done) => this._OpShow(args, done)
        this.ops["hide"] := (args, done) => this._OpHide(args, done)
        this.ops["log"] := (args, done) => this._OpLog(args, done)
        this.ops["logFilter"] := (args, done) => this._OpLogFilter(args, done)
        role.On("cmd.test.command", (msg) => this._OnCommand(msg))
        role.On("cmd.test.state", (msg) => Map("ok", true, "state", ManagerDriver.Wire(model.State())))
        role.On("cmd.test.trace", (msg) => this._OnTrace(msg))
        role.On("cmd.test.op", (msg) => this._OnOp(msg))
    }

    _OnCommand(msg) {
        t := msg.payload.Get("type", "")
        if (!this.allowed.Has(t))
            throw AhfError("cmd.test.command: type '" t "' is not allowed", ErrCode.BAD_PAYLOAD)
        inner := msg.payload.Get("payload", Map())
        if (!IsObject(inner))
            throw AhfError("cmd.test.command: payload must be an object", ErrCode.BAD_PAYLOAD)
        this.model.Command(t, inner, (ans) => this.role.peer.Reply(msg, Map("ok", true
            , "answer", ManagerDriver.Wire(ans["payload"]))))
        return Deferred.Marker()
    }

    _OnTrace(msg) {
        since := msg.payload.Get("since", 0)
        if (!IsInteger(since))
            throw AhfError("cmd.test.trace: since must be an integer", ErrCode.BAD_PAYLOAD)
        return Map("ok", true, "entries", ManagerDriver.Wire(this.model.Trace(since)), "count", this.model.traceCount)
    }

    _OnOp(msg) {
        name := msg.payload.Get("op", "")
        if (!this.ops.Has(name))
            throw AhfError("cmd.test.op: unknown operation '" name "'", ErrCode.BAD_PAYLOAD)
        this.ops[name](msg.payload, (result) => this.role.peer.Reply(msg, result))
        return Deferred.Marker()
    }

    _OpSelect(args, done) {
        this.model.Select(args.Get("flowId", ""))
        done(Map("ok", true, "selectedFlow", this.model.selectedFlow))
    }

    _OpShow(args, done) {
        this.role._OnShow("")
        done(Map("ok", true))
    }

    _OpHide(args, done) {
        if (IsObject(this.role.view))
            this.role.view.Hide()
        done(Map("ok", true))
    }

    ; WI-0080: opens (with a flow ID: only that flow) or closes the log; the answer has the log part of the state.
    _OpLog(args, done) {
        action := args.Get("action", "open")
        if (action = "open")
            this.role.OpenLog(args.Get("flowId", ""))
        else if (action = "close")
            this.role.CloseLog()
        else
            throw AhfError("cmd.test.op log: action must be open or close", ErrCode.BAD_PAYLOAD)
        done(Map("ok", true, "log", this.model.LogState()))
    }

    ; WI-0080: the filter of the log (level, group, flowId; the keys that are given are changed).
    _OpLogFilter(args, done) {
        changes := Map()
        for key in ["level", "group", "flowId"] {
            if (args.Has(key))
                changes[key] := args[key]
        }
        this.model.LogFilter(changes)
        done(Map("ok", true, "log", this.model.LogState()))
    }

    ; The result of an operation that sent a command: whether the answer was ok, its code and message.
    static AnswerResult(ans) {
        return Map("ok", true, "answer", ManagerDriver.Wire(Map("type", ans["type"], "flowId", ans["flowId"]
            , "ok", ans["ok"], "code", ans["code"], "message", ans["message"], "ms", ans["ms"])))
    }

    ; A copy of a node as it goes onto the wire: Json.Parse read true/false as 1/0, so the truth fields of the protocol are
    ; turned back into Json.True/Json.False (at any depth).
    static Wire(node) {
        static boolFields := "|ok|cancel|started|clean|restart|enabled|executing|exists|existed|waiting|byMeta|delete|armed|ready|"
        if (node is Map) {
            out := Map()
            out.CaseSense := node.CaseSense
            for key, value in node
                out[key] := (InStr(boolFields, "|" key "|") && IsNumber(value)) ? Json.Bool(value) : ManagerDriver.Wire(value)
            return out
        }
        if (node is Array) {
            out := []
            for item in node
                out.Push(ManagerDriver.Wire(item))
            return out
        }
        return node
    }
}
