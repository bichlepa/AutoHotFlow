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
        ; WI-0074: the operations on flows and categories (ManagerOps). The driver answers their questions itself: the
        ; answers of the test are set with the op "answers" (kind -> value, see _Answer); a question without an answer is
        ; answered no, "" (Cancel) or 0 (Cancel of a choice).
        this.flowOps := role.ops
        this.flowOps.ask := this
        this.answers := Map()
        this.asked := []          ; the questions since the last op "asked" (WI-0081): Map(kind, args)
        this.ops := Map()
        this.ops["select"] := (args, done) => this._OpSelect(args, done)
        this.ops["run"] := (args, done) => model.RunOrStop(args.Get("flowId", ""), (ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["exit"] := (args, done) => model.Exit((ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["show"] := (args, done) => this._OpShow(args, done)
        this.ops["hide"] := (args, done) => this._OpHide(args, done)
        this.ops["log"] := (args, done) => this._OpLog(args, done)
        this.ops["logFilter"] := (args, done) => this._OpLogFilter(args, done)
        this.ops["notices"] := (args, done) => this._OpNotices(args, done)
        this.ops["importV1"] := (args, done) => this._OpImportV1(args, done)
        this.ops["importFile"] := (args, done) => this.role.ImportFile(args.Get("path", ""), (res) => done(ManagerDriver.Wire(res)))
        this.ops["exportFlows"] := (args, done) => this.role.ExportFlows(args.Get("flowIds", []), args.Get("path", ""), (res) => done(ManagerDriver.Wire(res)))
        this.ops["asked"] := (args, done) => this._OpAsked(args, done)
        this.ops["answers"] := (args, done) => this._OpAnswers(args, done)
        this.ops["selectToggle"] := (args, done) => this._OpSelectToggle(args, done)
        this.ops["selectCategory"] := (args, done) => this._OpSelectCategory(args, done)
        this.ops["enable"] := (args, done) => this._OpSwitch(args, done, true)
        this.ops["disable"] := (args, done) => this._OpSwitch(args, done, false)
        this.ops["edit"] := (args, done) => this._OpEdit(args, done)
        this.ops["openNotice"] := (args, done) => this._OpOpenNotice(args, done)
        this.ops["create"] := (args, done) => this.flowOps.NewFlow(args.Get("category", ""), (ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["duplicate"] := (args, done) => this.flowOps.Duplicate(args.Get("flowId", ""), (ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["delete"] := (args, done) => this.flowOps.Delete(ManagerDriver.Ids(args), (ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["rename"] := (args, done) => this._OpRename(args, done)
        this.ops["settings"] := (args, done) => this._OpSettings(args, done)
        this.ops["move"] := (args, done) => this.flowOps.Move(ManagerDriver.Ids(args), args.Get("category", ""), args.Get("before", ""), (ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["catNew"] := (args, done) => this.flowOps.CategoryNew((ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["catRename"] := (args, done) => this.flowOps.CategoryRename(args.Get("name", ""), (ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["catDelete"] := (args, done) => this.flowOps.CategoryDelete(args.Get("name", ""), (ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["catSort"] := (args, done) => this.flowOps.CategorySort((ans) => done(ManagerDriver.AnswerResult(ans)))
        this.ops["catMove"] := (args, done) => this.flowOps.CategoryMove(args.Get("name", ""), args.Get("before", ""), (ans) => done(ManagerDriver.AnswerResult(ans)))
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

    ; WI-0087: the editor of a flow, as the Edit button and a double click do it: flowId (without it the selected flow), or
    ; flowIds, one request after the other, each sent when the answer of the one before has come (a test of a second Edit
    ; or of the editor limit needs the requests to follow each other at once). done({ok, results}) with one result per flow.
    ; WI-0103: the button "Open editor" of the list of notices for notice n. Answers { ok, sent, answer? }: sent false when
    ; the notice is not an editor notice (no request goes out).
    _OpOpenNotice(args, done) {
        n := args.Get("n", 0)
        sent := this.model.OpenNoticeEditor(n, (ans) => done(Map("ok", Json.True, "sent", Json.True
            , "answerOk", Json.Bool(ans.Get("ok", false)), "code", ans.Get("code", ""))))
        if (!sent)
            done(Map("ok", Json.True, "sent", Json.False))
    }

    _OpEdit(args, done) {
        ids := args.Get("flowIds", "")
        if (!(ids is Array))
            ids := [args.Get("flowId", "")]
        if (ids.Length = 1 && ids[1] = "")
            ids[1] := this.model.selectedFlow
        this._EditNext(ids, 1, [], done)
    }

    _EditNext(ids, i, results, done) {
        if (i > ids.Length) {
            done(Map("ok", true, "results", results))
            return
        }
        this.model.OpenEditor(ids[i], (ans) => this._EditAnswered(ids, i, results, ans, done))
    }

    _EditAnswered(ids, i, results, ans, done) {
        results.Push(ManagerDriver.Wire(ManagerDriver.AnswerResult(ans)))   ; nested ok: JSON true/false (PROTOCOL 2)
        this._EditNext(ids, i + 1, results, done)
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

    ; WI-0075: opens the list of notices (the marks of the flows go, the window is shown when there is one); the answer
    ; has the list of notices of the model (PROTOCOL 4.8).
    _OpNotices(args, done) {
        this.role.OpenNotices()
        done(Map("ok", true, "notices", this.model.NoticeState()))
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

    ; WI-0074: the answers of the questions of an operation (kind -> "yes"/"no", a text, or a choice number).
    _OpAnswers(args, done) {
        given := args.Get("answers", Map())
        if (!(given is Map))
            throw AhfError("cmd.test.op answers: answers must be an object", ErrCode.BAD_PAYLOAD)
        this.answers := given
        done(Map("ok", true))
    }

    ; WI-0076: the import from v1 (ManagerImport) of the folder dir; startupDir is the startup folder of the autostart step, and
    ; without it the step is left out (a test never touches the real startup folder). The answer is the report.
    _OpImportV1(args, done) {
        this.role.ImportV1(args.Get("dir", ""), args.Get("startupDir", ""), (res) => done(ManagerDriver.Wire(res)))
    }

    ; WI-0078: the OK of the settings dialog without the window: the values (settings: key -> raw value, as the controls give
    ; them) are checked by SettingsForm; a refused value answers ok false with the messages (errors: key -> message) and
    ; nothing is sent (sent false). Otherwise the set goes to the engine and the answer is the answer of cmd.settings.set.
    _OpSettings(args, done) {
        res := SettingsForm.Collect(args.Get("settings", Map()))
        if (!res["ok"]) {
            done(Map("ok", false, "sent", Json.False, "errors", ManagerDriver.Wire(res["errors"]), "code", "bad_payload"
                , "message", ""))
            return
        }
        this.model.SetSettings(res["partial"], (ans) => done(Map("ok", ans["ok"], "sent", Json.True, "errors", Map()
            , "code", ans["code"], "message", ans["message"])))
    }

    _OpSelectToggle(args, done) {
        this.model.SelectToggle(args.Get("flowId", ""))
        done(Map("ok", true, "selectedFlows", ManagerDriver.Wire(this.model.SelectedFlows())))
    }

    _OpSelectCategory(args, done) {
        this.model.SelectCategory(args.Get("name", ""))
        done(Map("ok", true))
    }

    ; enable/disable of flows (flowIds); the answer is the one of the last command, or sent false when none was sent.
    _OpSwitch(args, done, enable) {
        this.flowOps.SetEnabled(ManagerDriver.Ids(args), enable, (ans) => done(ManagerDriver.AnswerResult(ans)))
    }

    ; rename: with name the engine gets the name as given (its check is tested); without name the dialog's check and answer.
    _OpRename(args, done) {
        flowId := args.Get("flowId", "")
        if (args.Has("name"))
            this.flowOps.RenameTo(flowId, args["name"], (ans) => done(ManagerDriver.AnswerResult(ans)))
        else
            this.flowOps.Rename(flowId, (ans) => done(ManagerDriver.AnswerResult(ans)))
    }

    ; The questions of ManagerOps (ask seam, synchronous here): the answer of the test or the cancel value.
    Confirm(kind, args, done) {
        this._Asked(kind, args)
        done(this._Answer(kind, "no") = "yes")
    }

    Input(kind, default, check, done) {
        this._Asked(kind, [default])
        value := this._Answer(kind, "")
        if (value = "" || check(value) != "")
            value := ""
        done(value)
    }

    Choose(kind, items, done, args*) {
        this._Asked(kind, args)
        done(this._Answer(kind, 0))
    }

    ; WI-0081: the questions are recorded (kind and the arguments of the text) for the tests, which read them with "asked".
    _Asked(kind, args) {
        this.asked.Push(Map("kind", kind, "args", ManagerDriver.Wire(args)))
    }

    _OpAsked(args, done) {
        out := this.asked
        this.asked := []
        done(Map("ok", true, "asked", out))
    }

    _Answer(kind, cancel) => this.answers.Has(kind) ? this.answers[kind] : cancel

    ; The flow IDs of an operation: payload flowIds (a list); a single flowId is taken as a list of one.
    static Ids(args) {
        if (args.Has("flowIds"))
            return args["flowIds"]
        return args.Has("flowId") ? [args["flowId"]] : []
    }

    ; The result of an operation that sent a command: whether the answer was ok, its code and message. sent false when
    ; the operation sent nothing (a question was answered no, or no flow matched).
    static AnswerResult(ans) {
        if (!IsObject(ans))
            return Map("ok", true, "sent", Json.False)
        return Map("ok", true, "sent", Json.True, "answer", ManagerDriver.Wire(Map("type", ans["type"], "flowId", ans["flowId"]
            , "ok", ans["ok"], "code", ans["code"], "message", ans["message"], "ms", ans["ms"]
            , "payload", ans["payload"])))
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
