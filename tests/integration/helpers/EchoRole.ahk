#Requires AutoHotkey v2.0

; Test role "echo" for tests/integration/test_role.py (WI-06). Not part of the product: the entry
; point includes this file only so that the tests can start a role that answers and ends.
; It needs no includes of its own: Role and RoleRegistry are included by src/AutoHotFlow.ahk first.
;
;   cmd.test.echo {...}          -> {echo: <payload>}
;   cmd.test.log {count, level, text}  -> writes count entries (default a1 "entry <n>", or text), {logged}
;   cmd.test.stderr {text}       -> one line on stderr (Role.Console), the supervisor logs it (WI-23)
;   cmd.test.logstate            -> {queued, dropped, last}
;   cmd.test.setlogtarget {to}   -> Role.SetLogTarget(to)
;   cmd.test.throwlater {count}  -> count errors thrown from timers (default 1); the role keeps running
;                                   until the limit of Role.ERROR_LIMIT is exceeded (WI-23)
;
; sys.shutdown is handled by the base class (sys.bye, exit 0).
class EchoRole extends Role {
    RegisterHandlers() {
        this.On("cmd.test.echo", (msg) => Map("echo", msg.payload))
        this.On("cmd.test.log", (msg) => this._LogMany(msg.payload.Get("count", 0), msg.payload.Get("level", "a1")
            , msg.payload.Get("text", "")))
        this.On("cmd.test.stderr", (msg) => this._Stderr(msg.payload.Get("text", "")))
        this.On("cmd.test.logstate", (msg) => this.LogStats())
        this.On("cmd.test.setlogtarget", (msg) => this._SetTarget(msg.payload["to"]))
        this.On("cmd.test.throwlater", (msg) => this._ScheduleThrow(msg.payload.Get("count", 1)))
    }

    _LogMany(count, level, text) {
        loop count
            Log.Write(level, "echo", (text = "") ? "entry " A_Index : text)
        return Map("logged", count)
    }

    _Stderr(text) {
        Role.Console("a0", "echo", text)
        return Map()
    }

    _SetTarget(address) {
        this.SetLogTarget(address)
        return Map()
    }

    ; One timer function per error. A closure that captures nothing is the same function object every time
    ; (SetTimer would only restart its timer), so each one captures its number (doc/HOW-TO.md).
    _ScheduleThrow(count) {
        loop count
            SetTimer(EchoRole._ThrowFn(A_Index), -10 * A_Index)
        return Map()
    }

    static _ThrowFn(n) => () => EchoRole._ThrowLater(n)

    static _ThrowLater(n) {
        throw ValueError("echo role: deliberate error from a timer (" n ")")
    }
}
