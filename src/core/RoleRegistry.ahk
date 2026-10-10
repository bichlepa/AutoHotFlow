#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include Role.ahk

; Maps the role name of --role to its class (work_items/phase2/WI-06). Lookup is case-insensitive.
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

; Stand-in for roles that are not written yet. It reports that and ends with EXIT_NOT_IMPLEMENTED,
; so a missing role is visible at once and never opens a dialog. Replaced by the real class when
; the role is written (the registration below is then changed).
class PlaceholderRole extends Role {
    Start() {
        Role.Console("a0", "role", "role '" this.roleName "' is not implemented yet")
        ExitApp(Role.EXIT_NOT_IMPLEMENTED)
    }
}

; "supervisor" is not registered here: it is not a Role (WI-07) and the entry point starts it directly.
RoleRegistry.Register("storage", PlaceholderRole)      ; WI-12
; "engine" is registered by the entry point (WI-10, src/engine/Engine.ahk): core/ must not include
; role folders, so the real class cannot be named here.
RoleRegistry.Register("triggerhost", PlaceholderRole)  ; WI-14
RoleRegistry.Register("manager", PlaceholderRole)      ; WI-13
RoleRegistry.Register("editor", PlaceholderRole)       ; later phase
; "worker" is registered by the entry point (WI-11, src/worker/Worker.ahk), like "engine" (see above).
