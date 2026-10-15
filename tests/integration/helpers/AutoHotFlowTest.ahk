#Requires AutoHotkey v2.0
#SingleInstance Off

; Test entry point (WI-0029, changed by WI-0047-PREP): the supervisor with the test roles, and every product role in one
; process, so that a test can start a role directly (--role=engine ...). The supervisor started from this file starts its
; children from entry\ next to this file (the role entries of the tests, with the test elements) and, with
; --test-roles, from entry\test\ (the test roles). The roles are registered here without the selection by Mode of the
; product role entries: this entry parses all classes.
;   AutoHotkey64.exe tests\integration\helpers\AutoHotFlowTest.ahk --role=... --test-roles
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include ..\..\..\src\AhfBoot.ahk
#Include ..\..\..\src\supervisor\Supervisor.ahk
#Include ..\..\..\src\engine\Engine.ahk
#Include ..\..\..\src\worker\Worker.ahk
#Include ..\..\..\src\storage\Storage.ahk
#Include ..\..\..\src\manager\StubManager.ahk
#Include ..\..\..\src\debugview\DebugView.ahk
#Include ..\..\..\src\core\PlaceholderRole.ahk
#Include ..\..\..\src\entry\generated\Elements_engine.ahk
#Include entry\generated\TestElements_engine.ahk
#Include TestDialogProvider.ahk
#Include EchoRole.ahk
#Include CrasherRole.ahk
#Include HangerRole.ahk
#Include SlowShutdownRole.ahk
#Include RegisterFailure.ahk

TestDialogProvider.Register()   ; dialogs of elements are answered from the script of the test (E0038)
RoleRegistry.Register("engine", Engine)
RoleRegistry.Register("worker", Worker)
RoleRegistry.Register("storage", Storage)
RoleRegistry.Register("manager", StubManager)
RoleRegistry.Register("debug", DebugView)
RoleRegistry.Register("triggerhost", PlaceholderRole)
RoleRegistry.Register("editor", PlaceholderRole)
AhfTestRolesFn := AhfRegisterTestRoles

AhfMain((opts) => Supervisor.Run(opts))

; Registers the test roles. Called by AhfMain only with --test-roles.
AhfRegisterTestRoles() {
    RoleRegistry.Register("echo", EchoRole)
    RoleRegistry.Register("crasher", CrasherRole)
    RoleRegistry.Register("hanger", HangerRole)
    RoleRegistry.Register("slow_shutdown", SlowShutdownRole)
}
