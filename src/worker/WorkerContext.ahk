#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\elements\base\ExecContext.ahk

; Context of one worker execution (WI-11, ELEMENT-API-V2 section 3). It is the ExecContext of the
; engine without access to engine data: the worker holds no variables of the engine. Values come in
; through imports (read-only, copied by the engine) and go out through exports (collected and sent
; with evt.worker.done). Finish, After, State and Log work as in the engine.
;
; onFinish(ctx, result, msg) is set by Worker (see ExecContext).
class WorkerContext extends ExecContext {
    __New(flowId, elementId, instanceId, threadId, imports, onFinish := "") {
        super.__New(flowId, elementId, instanceId, threadId, onFinish)
        this.imports := WorkerContext._Map(imports)
        this.exports := WorkerContext._Map("")
    }

    ; Reads an imported value (a copy of an engine variable). Returns default when it was not imported.
    GetImport(name, default := "") {
        return this.imports.Get(name, default)
    }

    ; Sets an exported value. The engine receives it in evt.worker.done and stores it in the thread.
    Export(name, value) {
        if (IsObject(value))
            throw ElementError("Export: value of '" name "' must be a text or a number")
        this.exports[name] := value
    }

    ; Variables of the engine are not reachable from a worker (ARCHITECTURE 4). Use imports and exports.
    GetVar(name, default := "") {
        throw ElementError("GetVar is not available in a worker, use GetImport")
    }

    SetVar(name, value, scope := "") {
        throw ElementError("SetVar is not available in a worker, use Export")
    }

    ; A case-insensitive copy of a Map (variable names are case-insensitive, as in v1).
    static _Map(source) {
        m := Map()
        m.CaseSense := "Off"
        if (source is Map)
            for k, v in source
                m[k] := v
        return m
    }
}
