#Requires AutoHotkey v2.0
#Include ..\core\Json.ahk
#Include SceneBuilder.ahk
#Include EditorModel.ahk

; The switch and the star of a trigger in the editor (WI-0102, REQ-TRG-030, REQ-EDT-110, PROTOCOL 4.11): the marks that a
; press on the trigger hits (FlowHitTest, "mark"), and the same actions from the context menu.
;
; The switch sends the engine command of the trigger (cmd.trigger.enable when it is off, cmd.trigger.disable when it is on,
; PROTOCOL 4.2). It changes nothing in the flow, so it is no undo step; the state comes back as evt.trigger.state.
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
    }

    ; The switch of a trigger: the trigger goes to the state opposite to the one the model shows.
    Switch(triggerId, done := "") {
        t := this.model.triggers.Get(triggerId, "")
        enable := !((t is Map) && t["enabled"])
        type := enable ? "cmd.trigger.enable" : "cmd.trigger.disable"
        try {
            this.peer.Request("engine", type, Map("flowId", this.flowId, "elementId", triggerId)
                , (ans) => this._Answered(ans, done), EditorTriggers.COMMAND_MS)
        } catch {
            this.model.Notice("Menu_trigger_refused")       ; not sent (no peer): the status bar says so
            EditorTriggers._Done(done, false)
        }
    }

    _Answered(ans, done) {
        ok := ans.payload.Get("ok", 0) ? true : false
        if (!ok)
            this.model.Notice("Menu_trigger_refused")
        EditorTriggers._Done(done, ok)
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
