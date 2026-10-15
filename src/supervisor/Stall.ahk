#Requires AutoHotkey v2.0

; Detects a stand-still of the supervisor itself (WI-0033, F-0016, E0012, doc/ARCHITECTURE 6.2): frozen process, standby, a long
; hub backlog. It is the only place that measures it: the gap between two ticks of the supervisor's timer.
; Every holder of a deadline (children, hub requests and connections without hello, shutdown, report) is told by the
; supervisor how long the stand-still was and moves its deadline by that time, so the rest of the time is kept.
;
;   stall := Stall(2000, 200)
;   stall.Arm(now)            ; once, when the timer starts: a stand-still before the first tick counts too
;   ms := stall.Check(now)    ; every tick, first. 0 = none, else the length of the stand-still in ms
class Stall {
    ; A gap between two ticks longer than this is a stand-still (the same as Heartbeat.PING_EVERY_MS).
    static MIN_GAP_MS := 2000

    __New(minGapMs, tickMs) {
        this.minGapMs := minGapMs
        this.tickMs := tickMs
        this._lastAt := 0
    }

    Arm(now) {
        this._lastAt := now
    }

    ; Returns the length of the stand-still in ms (the gap without one regular tick), or 0.
    Check(now) {
        last := this._lastAt
        this._lastAt := now
        if (last > 0 && now - last > this.minGapMs)
            return Integer(now - last - this.tickMs)
        return 0
    }
}
