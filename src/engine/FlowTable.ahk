#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include core\FlowDefinition.ahk
#Include core\FlowExprConvert.ahk
#Include FlowRecord.ahk

; The loaded flows of the engine, keyed by flow ID (the file name without ".json"). Keys are case
; insensitive, as v1 object keys are (CONVENTIONS section 5). Pure bookkeeping: no I/O. The text of
; a flow file comes from storage, the engine only parses it (ARCHITECTURE 6.1, step 3).
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

    ; Adds a record that was created by a command (WI-0070, FlowLifecycle). Throws AhfError (conflict) for a flow ID
    ; that is in the table already.
    Insert(rec) {
        if (this._records.Has(rec.FlowId))
            throw AhfError("flow '" rec.FlowId "' is loaded already", ErrCode.CONFLICT)
        this._records[rec.FlowId] := rec
    }

    ; Removes a flow. Returns true if it was loaded. The caller stops its instances first
    ; (Executor.FlowDeleted).
    Remove(flowId) {
        if (!this._records.Has(flowId))
            return false
        this._records.Delete(flowId)
        return true
    }

    ; Parses the text of a flow file, converts the expression texts of v1 (FlowExprConvert) and adds it as
    ; revision 1. Throws AhfError for invalid JSON, a wrong structure or a flow ID that is loaded already.
    Load(flowId, text) {
        if (this._records.Has(flowId))
            throw AhfError("flow '" flowId "' is loaded already", ErrCode.CONFLICT)
        def := FlowDefinition.FromText(flowId, text, 1)
        try {
            FlowExprConvert.Run(def)   ; expression texts of v1 into the new language (WI-0039)
        } catch as e {
            ; The flow stays usable with the texts as they are; element code never takes the engine down.
            Log.Write("f1", "flow load", "converting the expression texts failed (" Type(e) ": " e.Message "); "
                . "the flow is loaded unconverted", flowId)
        }
        this._records[flowId] := FlowRecord(flowId, def, 1)
    }
}
