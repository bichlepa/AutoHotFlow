#Requires AutoHotkey v2.0
#SingleInstance Off

; Test entry point (WI-29): the product boot code (src/AhfBoot.ahk) plus the test roles, which are registered only with
; --test-roles. The supervisor starts its children with A_ScriptFullPath, so they get this entry, too.
;   AutoHotkey64.exe tests\integration\helpers\AutoHotFlowTest.ahk --role=... --test-roles
#Include ..\..\..\src\AhfBoot.ahk
#Include EchoRole.ahk
#Include CrasherRole.ahk
#Include HangerRole.ahk
#Include SlowShutdownRole.ahk
#Include RegisterFailure.ahk

AhfTestRolesFn := AhfRegisterTestRoles

AhfMain()

; Registers the test roles. Called by AhfMain only with --test-roles.
AhfRegisterTestRoles() {
    RoleRegistry.Register("echo", EchoRole)
    RoleRegistry.Register("crasher", CrasherRole)
    RoleRegistry.Register("hanger", HangerRole)
    RoleRegistry.Register("slow_shutdown", SlowShutdownRole)
}
