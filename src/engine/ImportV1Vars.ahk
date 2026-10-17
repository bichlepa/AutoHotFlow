#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include vars\VarNames.ahk
#Include vars\VarValues.ahk

; cmd.import.v1.vars (WI-0076, E0068, PROTOCOL 4.2): the global and static variables of a v1 data folder, read by the manager
; through storage and handed to the engine, which owns them. A global variable that v2 has already keeps its value (v2 wins,
; the conflict is listed in "kept"). A static variable goes to a loaded flow only. The change is sent to the write-behind of
; the variables (EngineVars.Touch, VarWriter), so storage writes the file like any other change (M-0006).
;
; The answer lists every entry once: taken (set), kept (the v2 value stays), failed (with the reason). An entry that fails
; does not stop the others.
class ImportV1Vars {
    __New(engine) {
        this._engine := engine
    }

    ; The handler of cmd.import.v1.vars. Returns the payload of the answer; throws busy while the engine loads.
    Run(msg) {
        if (!this._engine.IsLoaded)
            throw AhfError("the engine is still loading the flows", ErrCode.BUSY)
        p := msg.payload
        globals := p.Get("globals", [])
        statics := p.Get("statics", [])
        if (!(globals is Array) || !(statics is Array))
            throw AhfError("payload fields 'globals' and 'statics' must be lists", ErrCode.BAD_PAYLOAD)
        out := Map("taken", [], "kept", [], "failed", [])
        for item in globals
            this._One(out, "global", item)
        for item in statics
            this._One(out, "static", item)
        return out
    }

    ; One entry: a Map with name, type, content (and flowId for a static variable).
    _One(out, scope, item) {
        ref := Map("scope", scope, "flowId", "", "name", "")
        try {
            if (!(item is Map))
                throw AhfError("an entry must be an object", ErrCode.BAD_PAYLOAD)
            name := String(item.Get("name", ""))
            ref["name"] := name
            if (scope = "static") {
                flowId := String(item.Get("flowId", ""))
                ref["flowId"] := flowId
                if (!this._engine.flows.Has(flowId))
                    throw AhfError("flow '" flowId "' is not loaded", ErrCode.NOT_FOUND)
            }
            if (name = "" || VarNames.IsA(name))
                throw AhfError("'" name "' is not a variable that can be imported", ErrCode.BAD_PAYLOAD)
            table := this._engine.vars.Table(scope, ref["flowId"])
            if (table.Has(name)) {
                out["kept"].Push(ref)
                return
            }
            type := String(item.Get("type", "normal"))
            content := String(item.Get("content", ""))
            table[name] := (type = "object") ? VarValues.Import(Json.Parse(content)) : content
            this._engine.vars.Touch(scope, ref["flowId"], name)
            out["taken"].Push(ref)
        } catch as e {
            ref["message"] := e.Message
            out["failed"].Push(ref)
        }
    }
}
