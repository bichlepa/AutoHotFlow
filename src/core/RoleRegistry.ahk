#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include Role.ahk

; Maps the role name of --role to its class (v2-phase2-final:work_items/phase2/WI-0006-role-basis.md). Lookup is case-insensitive.
; Each entry script calls RoleRegistry.Register(<name>, <class>) for its role after it has included the
; role files; there is no dynamic loading. Names with a suffix ("editor:Flow 1") are looked up
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

; Nothing is registered here. Each entry script registers its own role before it calls AhfMain (WI-0047-PREP, E0041),
; so a process knows only the role it was started for: src/entry/<role>.ahk. "supervisor" is not a Role (WI-0007);
; src/AutoHotFlow.ahk runs it directly. Every role is written now (the placeholder of WI-0047-PREP is gone, WI-0088).
