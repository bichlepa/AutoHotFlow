#Requires AutoHotkey v2.0
#SingleInstance Off

; Single entry point of every role process (doc/ARCHITEKTUR.md D12, work_items/phase2/README.md):
;   AutoHotkey64.exe src\AutoHotFlow.ahk --role=<name> --session=<id> --hub=<pipe> --data=<dir> [--flow=<id>] [--hubHwnd=<n>] [--test-roles]
; --role=supervisor (or no --role) starts the supervisor (WI-07, src/supervisor/), which is not a Role.
; Exit codes: 0 normal end, 1 role or supervisor failed to start, 2 bad arguments or unknown role,
; 3 role not implemented yet, 4 hub lost (orphan guard) or peer closed, 5 supervisor: a child was terminated.
; No dialog is ever shown: every message goes to the console sink (stderr).
;
; Roles are included here, not loaded dynamically (WI-06). The test roles are compiled in, but they are
; registered only with --test-roles (WI-07), so a product start can never run them.
#Include core\RoleRegistry.ahk
#Include supervisor\Supervisor.ahk
#Include engine\Engine.ahk
#Include worker\Worker.ahk
#Include storage\Storage.ahk
#Include elements\skeleton\Trigger_Manual.ahk
#Include elements\skeleton\Action_Sleep.ahk
#Include elements\skeleton\Action_Do_nothing.ahk
#Include elements\skeleton\Action_TestThrow.ahk
#Include elements\skeleton\Action_TestBlockWorker.ahk
#Include elements\skeleton\Action_TestHangWorker.ahk
#Include elements\skeleton\Action_TestThrowWorker.ahk
#Include elements\skeleton\Action_TestEchoWorker.ahk
#Include ..\tests\integration\helpers\EchoRole.ahk
#Include ..\tests\integration\helpers\CrasherRole.ahk
#Include ..\tests\integration\helpers\HangerRole.ahk
#Include ..\tests\integration\helpers\SlowShutdownRole.ahk

AhfMain()

AhfMain() {
    Persistent()
    Log.Configure(Role.ConsoleFn)
    AhfRegisterRoles()
    opts := ""
    try {
        opts := Args.Parse(A_Args)
    } catch as e {
        AhfExit(2, "bad arguments: " e.Message)
    }
    if (opts.Has("test-roles"))
        AhfRegisterTestRoles()
    roleName := opts.Get("role", "supervisor")
    if (roleName = "supervisor") {
        try {
            Supervisor.Run(opts)
        } catch as e {
            AhfExit(1, "supervisor failed to start: " Type(e) ": " e.Message)
        }
        return
    }
    cls := RoleRegistry.Lookup(roleName)
    if (cls = "")
        AhfExit(2, "unknown role '" roleName "'")
    if (Role.BaseName(roleName) != "supervisor") {
        try {
            Args.Require(opts, ["session", "hub", "data"])
        } catch as e {
            AhfExit(2, e.Message)
        }
    }
    ; Not named "role": AHK identifiers are case-insensitive, so it would shadow the class Role.
    roleObj := ""
    try {
        roleObj := cls(opts)
    } catch as e {
        AhfExit(2, "bad arguments: " e.Message)
    }
    try {
        roleObj.Start()
    } catch as e {
        AhfExit(1, roleObj.name " failed to start: " Type(e) ": " e.Message)
    }
}

; Registers the roles that the entry point itself knows (the others sit in RoleRegistry.ahk).
AhfRegisterRoles() {
    RoleRegistry.Register("engine", Engine)
    RoleRegistry.Register("worker", Worker)
    RoleRegistry.Register("storage", Storage)
}

; Registers the test roles (tests/integration/helpers). Called only with --test-roles.
AhfRegisterTestRoles() {
    RoleRegistry.Register("echo", EchoRole)
    RoleRegistry.Register("crasher", CrasherRole)
    RoleRegistry.Register("hanger", HangerRole)
    RoleRegistry.Register("slow_shutdown", SlowShutdownRole)
}

AhfExit(code, text) {
    Role.Console("a0", "entry", text)
    ExitApp(code)
}
