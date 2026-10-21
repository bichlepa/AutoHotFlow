#Requires AutoHotkey v2.0
#Include ..\..\core\Ids.ahk

; The kept errors of the flows (WI-0113, PROTOCOL 4.7a): the last KEEP unhandled exceptions per flow, each with the copy of
; its variables (ErrorSnapshot). They live in memory of the engine only, and Forget drops them with the flow (cmd.flow.delete).
; Flow IDs are matched without case, as the flow table does.
class FlowErrors {
    static KEEP := 5

    __New() {
        this._byFlow := Map()
        this._byFlow.CaseSense := "Off"
    }

    ; Keeps an error of a flow and returns its errorId ("err-<n>"). The oldest error of the flow goes when KEEP is exceeded.
    Add(flowId, entry) {
        errorId := Ids.Next("err-")
        entry["errorId"] := errorId
        entry["flowId"] := flowId
        list := this._byFlow.Get(flowId, "")
        if (list = "") {
            list := []
            this._byFlow[flowId] := list
        }
        list.Push(entry)
        while (list.Length > FlowErrors.KEEP)
            list.RemoveAt(1)
        return errorId
    }

    ; The kept entry with this errorId, or "" when the flow keeps no such error.
    Get(flowId, errorId) {
        list := this._byFlow.Get(flowId, "")
        if (list = "")
            return ""
        for entry in list {
            if (entry["errorId"] = errorId)
                return entry
        }
        return ""
    }

    ; Drops the errors of a flow (the flow was deleted).
    Forget(flowId) {
        if (this._byFlow.Has(flowId))
            this._byFlow.Delete(flowId)
    }

    Count(flowId) {
        list := this._byFlow.Get(flowId, "")
        return (list = "") ? 0 : list.Length
    }
}
