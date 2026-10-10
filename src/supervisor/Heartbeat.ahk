#Requires AutoHotkey v2.0
#Include ..\core\Time.ahk
#Include Children.ahk

; Liveness of the child processes (doc/ARCHITEKTUR 6.2, WI-07): sys.ping every PING_EVERY_MS to each
; connected ready child, and a child counts as hung when no pong came for PONG_TIMEOUT_MS (three
; missed pings). A child that has not said sys.hello within STARTUP_MS (Children) is hung too.
; Hung children are handed to Children.MarkHung, which sends sys.shutdown and Children.Terminate
; after KILL_AFTER_MS. A frozen process (psutil suspend) is found this way; its pipe stays open.
;
;   heartbeat := Heartbeat(children, hub)
;   heartbeat.Tick(now)     ; called on every supervisor tick (200 ms)
class Heartbeat {
    static PING_EVERY_MS := 2000
    static PONG_TIMEOUT_MS := 6000

    __New(children, hub) {
        this.children := children
        this.hub := hub
        this._pingCount := 0
    }

    Tick(now) {
        for name in this.children.Names() {
            state := this.children.State(name)
            if (state = "starting") {
                if (this.children.StartedFor(name, now) >= Children.STARTUP_MS)
                    this.children.MarkHung(name, "no sys.hello within " Children.STARTUP_MS " ms")
            } else if (state = "ready" || state = "stopping") {
                if (this.children.SinceLastPong(name, now) >= Heartbeat.PONG_TIMEOUT_MS)
                    this.children.MarkHung(name, "no pong for " Heartbeat.PONG_TIMEOUT_MS " ms")
                else if (this.children.SinceLastPing(name, now) >= Heartbeat.PING_EVERY_MS)
                    this._Ping(name, now)
            } else if (state = "hung") {
                if (this.children.KillDue(name, now))
                    this.children.Terminate(name)
            }
        }
    }

    _Ping(name, now) {
        this._pingCount += 1
        this.children.MarkPing(name, now, this._pingCount)
        this.hub.Send(name, "sys.ping", Map("n", this._pingCount))
    }
}
