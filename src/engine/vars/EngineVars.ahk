#Requires AutoHotkey v2.0
#Include VarValues.ahk

; The variables that outlive an instance (WI-40, ARCHITECTURE 4): global (one table for all flows) and static (one
; table per flow). The engine is the only owner; this is its working copy in memory. VarLoader fills it from the
; files at the start, VarWriter writes the changes back (WI-41, both through storage; the engine never touches a
; file). Instance, thread and loop variables belong to Instance and ThreadState.
class EngineVars {
    __New() {
        this.Global := VarValues.NewMap()
        this._statics := VarValues.NewMap()   ; flowId -> Map of the static variables of the flow
        ; Called as OnChange(scope, flowId, name) when VarAccess has set or deleted a global or static variable
        ; (scope "global" or "static", flowId "" for global), or "" when nobody listens. Not called by VarLoader.
        this.OnChange := ""
    }

    ; Tells the listener that the variable (the root name, also when only a member changed) is different now.
    Touch(scope, flowId, name) {
        fn := this.OnChange
        if (IsObject(fn))
            fn(scope, flowId, name)
    }

    ; The table of one scope: Global, or the static variables of the flow.
    Table(scope, flowId) => (scope = "global") ? this.Global : this.Static(flowId)

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
