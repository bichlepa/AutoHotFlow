#Requires AutoHotkey v2.0
#SingleInstance Off

; Single entry point of every role process (doc/ARCHITEKTUR.md D12, work_items/phase2/README.md):
;   AutoHotkey64.exe src\AutoHotFlow.ahk --role=<name> --session=<id> --hub=<pipe> --data=<dir> [--flow=<id>] [--hubHwnd=<n>] [--test-roles]
; --role=supervisor (or no --role) starts the supervisor (WI-07, src/supervisor/), which is not a Role.
; Exit codes: 0 normal end, 1 role or supervisor failed to start (also an error while the files load), 2 bad
; arguments, unknown role or a 32-bit interpreter,
; 3 role not implemented yet, 4 hub lost (orphan guard) or peer closed, 5 supervisor: a child was terminated,
; 6 a role: too many unexpected errors (Role.ERROR_LIMIT within Role.ERROR_WINDOW_MS, WI-23).
; No dialog is ever shown: every message goes to the console sink (stderr).
;
; Roles are included here, not loaded dynamically (WI-06). The test roles are compiled in, but they are
; registered only with --test-roles (WI-07), so a product start can never run them.
;
; The first two statements run before any #Include below, because included files may contain code on file level
; (the element files call ElementRegistry.Register there) and AHK runs it in text order, before AhfMain:
;  1. Only the 64-bit interpreter is supported (decision E4). Exit 2, message on stderr, no dialog.
;  2. AhfLoadError catches an error in that file-level code: message on stderr, exit 1, no dialog. AhfMain removes
;     it again before the supervisor or the role installs its own OnError handler.
if (A_PtrSize != 8) {
    AhfConsole("a0 entry: AutoHotFlow v2 needs the 64-bit AutoHotkey v2 interpreter (this one is " (A_PtrSize * 8)
        . "-bit: " A_AhkPath ")`n")
    ExitApp(2)
}
OnError(AhfLoadError)

#Include core\RoleRegistry.ahk
#Include supervisor\Supervisor.ahk
#Include engine\Engine.ahk
#Include worker\Worker.ahk
#Include storage\Storage.ahk
#Include manager\StubManager.ahk
#Include debugview\DebugView.ahk
#Include elements\skeleton\Trigger_Manual.ahk
#Include elements\skeleton\Action_Sleep.ahk
#Include elements\skeleton\Action_Do_nothing.ahk
#Include elements\skeleton\Action_TestThrow.ahk
#Include elements\skeleton\Action_TestBlockWorker.ahk
#Include elements\skeleton\Action_TestHangWorker.ahk
#Include elements\skeleton\Action_TestThrowWorker.ahk
#Include elements\skeleton\Action_TestEchoWorker.ahk
#Include elements\skeleton\Action_TestLongBlockWorker.ahk
#Include elements\skeleton\Action_TestFreezeWorker.ahk
#Include elements\skeleton\Action_TestFreezeTimeoutWorker.ahk
#Include ..\tests\integration\helpers\EchoRole.ahk
#Include ..\tests\integration\helpers\CrasherRole.ahk
#Include ..\tests\integration\helpers\HangerRole.ahk
#Include ..\tests\integration\helpers\SlowShutdownRole.ahk
#Include ..\tests\integration\helpers\RegisterFailure.ahk

AhfMain()

; Best effort write to stderr (no usable stderr: nothing happens). Used before Role.Console is loaded.
AhfConsole(text) {
    try {
        FileAppend(text, "**", "UTF-8-RAW")
    } catch {
        ; best effort
    }
}

; Handler for errors while the files are loaded and AhfMain starts (see above). Ends the process: a process whose
; element registration failed must not run on.
AhfLoadError(e, mode) {
    AhfConsole("a0 entry: error while loading: " Type(e) ": " e.Message " (" e.File ", line " e.Line ")`n")
    ExitApp(1)
}

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
        OnError(AhfLoadError, 0)     ; the supervisor installs its own handler
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
    OnError(AhfLoadError, 0)         ; the role installs its own handler in Start
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
    RoleRegistry.Register("manager", StubManager)   ; WI-13: stub only, needs --ui=stub
    RoleRegistry.Register("debug", DebugView)       ; WI-28: the debug window (--headless without a window)
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
