#Requires AutoHotkey v2.0

; Test role "echo" for tests/integration/test_role.py (WI-0006). Not part of the product: the entry
; point includes this file only so that the tests can start a role that answers and ends.
; It needs no includes of its own: Role and RoleRegistry are included by src/AutoHotFlow.ahk first.
;
;   cmd.test.echo {...}          -> {echo: <payload>}
;   cmd.test.log {count, level, text}  -> writes count entries (default a1 "entry <n>", or text), {logged}
;   cmd.test.stderr {text}       -> one line on stderr (Role.Console), the supervisor logs it (WI-0023)
;   cmd.test.logstate            -> {queued, dropped, last}
;   cmd.test.setlogtarget {to}   -> Role.SetLogTarget(to)
;   cmd.test.dump {title, value, kind, count} -> Debug.Dump (WI-0028). kind: "value" (default, the value of the request),
;                                   "cycle" (a Map that contains itself), "big" (a 200000 character text), "deep" (30 levels),
;                                   "objects" (functions and a class instance). count: how many times (default 1).
;                                   Answer: {sent, dropped, failed} (the counters of Debug)
;   cmd.test.throwlater {count}  -> count errors thrown from timers (default 1); the role keeps running
;                                   until the limit of Role.ERROR_LIMIT is exceeded (WI-0023)
;
;   cmd.test.args               -> {flowId, name}: what the command line gave the role (WI-0087, round trip of --flow)
;
; sys.shutdown is handled by the base class (sys.bye, exit 0).
;
; Test option in the name (WI-0034, F-0037): "echo:slowhello<ms>" (the flow part of the name) starts its connection to the
; hub only <ms> after the process start, so a test can end the session while this child is still starting and says
; sys.hello during the shutdown. The supervisor needs no option for it (it starts the child as --flow=slowhello<ms>).
class EchoRole extends Role {
    Start() {
        if (RegExMatch(this.flowId, "^slowhello(\d+)$", &m)) {
            SetTimer(ObjBindMethod(this, "_StartLate"), -Integer(m[1]))
            return
        }
        super.Start()
    }

    _StartLate() {
        try {
            super.Start()
        } catch as e {
            Role.Console("a0", "echo", this.name " failed to start late: " Type(e) ": " e.Message)
            ExitApp(1)
        }
    }

    RegisterHandlers() {
        this.On("cmd.test.echo", (msg) => Map("echo", msg.payload))
        this.On("cmd.test.log", (msg) => this._LogMany(msg.payload.Get("count", 0), msg.payload.Get("level", "a1")
            , msg.payload.Get("text", "")))
        this.On("cmd.test.stderr", (msg) => this._Stderr(msg.payload.Get("text", "")))
        this.On("cmd.test.logstate", (msg) => this.LogStats())
        this.On("cmd.test.setlogtarget", (msg) => this._SetTarget(msg.payload["to"]))
        this.On("cmd.test.throwlater", (msg) => this._ScheduleThrow(msg.payload.Get("count", 1)))
        this.On("cmd.test.dump", (msg) => this._Dump(msg.payload))
        this.On("cmd.test.args", (msg) => Map("flowId", this.flowId, "name", this.name))   ; WI-0087: command line round trip
    }

    _LogMany(count, level, text) {
        loop count
            Log.Write(level, "echo", (text = "") ? "entry " A_Index : text)
        return Map("logged", count)
    }

    _Dump(p) {
        kind := p.Get("kind", "value")
        value := p.Get("value", "")
        if (kind = "cycle") {
            value := Map("name", "loop")
            value["self"] := value
        } else if (kind = "big") {
            value := Format("{:200000}", "")
        } else if (kind = "deep") {
            value := Map("leaf", 1)
            loop 30
                value := Map("next", value)
        } else if (kind = "objects") {
            value := Map("fn", StrLen, "bound", ObjBindMethod(this, "_Stderr"), "role", this, "plain", {a: 1, b: [1, 2]})
        }
        sent := 0
        loop p.Get("count", 1)
            sent += Debug.Dump(value, p.Get("title", "")) ? 1 : 0
        return Map("sentNow", sent, "sent", Debug.sent, "dropped", Debug.dropped, "failed", Debug.failed)
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
