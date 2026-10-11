#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include core\FlowDefinition.ahk
#Include FlowRecord.ahk

; The loaded flows of the engine, keyed by flow ID (the file name without ".json"). Keys are case
; insensitive, as v1 object keys are (KONVENTIONEN section 5). Pure bookkeeping: no I/O. The text of
; a flow file comes from storage, the engine only parses it (ARCHITEKTUR 6.1, step 3).
class FlowTable {
    __New() {
        this._records := Map()
        this._records.CaseSense := "Off"
    }

    Count => this._records.Count

    Has(flowId) => this._records.Has(flowId)

    ; The record, or "" if the flow is not loaded.
    Get(flowId) => this._records.Get(flowId, "")

    ; The record, or throws AhfError (code not_found).
    Require(flowId) {
        rec := this._records.Get(flowId, "")
        if (!IsObject(rec))
            throw AhfError("flow '" flowId "' is not loaded", ErrCode.NOT_FOUND)
        return rec
    }

    ; All records as an Array, in Map order (sorted by flow ID).
    All() {
        out := []
        for _, rec in this._records
            out.Push(rec)
        return out
    }

    ; Removes a flow. Returns true if it was loaded. The caller stops its instances first
    ; (Executor.FlowDeleted).
    Remove(flowId) {
        if (!this._records.Has(flowId))
            return false
        this._records.Delete(flowId)
        return true
    }

    ; Parses the text of a flow file and adds it as revision 1. Throws AhfError for invalid JSON,
    ; a wrong structure or a flow ID that is loaded already.
    Load(flowId, text) {
        if (this._records.Has(flowId))
            throw AhfError("flow '" flowId "' is loaded already", ErrCode.CONFLICT)
        def := FlowDefinition.FromText(flowId, text, 1)
        this._records[flowId] := FlowRecord(flowId, def, 1)
    }
}
