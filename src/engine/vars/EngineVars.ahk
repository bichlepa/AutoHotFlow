#Requires AutoHotkey v2.0
#Include VarValues.ahk

; The variables that outlive an instance (WI-40, ARCHITECTURE 4): global (one table for all flows) and static (one
; table per flow). The engine is the only owner; this is its working copy in memory. Loading them from the data
; folder and writing them back is WI-41. Instance, thread and loop variables belong to Instance and ThreadState.
class EngineVars {
    __New() {
        this.Global := VarValues.NewMap()
        this._statics := VarValues.NewMap()   ; flowId -> Map of the static variables of the flow
    }

    ; The static variables of a flow (created when first used).
    Static(flowId) {
        m := this._statics.Get(flowId, "")
        if (!IsObject(m)) {
            m := VarValues.NewMap()
            this._statics[flowId] := m
        }
        return m
    }

    ; The flow IDs that have a table of static variables.
    StaticFlows() {
        out := []
        for flowId in this._statics
            out.Push(flowId)
        return out
    }
}
