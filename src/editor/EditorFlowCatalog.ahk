#Requires AutoHotkey v2.0
#Include ..\core\Json.ahk

; The other flows as the element settings need them (WI-0107, PROTOCOL 4.2): the flow list (names, from cmd.engine.snapshot)
; and the triggers of the other flows (names, from cmd.flow.triggers). The editor asks when a settings window opens (Refresh)
; and keeps the answers until evt.flow.list.changed (Drop). A name that is not known yet shows the ID: nothing waits for the
; engine. An answer that arrives calls onChange() once, so that an open settings window shows the lists (EditorSettings).
;
; A request that fails (timeout, engine down) keeps no answer and calls nothing: the next need asks again. Every request has
; a timeout (COMMAND_MS). The own flow is not in the trigger cache: EditorElementCtx reads its draft, which is newer.
class EditorFlowCatalog {
    static COMMAND_MS := 5000

    __New(peer) {
        this.peer := peer
        this.flows := []            ; Array of Map("flowId", "name"), in the order of the engine
        this.loaded := false        ; true once an answer of cmd.engine.snapshot was kept (until Drop)
        this.triggerLists := Map()      ; flowId -> Array of Map("elementId", "name", "manual"), kept until Drop
        this.inFlight := Map()      ; flowId -> true while cmd.flow.triggers of the flow is on its way
        this.onChange := ""         ; fn(): called after an answer was kept
    }

    ; Asks the engine for the flow list. The answer is kept and onChange is called.
    Refresh() {
        try {
            this.peer.Request("engine", "cmd.engine.snapshot", Map(), (ans) => this._Snapshot(ans)
                , EditorFlowCatalog.COMMAND_MS)
        } catch {
            ; not sent (no peer): the lists stay as they are
        }
    }

    ; evt.flow.list.changed: the kept answers are old. The flow list is asked again at once (onChange follows it).
    Drop() {
        this.flows := []
        this.loaded := false
        this.triggerLists := Map()
        this.Refresh()
    }

    ; The triggers of another flow: the kept list, or "" while it is not known (then the engine is asked, and onChange
    ; follows the answer). The own flow is not asked for: its draft is the source (EditorElementCtx).
    Triggers(flowId) {
        if (this.triggerLists.Has(flowId))
            return this.triggerLists[flowId]
        if (this.inFlight.Has(flowId))
            return ""
        this.inFlight[flowId] := true
        try {
            this.peer.Request("engine", "cmd.flow.triggers", Map("flowId", flowId)
                , (ans) => this._Triggers(flowId, ans), EditorFlowCatalog.COMMAND_MS)
        } catch {
            this.inFlight.Delete(flowId)
        }
        return ""
    }

    _Snapshot(ans) {
        p := ans.payload
        if (!p.Get("ok", 0) || !(p.Get("flows", "") is Array))
            return
        list := []
        for f in p["flows"] {
            if (!(f is Map))
                continue
            list.Push(Map("flowId", EditorFlowCatalog._Text(f.Get("flowId", "")), "name", EditorFlowCatalog._Text(f.Get("name", ""))))
        }
        this.flows := list
        this.loaded := true
        this._Changed()
    }

    _Triggers(flowId, ans) {
        this.inFlight.Delete(flowId)
        p := ans.payload
        if (!p.Get("ok", 0) || !(p.Get("triggers", "") is Array))
            return
        list := []
        for t in p["triggers"] {
            if (!(t is Map))
                continue
            list.Push(Map("elementId", EditorFlowCatalog._Text(t.Get("elementId", "")), "name", EditorFlowCatalog._Text(t.Get("name", ""))
                , "manual", EditorFlowCatalog._Flag(t.Get("manual", 0))))
        }
        this.triggerLists[flowId] := list
        this._Changed()
    }

    _Changed() {
        if (IsObject(this.onChange))
            this.onChange.Call()        ; .Call: a function object in a property gets no object as first argument
    }

    static _Text(v) => IsObject(v) ? "" : String(v)

    ; A JSON boolean from the wire: Json.True, 1, "1" or "true" are on; anything else is off.
    static _Flag(v) => (v == Json.True) || (!IsObject(v) && (v = 1 || v = "1" || v = "true"))
}
