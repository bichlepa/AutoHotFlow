#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046): only the product manager (src/entry/manager.ahk) keeps its icon.
#NoTrayIcon

; Test role slow_shutdown (WI-0047-PREP): only the shared boot code and the role. Registered with --test-roles only.
#Include ..\..\..\..\..\src\AhfBoot.ahk
#Include ..\..\SlowShutdownRole.ahk

AhfTestRolesFn := AhfRegisterTestRole

AhfMain()

AhfRegisterTestRole() {
    RoleRegistry.Register("slow_shutdown", SlowShutdownRole)
}
