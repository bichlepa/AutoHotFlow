#Requires AutoHotkey v2.0

class FlowInstance {
    __New(instanceId, flowId) {
        this.instanceId := instanceId
        this.flowId := flowId
        this.state := "starting" ; Valid states: starting, running, finished, stopped
        this.variables := Map()
        this.currentElementId := ""
    }

    transitionTo(newState) {
        validTransitions := Map(
            "starting", ["running", "stopped"],
            "running", ["finished", "stopped"],
            "finished", [],
            "stopped", []
        )

        if (!validTransitions.Has(this.state) || !this.hasValue(validTransitions[this.state], newState)) {
            throw ValueError("Invalid state transition from " . this.state . " to " . newState)
        }
        this.state := newState
    }

    hasValue(arr, val) {
        for item in arr {
            if (item == val)
                return true
        }
        return false
    }

    setVariable(name, value) {
        this.variables[name] := value
    }

    getVariable(name) {
        return this.variables.Has(name) ? this.variables[name] : ""
    }
}
