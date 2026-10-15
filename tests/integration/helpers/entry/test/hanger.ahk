#Requires AutoHotkey v2.0
#SingleInstance Off

; Test role hanger (WI-0047-PREP): only the shared boot code and the role. Registered with --test-roles only.
#Include ..\..\..\..\..\src\AhfBoot.ahk
#Include ..\..\HangerRole.ahk

AhfTestRolesFn := AhfRegisterTestRole

AhfMain()

AhfRegisterTestRole() {
    RoleRegistry.Register("hanger", HangerRole)
}
