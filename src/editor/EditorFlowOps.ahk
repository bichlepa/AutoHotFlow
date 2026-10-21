#Requires AutoHotkey v2.0
#Include ..\core\Json.ahk
#Include EditorModel.ahk

; The flow commands of the editor (WI-0091, PROTOCOL 4.11, E0087): Run and Enable or disable, as the tray menu of the editor
; offers them. They send the engine commands of the manager (cmd.flow.start, cmd.flow.enable, cmd.flow.disable, PROTOCOL 4.2)
; with the same questions as the manager (ManagerOps, E0056, E0063): an enable or disable of a flow that is not enabled while
; its independent triggers are on asks whether they go off too; a state that the engine cannot read asks whether the state of
; the session is written (force).
;
; Every request has a timeout (EditorFlowOps.COMMAND_MS). Each operation calls done(res) once, with
; res = Map("ok", bool, "code", string, "message", string). A question answered "no" is ok with the code "cancelled".
;
; The questions go through the seam `ask`: ask.Confirm(kind, args, done), done(true|false). The window (EditorWindow) answers
; them with a dialog, the headless driver (EditorDriver) with the answer of the test.
class EditorFlowOps {
    static COMMAND_MS := 5000
    ; The keys of the texts of each question (the same texts as the manager, assets/language/manager).
    static ASK := Map("independent", ["Ask_independent_title", "Ask_independent_text"]
        , "force", ["Ask_force_title", "Ask_force_text"]
        , "selection", ["Ask_selection_delete_title", "Ask_selection_delete_text"])     ; WI-0101: Del and the trash button

    __New(peer, flowId, model) {
        this.peer := peer
        this.flowId := flowId
        this.model := model
        this.ask := ""           ; the seam, set by the role
    }

    ; Starts the flow with its default trigger (cmd.flow.start without triggerId, as the manager's Run button).
    Run(done := "") {
        this._Send("cmd.flow.start", Map("flowId", this.flowId), done)
    }

    ; Stops the flow: its running and waiting instances end (cmd.flow.stop, PROTOCOL 4.2, WI-0102). The answer is {stopped: n}
    ; without an ok key, so it is ok when it has that key; a refusal is the usual error answer.
    Stop(done := "") {
        this._SendFlowCommand("cmd.flow.stop", "stopped", done)
    }

    ; Saves the flow now (cmd.flow.save, PROTOCOL 4.2, REQ-EDT-100): the answer is {savedRev} when storage has written it.
    Save(done := "") {
        this._SendFlowCommand("cmd.flow.save", "savedRev", done)
    }

    ; A command whose success answer has the key okKey and no ok (cmd.flow.stop, cmd.flow.save).
    _SendFlowCommand(type, okKey, done) {
        try {
            this.peer.Request("engine", type, Map("flowId", this.flowId), (ans) => this._FlowCommandAnswered(ans, okKey, done)
                , EditorFlowOps.COMMAND_MS)
        } catch as e {
            EditorFlowOps._Done(done, Map("ok", false, "code", "not_sent", "message", e.Message))
        }
    }

    _FlowCommandAnswered(ans, okKey, done) {
        if (ans.payload.Has(okKey))
            EditorFlowOps._Done(done, Map("ok", true, "code", "", "message", ""))
        else
            this._Answered(ans, done)
    }

    ; The entry "Disable" when the flow is enabled or one of its independent triggers is on, else "Enable" (the label is built
    ; from the same state, see EditorTray). A disable of a flow that is not enabled, while its independent triggers are on,
    ; asks first (yes: all triggers go off; no: nothing changes).
    Toggle(done := "") {
        st := this.model.flowState
        if (st["enabled"]) {
            this._Switch(true, false, false, done)
        } else if (st["independentActive"] > 0) {
            this._Ask("independent", [this._Name(), st["independentActive"]], (yes) => (yes
                ? this._Switch(true, true, false, done) : EditorFlowOps._Done(done, EditorFlowOps.Cancelled())))
        } else {
            this._Switch(false, false, false, done)
        }
    }

    ; One switch. disable: cmd.flow.disable, else cmd.flow.enable. all: every trigger (E0056). force: the state of the session
    ; is written although the file cannot be read (E0063).
    _Switch(disable, all, force, done) {
        payload := Map("flowId", this.flowId)
        if (all)
            payload["all"] := Json.True
        if (force)
            payload["force"] := Json.True
        this._Send(disable ? "cmd.flow.disable" : "cmd.flow.enable", payload
            , (res) => this._AfterSwitch(disable, all, force, res, done))
    }

    _AfterSwitch(disable, all, force, res, done) {
        if (!force && !res["ok"] && InStr(res["message"], "cannot be read (")) {
            this._Ask("force", [this._Name()], (yes) => (yes
                ? this._Switch(disable, all, true, done) : EditorFlowOps._Done(done, EditorFlowOps.Cancelled())))
            return
        }
        EditorFlowOps._Done(done, res)
    }

    ; --- helpers ---------------------------------------------------------------------------------------------------------

    _Send(type, payload, done) {
        try {
            this.peer.Request("engine", type, payload, (ans) => this._Answered(ans, done), EditorFlowOps.COMMAND_MS)
        } catch as e {
            EditorFlowOps._Done(done, Map("ok", false, "code", "not_sent", "message", e.Message))
        }
    }

    _Answered(ans, done) {
        p := ans.payload
        ok := p.Get("ok", 0) ? true : false
        code := ""
        message := ""
        if (!ok) {
            code := EditorModel.Outcome(p)
            message := EditorModel.TextOf(p, "message")
            if (p.Has("error") && IsObject(p["error"]))
                message := EditorModel.TextOf(p["error"], "message")
        }
        EditorFlowOps._Done(done, Map("ok", ok, "code", code, "message", message))
    }

    _Ask(kind, args, done) {
        if (!IsObject(this.ask)) {
            done(false)
            return
        }
        this.ask.Confirm(kind, args, done)
    }

    _Name() {
        name := this.model.name
        return name = "" ? this.flowId : name
    }

    static Cancelled() => Map("ok", true, "code", "cancelled", "message", "")

    static _Done(done, res) {
        if (IsObject(done))
            done(res)
    }
}
