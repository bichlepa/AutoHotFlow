#Requires AutoHotkey v2.0
#Include ..\..\..\core\ElementError.ahk
#Include ..\..\..\core\Lang.ahk
#Include ProcessSnapshot.ahk

; The shared poll of the window and process triggers (WI-0132, ARCHITECTURE 2.3, trigger host). Each armed trigger
; subscribes with its interval; all subscribers with the same interval share ONE timer, so ten armed triggers with the
; same interval cost one timer and one tick per interval. A tick calls every subscriber of its interval in turn; the
; subscriber function is a guarded callback (ctx.Guard), so an error stays with its trigger.
;
; Processes: a tick takes one process snapshot, shared by the process triggers of its interval (Processes()). A
; subscriber that needs the list at its arming asks for a fresh one (fresh := true).
;
; The state is static: the trigger host is one process, and the subscriptions end with the arming (Unsubscribe).
class WatchPoll {
    ; interval (ms) -> Map("timer", function, "subs", Map(triggerKey -> Map("ctx", ctx, "fn", fn)))
    static _buckets := Map()
    static _generation := 0          ; counts the ticks of all buckets; a snapshot is valid for one generation
    static _snapshot := Map()
    static _snapshotGeneration := -1

    ; The period of a poll in milliseconds for an interval parameter. Throws ElementError with the v1 text for an
    ; interval that is not a number above 0. Below 1 ms the period is 1 ms (the timer resolution).
    static PeriodMs(interval) {
        if (IsObject(interval) || !IsNumber(interval) || interval <= 0)
            throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "interval", IsObject(interval) ? "" : interval))
        return Integer(Max(1, Round(interval)))
    }

    ; Adds the subscriber of a trigger context. fn is called every periodMs (a guarded function object). The first
    ; subscriber of an interval starts its timer.
    static Subscribe(ctx, periodMs, fn) {
        if (!WatchPoll._buckets.Has(periodMs)) {
            timer := () => WatchPoll._Tick(periodMs)
            WatchPoll._buckets[periodMs] := Map("timer", timer, "subs", Map())
            SetTimer(timer, periodMs)
        }
        WatchPoll._buckets[periodMs]["subs"][ctx.triggerKey] := Map("ctx", ctx, "fn", fn)
    }

    ; Removes the subscriber of this context from its interval. The timer of an interval without subscribers stops.
    static Unsubscribe(ctx, periodMs) {
        if (!WatchPoll._buckets.Has(periodMs))
            return
        bucket := WatchPoll._buckets[periodMs]
        subs := bucket["subs"]
        if (subs.Has(ctx.triggerKey) && subs[ctx.triggerKey]["ctx"] == ctx)
            subs.Delete(ctx.triggerKey)
        if (subs.Count = 0) {
            SetTimer(bucket["timer"], 0)
            WatchPoll._buckets.Delete(periodMs)
        }
    }

    ; The process list (WatchPoll-owned snapshot, ProcessSnapshot.Take). fresh := false reuses the snapshot of the
    ; current tick. Returns a Map pid -> base name (not a copy: do not change it).
    static Processes(fresh := false) {
        if (fresh || WatchPoll._snapshotGeneration != WatchPoll._generation) {
            WatchPoll._snapshot := ProcessSnapshot.Take()
            WatchPoll._snapshotGeneration := WatchPoll._generation
        }
        return WatchPoll._snapshot
    }

    ; The number of armed subscribers and of timers (for the tests and the diagnosis).
    static Counts() {
        subscribers := 0
        for periodMs, bucket in WatchPoll._buckets
            subscribers += bucket["subs"].Count
        return Map("timers", WatchPoll._buckets.Count, "subscribers", subscribers)
    }

    ; One tick of an interval: every subscriber that is still armed runs its function. A subscriber that throws is
    ; handled by its guard, the others run anyway.
    static _Tick(periodMs) {
        if (!WatchPoll._buckets.Has(periodMs))
            return
        WatchPoll._generation += 1
        entries := []
        for triggerKey, sub in WatchPoll._buckets[periodMs]["subs"]
            entries.Push(sub)
        for sub in entries {
            if (sub["ctx"].IsOpen)
                sub["fn"]()
        }
    }
}
