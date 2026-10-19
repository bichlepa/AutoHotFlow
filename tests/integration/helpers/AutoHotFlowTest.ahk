#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046, E0075): the icon of the application belongs to the role tray (src/tray/Tray.ahk).
#NoTrayIcon

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
#Include ..\..\..\src\manager\Manager.ahk
#Include ..\..\..\src\tray\Tray.ahk
#Include ..\..\..\src\debugview\DebugView.ahk
#Include ..\..\..\src\triggerhost\TriggerHost.ahk
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
RoleRegistry.Register("manager", Manager)
RoleRegistry.Register("tray", Tray)
RoleRegistry.Register("debug", DebugView)
RoleRegistry.Register("triggerhost", TriggerHost)
RoleRegistry.Register("editor", PlaceholderRole)
AhfTestRolesFn := AhfRegisterTestRoles
Supervisor.StartDefault := ""          ; a test names its roles with --start (E0083)
Supervisor.TrayDefault := false      ; a test run starts the role tray only with --tray (no icon in a test run, E0046)

AhfMain((opts) => Supervisor.Run(opts))

; Registers the test roles. Called by AhfMain only with --test-roles.
AhfRegisterTestRoles() {
    RoleRegistry.Register("echo", EchoRole)
    RoleRegistry.Register("crasher", CrasherRole)
    RoleRegistry.Register("hanger", HangerRole)
    RoleRegistry.Register("slow_shutdown", SlowShutdownRole)
}
