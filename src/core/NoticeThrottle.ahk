#Requires AutoHotkey v2.0

; Throttle of notices (WI-0075, PROTOCOL 4.7): per key (a kind and a flow) the first notice goes out at once, the notices
; that come within the window are held back and counted. The count goes out with the next notice after the window, or
; with the timer that the caller arms (Engine: FlushDue). Pure state, no messages, no timers of its own: the caller passes
; the time, so the rule can be tested without waiting.
;
;   Offer(key, nowMs)   true: send this notice now. false: it is held back (Take gives the count later)
;   Take(key)           the number of notices held back for key since the last one that went out (and resets it)
;   Sent(key, nowMs)    a notice for key went out at nowMs (the trailing notice with the count counts as one)
;   DueMs(key, nowMs)   ms until the window of key ends (0 when it has ended)
class NoticeThrottle {
    static WINDOW_MS := 10000

    __New(windowMs := 10000) {
        this.windowMs := windowMs
        this._last := Map()       ; key -> time of the last notice that went out
        this._held := Map()       ; key -> notices held back since then
    }

    Offer(key, nowMs) {
        if (!this._last.Has(key) || nowMs - this._last[key] >= this.windowMs) {
            this._last[key] := nowMs
            return true
        }
        this._held[key] := this._held.Get(key, 0) + 1
        return false
    }

    Take(key) {
        n := this._held.Get(key, 0)
        if (n > 0)
            this._held.Delete(key)
        return n
    }

    Sent(key, nowMs) {
        this._last[key] := nowMs
    }

    DueMs(key, nowMs) {
        if (!this._last.Has(key))
            return 0
        left := this._last[key] + this.windowMs - nowMs
        return left > 0 ? left : 0
    }
}
