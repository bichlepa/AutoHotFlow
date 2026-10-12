#Requires AutoHotkey v2.0
#Include Role.ahk

; Stand-in for roles that are not written yet. It reports that and ends with EXIT_NOT_IMPLEMENTED,
; so a missing role is visible at once and never opens a dialog. Replaced by the real class when
; the role is written (the registration below is then changed).
class PlaceholderRole extends Role {
    Start() {
        Role.Console("a0", "role", "role '" this.roleName "' is not implemented yet")
        ExitApp(Role.EXIT_NOT_IMPLEMENTED)
    }
}
