#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include Role.ahk
#Include PlaceholderRole.ahk

; Maps the role name of --role to its class (v2-phase2-final:work_items/phase2/WI-0006-role-basis.md). Lookup is case-insensitive.
; Each role file ends with RoleRegistry.Register(<name>, <class>); the entry point includes the
; role files, there is no dynamic loading. Names with a suffix ("editor:Flow 1") are looked up
; by their base name ("editor").
;
;   RoleRegistry.Register("engine", EngineRole)
;   cls := RoleRegistry.Lookup("editor:Flow 1")      ; class or "" when unknown
class RoleRegistry {
    static roles := Map()

    ; Runs once when the class is loaded. The key case must be set before the first insert.
    static __New() {
        this.roles.CaseSense := "Off"
    }

    ; Registers a role class. Throws AhfError for an invalid name, a non-Role class or a duplicate.
    static Register(name, cls) {
        if (name = "" || Type(cls) != "Class" || !HasBase(cls, Role))
            throw AhfError("RoleRegistry.Register: needs a name and a Role class", ErrCode.BAD_ARGS)
        if (this.roles.Has(name))
            throw AhfError("RoleRegistry.Register: duplicate role '" name "'", ErrCode.CONFLICT)
        this.roles[name] := cls
    }

    ; Returns the class for a role name (suffix after ":" ignored), or "" if unknown.
    static Lookup(name) => this.roles.Get(Role.BaseName(name), "")
}

; "supervisor" is not registered here: it is not a Role (WI-0007) and the entry point starts it directly.
; "storage" is registered by the entry point (WI-0012, src/storage/Storage.ahk), like "engine" below.
; "engine" is registered by the entry point (WI-0010, src/engine/Engine.ahk): core/ must not include
; role folders, so the real class cannot be named here.
RoleRegistry.Register("triggerhost", PlaceholderRole)  ; WI-0014
RoleRegistry.Register("editor", PlaceholderRole)       ; later phase
; "worker" is registered by the entry point (WI-0011, src/worker/Worker.ahk), like "engine" (see above).
; "manager" is registered by the entry point (WI-0013, src/manager/StubManager.ahk), like "storage". Registering it
; here as well would make the entry point's Register throw (duplicate role).
