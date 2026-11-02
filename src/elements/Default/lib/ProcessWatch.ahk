#Requires AutoHotkey v2.0
#Include ..\..\..\core\ElementError.ahk
#Include ..\..\..\core\Lang.ahk
#Include WatchPoll.ahk
#Include ProcessSnapshot.ahk
#Include WindowIdent.ahk     ; WindowIdent._Flag reads the checkbox values (0 or 1), as the window triggers do

; The shared logic of the two process triggers of the package Default (WI-0132, REQ-TRG-270): Process starts and Process
; closes. Each poll takes the process list (WatchPoll.Processes, one snapshot per interval for all process triggers) and
; compares the processes that match the filter with the last poll. The rules are those of v1
; (Source_Elements/Default/Triggers/Process_*.ahk); the differences are in MIGRATION (M-0169).
;
;   starts   the matching processes of the arming are the baseline when NotTriggerOnEnable is set; otherwise every
;            matching process fires at the first poll. Fires once for each new process ID.
;   closes   the matching processes at the arming are the baseline; fires once for each process ID that is gone.
;
; The filter is the process name (not case-sensitive) or the process ID; an empty filter matches every process.
class ProcessWatch {
    ; Arms the trigger of a kind: "starts" or "closes". Throws ElementError with the v1 text for an interval that is not
    ; a number above 0.
    static Arm(ctx, params, kind) {
        periodMs := WatchPoll.PeriodMs(params.HasProp("interval") ? params.interval : "")
        filter := ProcessWatch._Text(params, "ProcessName")
        notTrigger := WindowIdent._Flag(params, "NotTriggerOnEnable", "NotTriggerOnEnable")
        s := ctx.State
        s.kind := kind
        s.filter := filter
        s.periodMs := periodMs
        s.seen := Map()          ; pid -> base name of the matching processes of the last poll
        if (kind = "closes" || notTrigger)
            s.seen := ProcessSnapshot.Matching(WatchPoll.Processes(true), filter)
        WatchPoll.Subscribe(ctx, periodMs, ctx.Guard(() => ProcessWatch.Tick(ctx)))
        s.subscribed := true
        return ""
    }

    ; Removes the subscription of the arming. Nothing to do when Arm failed before the subscription.
    static Disarm(ctx) {
        if (ctx.State.HasProp("subscribed"))
            WatchPoll.Unsubscribe(ctx, ctx.State.periodMs)
    }

    ; One poll of the trigger. Fires with Map("processID", pid, "processName", name).
    static Tick(ctx) {
        s := ctx.State
        current := ProcessSnapshot.Matching(WatchPoll.Processes(), s.filter)
        if (s.kind = "starts") {
            for pid, name in current {
                if (!s.seen.Has(pid))
                    ctx.Fire(Map("processID", pid, "processName", name))
            }
        } else {
            for pid, name in s.seen {
                if (!current.Has(pid))
                    ctx.Fire(Map("processID", pid, "processName", name))
            }
        }
        s.seen := current
    }

    ; The thread variables of the event (the names of v1 Process_closes; Process_starts sets the same ones).
    static Variables(data) {
        if (!(data is Map) || !data.Has("processID"))
            return Map()
        return Map("A_ProcessID", data["processID"], "A_ProcessName", data["processName"])
    }

    ; A text parameter, trimmed; "" when missing or an object.
    static _Text(params, key) {
        if (!params.HasProp(key))
            return ""
        value := params.%key%
        return IsObject(value) ? "" : Trim(String(value))
    }
}
