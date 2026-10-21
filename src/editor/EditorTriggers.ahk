#Requires AutoHotkey v2.0
#Include ..\core\Json.ahk
#Include SceneBuilder.ahk
#Include EditorModel.ahk

; The switch and the star of a trigger in the editor (WI-0102, REQ-TRG-030, REQ-EDT-110, PROTOCOL 4.11): the marks that a
; press on the trigger hits (FlowHitTest, "mark"), and the same actions from the context menu.
;
; The switch sends the engine command of the trigger (cmd.trigger.enable when it is off, cmd.trigger.disable when it is on,
; PROTOCOL 4.2). It changes nothing in the flow, so it is no undo step; the state comes back as evt.trigger.state.
; When the engine cannot read the state of the flow, the switch asks the same force question as the flow commands
; (EditorFlowOps, E0087, REQ-TRG-030, E0101): yes sends the switch with force (the state of the session is written), no
; changes nothing and says nothing (a cancel is not an error).
; The star makes the trigger the default manual trigger with one patch (element.update of DefaultTrigger; the engine clears
; the default of the other manual triggers in the same patch, PROTOCOL 4.2), so it is one undo step. The star of the default
; trigger does nothing (v1), and so does the star of a trigger that is not manual.
;
; Every request has a timeout (COMMAND_MS). A refused switch or star is a text in the status bar (EditorModel.Notice).
; Each operation calls done(ok) once, when the answer is known (the patch answers at once, the switch later).
class EditorTriggers {
    static COMMAND_MS := 5000

    __New(peer, flowId, model) {
        this.peer := peer
        this.flowId := flowId
        this.model := model
        this.ask := ""                ; the seam of the force question: ask.Confirm(kind, args, done) (EditorFlowOps.ask)
    }

    ; The switch of a trigger: the trigger goes to the state opposite to the one the model shows.
    Switch(triggerId, done := "") {
        t := this.model.triggers.Get(triggerId, "")
        enable := !((t is Map) && t["enabled"])
        this._Send(triggerId, enable, false, done)
    }

    ; One switch request. force: the state of the session is written although the file cannot be read (E0063).
    _Send(triggerId, enable, force, done) {
        type := enable ? "cmd.trigger.enable" : "cmd.trigger.disable"
        payload := Map("flowId", this.flowId, "elementId", triggerId)
        if (force)
            payload["force"] := Json.True
        try {
            this.peer.Request("engine", type, payload
                , (ans) => this._Answered(ans, triggerId, enable, force, done), EditorTriggers.COMMAND_MS)
        } catch {
            this.model.Notice("Menu_trigger_refused")       ; not sent (no peer): the status bar says so
            EditorTriggers._Done(done, false)
        }
    }

    _Answered(ans, triggerId, enable, force, done) {
        p := ans.payload
        ok := p.Get("ok", 0) ? true : false
        if (ok) {
            EditorTriggers._Done(done, true)
            return
        }
        message := EditorModel.TextOf(p, "message")
        if (p.Has("error") && IsObject(p["error"]))
            message := EditorModel.TextOf(p["error"], "message")
        if (!force && InStr(message, "cannot be read (")) {
            ; the same question as the flow commands (E0101): yes writes the state of the session, no changes nothing
            this._Ask(() => this._Send(triggerId, enable, true, done), done)
            return
        }
        this.model.Notice("Menu_trigger_refused")
        EditorTriggers._Done(done, false)
    }

    _Ask(onYes, done) {
        if (!IsObject(this.ask)) {
            this.model.Notice("Menu_trigger_refused")       ; no question can be asked: the switch is refused
            EditorTriggers._Done(done, false)
            return
        }
        name := this.model.name
        this.ask.Confirm("force", [name = "" ? this.flowId : name], (yes) => (yes ? onYes()
            : EditorTriggers._Done(done, false)))
    }

    ; The star: the trigger becomes the default manual trigger in one patch. done(ok): false when it is nothing to do.
    SetDefault(triggerId, done := "") {
        root := this.model.draft.root
        if (!(root is Map) || !root.Get("allElements", Map()).Has(triggerId)) {
            EditorTriggers._Done(done, false)
            return
        }
        el := root["allElements"][triggerId]
        className := SceneBuilder.TextOf(el, "class")
        package := SceneBuilder.TextOf(el, "package")
        if (!SceneBuilder.IsManualTrigger(className, package) || SceneBuilder.IsDefaultTrigger(el, className, package)) {
            EditorTriggers._Done(done, false)
            return
        }
        res := this.model.draft.Commit([Map("op", "element.update", "id", triggerId
            , "fields", Map("DefaultTrigger", 1))], true)
        if (!res["ok"]) {
            this.model.Notice("Menu_default_refused")
            EditorTriggers._Done(done, false)
            return
        }
        EditorTriggers._Done(done, true)
    }

    static _Done(done, ok) {
        if (IsObject(done))
            done(ok)
    }
}
