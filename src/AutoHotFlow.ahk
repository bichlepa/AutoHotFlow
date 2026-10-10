#Requires AutoHotkey v2.0
#SingleInstance Off

; Single entry point of every role process (doc/ARCHITEKTUR.md D12, work_items/phase2/README.md):
;   AutoHotkey64.exe src\AutoHotFlow.ahk --role=<name> --session=<id> --hub=<pipe> --data=<dir> [--flow=<id>] [--hubHwnd=<n>]
; Without --role (or with --role=supervisor) the supervisor role starts (WI-07, placeholder for now).
; Exit codes: 0 normal end, 1 role failed to start, 2 bad arguments or unknown role,
; 3 role not implemented yet, 4 hub lost (orphan guard) or peer closed.
; No dialog is ever shown: every message goes to the console sink (stderr).
;
; Roles are included here, not loaded dynamically (WI-06). Test roles are included as well and
; are registered only by name; no product code depends on them.
#Include core\RoleRegistry.ahk
#Include ..\tests\integration\helpers\EchoRole.ahk

AhfMain()

AhfMain() {
    Persistent()
    Log.Configure(Role.ConsoleFn)
    opts := ""
    try {
        opts := Args.Parse(A_Args)
    } catch as e {
        AhfExit(2, "bad arguments: " e.Message)
    }
    roleName := opts.Get("role", "supervisor")
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

AhfExit(code, text) {
    Role.Console("a0", "entry", text)
    ExitApp(code)
}
