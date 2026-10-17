#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046, E0075): the icon of the application belongs to the role tray (src/tray/Tray.ahk).
#NoTrayIcon

; Test role crasher (WI-0047-PREP): only the shared boot code and the role. Registered with --test-roles only.
#Include ..\..\..\..\..\src\AhfBoot.ahk
#Include ..\..\CrasherRole.ahk

AhfTestRolesFn := AhfRegisterTestRole

AhfMain()

AhfRegisterTestRole() {
    RoleRegistry.Register("crasher", CrasherRole)
}
