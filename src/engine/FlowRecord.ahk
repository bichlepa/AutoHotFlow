#Requires AutoHotkey v2.0

; One loaded flow in the engine (WI-0010, ARCHITECTURE 4.2): the committed definition, its revision and the
; target state of its triggers (E0056, WI-0060). Owned by the engine only; other roles get copies through messages.
;
; The target state of a trigger is "enabled" or not. A trigger that follows the flow (FlowDefinition.FollowsFlow)
; belongs to the flow: the flow is enabled when at least one of them is enabled (derived, not stored). A trigger
; that does not follow the flow ("independent") keeps its own state. Nothing is armed here (WI-0062): this record
; only knows the target state.
class FlowRecord {
    __New(flowId, def, rev := 1) {
        this.FlowId := flowId
        this.Def := def          ; FlowDefinition (engine/core), read only
        this.Rev := rev
        this._enabled := FlowDefinition.NewIndex()   ; trigger ID -> true; a trigger not in the map is disabled
    }

    ; Commits a new definition as the next revision. The Executor reads Def at every step (E0001), so the
    ; next step of every running instance sees it. Called by cmd.flow.patch and by a meta update (WI-0093).
    Commit(def) {
        this.Def := def
        this.Rev += 1
    }

    ; True if the trigger is enabled (target state). Only meaningful for triggers of the flow; false otherwise.
    TriggerEnabled(triggerId) => this._enabled.Has(triggerId) && this.Def.ElementKind(triggerId) = "trigger"

    ; True if at least one trigger that follows the flow is enabled. The flow is "enabled" in this sense (evt.flow.state).
    IsFlowEnabled() {
        for triggerId in this.Def.Triggers() {
            if (this.Def.FollowsFlow(triggerId) && this.TriggerEnabled(triggerId))
                return true
        }
        return false
    }

    ; True if at least one trigger follows the flow (the switch of the flow has something to switch).
    HasFollowingTrigger() {
        for triggerId in this.Def.Triggers() {
            if (this.Def.FollowsFlow(triggerId))
                return true
        }
        return false
    }

    ; Number of enabled triggers that do not follow the flow (evt.flow.state.independentActive).
    IndependentActiveCount() {
        n := 0
        for triggerId in this.Def.Triggers() {
            if (!this.Def.FollowsFlow(triggerId) && this.TriggerEnabled(triggerId))
                n += 1
        }
        return n
    }

    ; IDs of the enabled triggers, in the order of the triggers of the flow (sorted by ID). The file FlowStates/<flowId>.json
    ; keeps exactly these.
    EnabledTriggers() {
        out := []
        for triggerId in this.Def.Triggers() {
            if (this.TriggerEnabled(triggerId))
                out.Push(triggerId)
        }
        return out
    }

    ; Sets the target state of one trigger. Returns true if it changed; false for an element that is not a trigger of the flow.
    SetTriggerEnabled(triggerId, enabled) {
        if (this.Def.ElementKind(triggerId) != "trigger")
            return false
        was := this._enabled.Has(triggerId)
        if (enabled && !was) {
            this._enabled[triggerId] := true
            return true
        }
        if (!enabled && was) {
            this._enabled.Delete(triggerId)
            return true
        }
        return false
    }

    ; Drops the target state of a trigger that the flow no longer has (WI-0094): an undo that brings it back with the same
    ; ID starts from the rules of a new trigger, not from its old state.
    ForgetTrigger(triggerId) {
        if (this._enabled.Has(triggerId))
            this._enabled.Delete(triggerId)
    }

    ; Sets the target state of every trigger that follows the flow, or of every trigger when all is true. Returns the
    ; IDs of the triggers whose state changed (an Array, possibly empty).
    SetFollowingEnabled(enabled, all := false) {
        changed := []
        for triggerId in this.Def.Triggers() {
            if (!all && !this.Def.FollowsFlow(triggerId))
                continue
            if (this.SetTriggerEnabled(triggerId, enabled))
                changed.Push(triggerId)
        }
        return changed
    }

    ; The triggers of a scope (WI-0065, the choices of the elements Set flow status and Flow enabled): "following" (they
    ; switch with the flow), "independent" (they do not) or "all". An Array in the order of the flow, possibly empty.
    TriggersOf(scope) {
        out := []
        for triggerId in this.Def.Triggers() {
            follows := this.Def.FollowsFlow(triggerId)
            if (scope = "all" || (scope = "following" && follows) || (scope = "independent" && !follows))
                out.Push(triggerId)
        }
        return out
    }

    ; Sets the target state of the given triggers. Returns the IDs whose state changed (an Array, possibly empty).
    SetEnabledOf(triggerIds, enabled) {
        changed := []
        for triggerId in triggerIds {
            if (this.SetTriggerEnabled(triggerId, enabled))
                changed.Push(triggerId)
        }
        return changed
    }

    ; Takes the enabled triggers of the file FlowStates/<flowId>.json (the IDs that are triggers of this flow). Returns the IDs that were newly enabled.
    LoadEnabledTriggers(triggerIds) {
        taken := []
        for triggerId in triggerIds {
            if (this.Def.ElementKind(triggerId) = "trigger" && !this._enabled.Has(triggerId)) {
                this._enabled[triggerId] := true
                taken.Push(triggerId)
            }
        }
        return taken
    }
}
