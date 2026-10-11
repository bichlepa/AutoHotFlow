#Requires AutoHotkey v2.0

; One loaded flow in the engine (WI-10, ARCHITECTURE 4.2): the committed definition, its revision
; and the enabled flag. Owned by the engine only; other roles get copies through messages.
class FlowRecord {
    __New(flowId, def, rev := 1) {
        this.FlowId := flowId
        this.Def := def          ; FlowDefinition (engine/core), read only
        this.Rev := rev
        this.Enabled := false    ; Phase 2: a flag only, triggers are not armed (WI-14, Phase 3)
    }

    ; Commits a new definition as the next revision. The Executor reads Def at every step (E1), so the
    ; next step of every running instance sees it. Phase 3 calls this when a patch is applied.
    Commit(def) {
        this.Def := def
        this.Rev += 1
    }
}
