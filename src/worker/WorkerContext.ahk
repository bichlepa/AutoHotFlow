#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\elements\base\ExecContext.ahk
#Include ..\elements\base\ParamEvaluator.ahk

; Context of one worker execution (WI-11, ELEMENT-API-V2 section 3). It is the ExecContext of the
; engine without access to engine data: the worker holds no variables of the engine. Values come in
; through imports (read-only, copied by the engine) and go out through exports (collected and sent
; with evt.worker.done). Finish, After, State and Log work as in the engine.
;
; Parameters (E26, WI-42): the engine evaluated them before it sent the job (evaluated: an Array of Maps {id, value}
; or {id, error} in the order of Parameters()). EvalParams and EvalMoreParams return these values and throw at the
; first error of a parameter that is asked for. GetVar and GetVarType read the imported copy of the visible loop,
; thread and instance variables. The other variable functions need the engine: they come with ctx.Request (R4, S2)
; and throw until then.
;
; onFinish(ctx, result, msg) is set by Worker (see ExecContext).
class WorkerContext extends ExecContext {
    static _NONE := Object()            ; returned by _FindImport when there is no such variable

    __New(flowId, elementId, instanceId, threadId, imports, onFinish := "", evaluated := "") {
        super.__New(flowId, elementId, instanceId, threadId, onFinish)
        this.imports := WorkerContext._Map(imports)
        this.exports := WorkerContext._Map("")
        this.evaluated := (evaluated is Array) ? evaluated : []
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

    ; The parameters that the engine evaluated (E26), without the ids in skipList. Throws ElementError at the first
    ; parameter with an error that is not skipped.
    EvalParams(params, skipList := "") {
        return this._FromEvaluated({}, ParamEvaluator.NameSet(skipList), "")
    }

    ; The parameters names (Array or text with commas) from what the engine evaluated, added to evaluated.
    EvalMoreParams(evaluated, params, names) {
        return this._FromEvaluated(IsObject(evaluated) ? evaluated : {}, ParamEvaluator.NameSet(""), ParamEvaluator.NameSet(names))
    }

    _FromEvaluated(out, skip, only) {
        for entry in this.evaluated {
            if (!(entry is Map) || !entry.Has("id"))
                continue
            id := String(entry["id"])
            if (skip.Has(id) || (IsObject(only) && !only.Has(id)))
                continue
            if (entry.Has("error"))
                throw ElementError(String(entry["error"]))
            out.%id% := WorkerContext.FromWire(entry.Has("value") ? entry["value"] : "")
        }
        return out
    }

    ; A variable or a member ("list.1") from the imported copy (visible loop, thread and instance variables), as a
    ; copy; default if it is not there. Hidden, global, static and built-in variables are not in the copy (R4, S2).
    GetVar(name, default := "", hidden := false) {
        found := hidden ? WorkerContext._NONE : this._FindImport(name)
        return (found == WorkerContext._NONE) ? default : WorkerContext.FromWire(found)
    }

    ; "object", "normal" or "" for a variable of the imported copy (see GetVar).
    GetVarType(name, hidden := false) {
        found := hidden ? WorkerContext._NONE : this._FindImport(name)
        if (found == WorkerContext._NONE)
            return ""
        return IsObject(found) ? "object" : "normal"
    }

    SetVar(name, value, scope := "", hidden := false) {
        throw ElementError("SetVar is not available in a worker, use Export")
    }

    ; Every other variable function needs the variables of the engine.
    _Vars() {
        throw ElementError("this variable function is not available in a worker yet (it comes with ctx.Request, R4); "
            . "use GetVar or GetImport for the copy of the variables, Export to set one")
    }

    _FindImport(name) {
        parts := StrSplit(String(name), ".")
        if (parts.Length = 0 || !this.imports.Has(parts[1]))
            return WorkerContext._NONE
        value := this.imports[parts[1]]
        loop parts.Length - 1 {
            if (!(value is Map))
                return WorkerContext._NONE
            key := WorkerContext.NormKey(parts[A_Index + 1])
            if (value.Has(key))
                value := value[key]
            else if (Type(key) = "Integer" && value.Has(String(key)))
                value := value[String(key)]
            else
                return WorkerContext._NONE
        }
        return value
    }

    ; A value as the engine has it (VarValues of the engine): JSON has no Integer keys, so a key of decimal digits
    ; becomes the Integer again (VarValues.NormKey); objects are Maps with case-insensitive keys; null is the empty
    ; text, true and false are 1 and 0. A copy.
    static FromWire(value) {
        if (value is Map) {
            m := Map()
            m.CaseSense := "Off"
            for k, v in value
                m[WorkerContext.NormKey(k)] := WorkerContext.FromWire(v)
            return m
        }
        if (value is Array) {
            m := Map()
            m.CaseSense := "Off"
            for v in value
                m[A_Index] := WorkerContext.FromWire(IsSet(v) ? v : "")
            return m
        }
        if (IsObject(value)) {
            if (value == Json.True)
                return 1
            if (value == Json.False)
                return 0
            return ""
        }
        return value
    }

    ; The key of a member as the engine stores it (the rule of VarValues.NormKey, which lives in the engine and cannot
    ; be included by the worker role).
    static NormKey(key) {
        if (Type(key) = "Integer")
            return key
        k := String(key)
        return RegExMatch(k, "^-?[0-9]{1,18}$") ? Integer(k) : k
    }

    ; A case-insensitive copy of a Map (variable names are case-insensitive, as in v1), values as FromWire.
    static _Map(source) {
        m := Map()
        m.CaseSense := "Off"
        if (source is Map)
            for k, v in source
                m[k] := WorkerContext.FromWire(v)
        return m
    }
}
