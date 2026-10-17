#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\ErrCode.ahk
#Include ..\core\Json.ahk
#Include ..\elements\base\ElementRegistry.ahk
#Include core\FlowDefinition.ahk

; cmd.import.scan (WI-0081, PROTOCOL 4.2, REQ-SEC-060): the elements of the flows of an .ahf file that act on the system, read
; before the user agrees to the import. Nothing is created or changed. The flows are the definitions the manager read from the
; archive; a definition that does not load is reported with its error (the import then lists it as failed).
; An element acts when its class has `static ActsOnSystem` true (ELEMENT-API-V2 section 2). A class that the engine does not
; know counts as acting too (known false), because nothing tells what it does.
class ImportScan {
    __New(engine) {
        this._engine := engine
    }

    ; The handler of cmd.import.scan. Returns the payload; throws busy while the engine loads.
    Run(msg) {
        if (!this._engine.IsLoaded)
            throw AhfError("the engine is still loading the flows", ErrCode.BUSY)
        defs := msg.payload.Get("flows", "")
        if (!(defs is Array))
            throw AhfError("payload field 'flows' must be a list of flow definitions", ErrCode.BAD_PAYLOAD)
        out := []
        for defn in defs
            out.Push(this._One(defn))
        return Map("flows", out)
    }

    _One(defn) {
        entry := Map("acting", [])
        try {
            if (!(defn is Map))
                throw AhfError("a flow definition must be an object", ErrCode.BAD_PAYLOAD)
            raw := FlowDefinition.CopyValue(defn)
            FlowDefinition("import", raw)           ; throws when the definition does not load
            for elemId, elem in raw.Get("allElements", Map()) {
                if (!(elem is Map))
                    continue
                pkg := String(elem.Get("package", ""))
                cls := String(elem.Get("class", ""))
                qid := ElementRegistry.QualifiedId(pkg, cls)
                known := ElementRegistry.Lookup(pkg, cls)
                if (!IsObject(known))
                    entry["acting"].Push(Map("id", qid, "known", Json.False))
                else if (known.ActsOnSystem)
                    entry["acting"].Push(Map("id", qid, "known", Json.True))
            }
        } catch as e {
            entry["error"] := e.Message
        }
        return entry
    }
}
