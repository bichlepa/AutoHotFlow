#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk

; In-memory variables for inline elements, Phase 2 (WI-09): scopes "thread" and "instance" only.
; Other scopes (loop, static, global) come with the engine role (Phase 3). Names are case-insensitive,
; as in v1. The maps can be shared: the engine passes the instance map to all threads of an instance.
class VarStore {
    __New(instanceVars := "", threadVars := "") {
        this.instance := IsObject(instanceVars) ? instanceVars : VarStore.NewMap()
        this.thread := IsObject(threadVars) ? threadVars : VarStore.NewMap()
    }

    static NewMap() {
        m := Map()
        m.CaseSense := "Off"
        return m
    }

    ; Sets a value. An empty scope means "thread".
    Set(scope, name, value) {
        this._Store(scope)[name] := value
    }

    ; Reads a value from one scope. Returns default if the name is not set there.
    Get(scope, name, default := "") {
        store := this._Store(scope)
        return store.Has(name) ? store[name] : default
    }

    ; Looks in the thread scope first, then in the instance scope.
    Find(name, default := "") {
        if (this.thread.Has(name))
            return this.thread[name]
        if (this.instance.Has(name))
            return this.instance[name]
        return default
    }

    _Store(scope) {
        s := StrLower(scope)
        if (s = "" || s = "thread")
            return this.thread
        if (s = "instance")
            return this.instance
        throw ElementError("variable scope '" scope "' is not supported in this phase")
    }
}
