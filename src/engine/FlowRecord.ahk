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
}
