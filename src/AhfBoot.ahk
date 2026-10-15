#Requires AutoHotkey v2.0
#SingleInstance Off

; Boot code that every role process shares (WI-0029, split by WI-0047-PREP). Each entry script includes this file first,
; then the code of its own role (and only that), registers the role and calls AhfMain (doc/ARCHITECTURE.md D0012, 8):
;   src\AutoHotFlow.ahk      the supervisor, the file the user starts; it starts the other roles from src\entry\<role>.ahk
;   src\entry\<role>.ahk    storage, engine, worker, manager, debug, triggerhost, editor
; Command line of a role (the supervisor builds it, Children._Launch):
;   AutoHotkey64.exe src\entry\<role>.ahk --role=<name> --session=<id> --hub=<pipe> --data=<dir> [--flow=<id>] [--hubHwnd=<n>] [--test-roles]
; The supervisor takes only --session, --data, --start and the like (doc/PROTOCOL.md section 5a).
; Exit codes: 0 normal end, 1 role or supervisor failed to start (also an error while the files load), 2 bad
; arguments, unknown role (a role that the entry does not register) or a 32-bit interpreter,
; 3 role not implemented yet, 4 hub lost (orphan guard) or peer closed, 5 supervisor: a child was terminated,
; 6 a role: too many unexpected errors (Role.ERROR_LIMIT within Role.ERROR_WINDOW_MS, WI-0023).
; No dialog is ever shown: every message goes to the console sink (stderr).
;
; Roles are included by the entry scripts, not here, and not loaded dynamically (WI-0006). The element classes of a role
; are the generated block src\entry\generated\Elements_<role>.ahk (tools/gen_element_includes.py, E0041). The test roles
; are not part of src/: the test entries in tests/integration/helpers include this file, add the test roles and the test
; elements and register the roles only with --test-roles (WI-0007, WI-0029).
;
; The first two statements run before any #Include below, because included files may contain code on file level
; (the element files call ElementRegistry.Register there) and AHK runs it in text order, before AhfMain:
;  1. Only the 64-bit interpreter is supported (decision E0004). Exit 2, message on stderr, no dialog.
;  2. AhfLoadError catches an error in that file-level code: message on stderr, exit 1, no dialog. AhfMain removes
;     it again before the supervisor or the role installs its own OnError handler.
if (A_PtrSize != 8) {
    AhfConsole("a0 entry: AutoHotFlow v2 needs the 64-bit AutoHotkey v2 interpreter (this one is " (A_PtrSize * 8)
        . "-bit: " A_AhkPath ")`n")
    ExitApp(2)
}
OnError(AhfLoadError)

#Include core\RoleRegistry.ahk
; The test entry (tests/integration/helpers/AutoHotFlowTest.ahk) sets this to a function that registers the test roles.
; The product entry leaves it empty, so --test-roles does nothing there.
global AhfTestRolesFn := ""

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

; supervisorFn: the supervisor entry passes a function that runs the supervisor with the options (it is not a Role). The
; other entries leave it empty, so for them "--role=supervisor" is an unknown role. The entry has registered its role
; in RoleRegistry before it calls AhfMain.
AhfMain(supervisorFn := "") {
    Persistent()
    Log.Configure(Role.ConsoleFn)
    opts := ""
    try {
        opts := Args.Parse(A_Args)
    } catch as e {
        AhfExit(2, "bad arguments: " e.Message)
    }
    if (opts.Has("test-roles") && AhfTestRolesFn != "")
        AhfTestRolesFn()
    roleName := opts.Get("role", supervisorFn != "" ? "supervisor" : "")
    if (supervisorFn != "" && roleName = "supervisor") {
        OnError(AhfLoadError, 0)     ; the supervisor installs its own handler
        try {
            supervisorFn(opts)
        } catch as e {
            AhfExit(1, "supervisor failed to start: " Type(e) ": " e.Message)
        }
        return
    }
    cls := RoleRegistry.Lookup(roleName)
    if (cls = "")
        AhfExit(2, "unknown role '" roleName "'")
    try {
        Args.Require(opts, ["session", "hub", "data"])
    } catch as e {
        AhfExit(2, e.Message)
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

AhfExit(code, text) {
    Role.Console("a0", "entry", text)
    ExitApp(code)
}
