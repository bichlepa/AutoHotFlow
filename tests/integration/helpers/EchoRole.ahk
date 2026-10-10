#Requires AutoHotkey v2.0

; Test role "echo" for tests/integration/test_role.py (WI-06). Not part of the product: the entry
; point includes this file only so that the tests can start a role that answers and ends.
; It needs no includes of its own: Role and RoleRegistry are included by src/AutoHotFlow.ahk first.
;
;   cmd.test.echo {...}          -> {echo: <payload>}
;   cmd.test.log {count}         -> writes count a1 entries, {logged}
;   cmd.test.logstate            -> {queued, dropped, last}
;   cmd.test.setlogtarget {to}   -> Role.SetLogTarget(to)
;   cmd.test.throwlater          -> an error thrown from a timer; the role must keep running
;
; sys.shutdown is handled by the base class (sys.bye, exit 0).
class EchoRole extends Role {
    static ThrowFn := () => EchoRole._ThrowLater()

    RegisterHandlers() {
        this.On("cmd.test.echo", (msg) => Map("echo", msg.payload))
        this.On("cmd.test.log", (msg) => this._LogMany(msg.payload.Get("count", 0)))
        this.On("cmd.test.logstate", (msg) => this.LogStats())
        this.On("cmd.test.setlogtarget", (msg) => this._SetTarget(msg.payload["to"]))
        this.On("cmd.test.throwlater", (msg) => this._ScheduleThrow())
    }

    _LogMany(count) {
        loop count
            Log.Write("a1", "echo", "entry " A_Index)
        return Map("logged", count)
    }

    _SetTarget(address) {
        this.SetLogTarget(address)
        return Map()
    }

    _ScheduleThrow() {
        SetTimer(EchoRole.ThrowFn, -10)
        return Map()
    }

    static _ThrowLater() {
        throw ValueError("echo role: deliberate error from a timer")
    }
}
