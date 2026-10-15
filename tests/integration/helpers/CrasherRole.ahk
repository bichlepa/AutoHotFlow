#Requires AutoHotkey v2.0

; Test role "crasher" for tests/integration/test_supervisor.py (WI-0007). Not part of the product. It is
; registered only with --test-roles (src/AutoHotFlow.ahk). It does nothing until it gets cmd.test.arm;
; CRASH_AFTER_MS later it ends itself with TerminateProcess on its own handle: no sys.bye, no cleanup,
; which is how a crash looks to the supervisor. The arm message lets the test start watching the
; process before it dies. Under --test-roles the supervisor restarts it by policy
; (Children.TEST_AUTO_RESTART), so the restart limit can be tested.
class CrasherRole extends Role {
    static CRASH_AFTER_MS := 300
    static CrashFn := () => CrasherRole._Crash()

    RegisterHandlers() {
        this.On("cmd.test.arm", (msg) => this._Arm())
    }

    _Arm() {
        SetTimer(CrasherRole.CrashFn, -CrasherRole.CRASH_AFTER_MS)
        return Map()
    }

    ; -1 is the pseudo handle of the current process.
    static _Crash() {
        DllCall("TerminateProcess", "ptr", -1, "uint", 7)
    }
}
