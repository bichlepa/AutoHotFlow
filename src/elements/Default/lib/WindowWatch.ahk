#Requires AutoHotkey v2.0
#Include ..\..\..\core\ElementError.ahk
#Include ..\..\..\core\Lang.ahk
#Include WindowIdent.ahk
#Include WatchPoll.ahk

; The shared logic of the four window triggers of the package Default (WI-0132, REQ-TRG-260): Window opens, Window
; closes, Window gets active, Window gets inactive. Each trigger polls the windows that its identification names (WatchPoll,
; one timer per interval) and fires when the result changes. The rules are those of v1 (Source_Elements/Default/Triggers/
; Window_*.ahk); the differences are in MIGRATION (M-0177):
;
;   opens          the windows of the first poll are the baseline when NotTriggerOnEnable is set; otherwise every
;                  matching window fires at the first poll. Fires once for each new window ID.
;   closes         the windows at the arming are the baseline; fires once for each window ID that is gone.
;   gets active    the active matching window at the arming is the baseline when NotTriggerOnEnable is set; fires when
;                  a matching window becomes the active one (not for "no window").
;   gets inactive  the active matching window at the arming is the baseline; fires with the ID of the window that was
;                  active when that window stops being the active one.
;
; A window that opens and closes between two polls is not seen (polling, not a Windows event; the interval is the
; resolution, see the help page).
class WindowWatch {
    ; Arms the trigger of a kind: "opens", "closes", "active" or "inactive". The window identification and the interval
    ; are checked first (ElementError with the v1 texts), then the baseline is taken, then the subscription.
    static Arm(ctx, params, kind) {
        spec := WindowIdent.Spec(params)
        periodMs := WatchPoll.PeriodMs(params.HasProp("interval") ? params.interval : "")
        notTrigger := WindowIdent._Flag(params, "NotTriggerOnEnable", "NotTriggerOnEnable")
        s := ctx.State
        s.kind := kind
        s.spec := spec
        s.periodMs := periodMs
        s.seen := Map()          ; opens, closes: window ID -> true
        s.last := 0              ; gets active, gets inactive: the ID of the active matching window (0 = none)
        switch kind {
            case "opens":
                if (notTrigger)
                    s.seen := WindowWatch._SetOf(WindowIdent.List(spec))
            case "closes":
                s.seen := WindowWatch._SetOf(WindowIdent.List(spec))
            case "active":
                if (notTrigger)
                    s.last := WindowIdent.ActiveId(spec)
            case "inactive":
                s.last := WindowIdent.ActiveId(spec)
            default:
                throw ElementError("WindowWatch: unknown kind '" kind "'")
        }
        WatchPoll.Subscribe(ctx, periodMs, ctx.Guard(() => WindowWatch.Tick(ctx)))
        s.subscribed := true
        return ""
    }

    ; Removes the subscription of the arming. Nothing to do when Arm failed before the subscription.
    static Disarm(ctx) {
        if (ctx.State.HasProp("subscribed"))
            WatchPoll.Unsubscribe(ctx, ctx.State.periodMs)
    }

    ; One poll of the trigger (see the header). Fires with Map("windowID", id).
    static Tick(ctx) {
        s := ctx.State
        spec := s.spec
        switch s.kind {
            case "opens":
                current := WindowWatch._SetOf(WindowIdent.List(spec))
                for id in current {
                    if (!s.seen.Has(id))
                        ctx.Fire(Map("windowID", id))
                }
                s.seen := current
            case "closes":
                current := WindowWatch._SetOf(WindowIdent.List(spec))
                for id in s.seen {
                    if (!current.Has(id))
                        ctx.Fire(Map("windowID", id))
                }
                s.seen := current
            case "active":
                id := WindowIdent.ActiveId(spec)
                if (id != s.last) {
                    s.last := id
                    if (id)
                        ctx.Fire(Map("windowID", id))
                }
            case "inactive":
                id := WindowIdent.ActiveId(spec)
                if (id != s.last) {
                    previous := s.last
                    s.last := id
                    if (previous)
                        ctx.Fire(Map("windowID", previous))
                }
        }
    }

    ; The thread variable of the event (v1 a_WindowID). Data of a start by the engine is "" and sets nothing.
    static Variables(data) {
        if (!(data is Map) || !data.Has("windowID"))
            return Map()
        return Map("A_WindowID", data["windowID"])
    }

    ; A Map with every ID of the Array as a key (the set of the window IDs of one poll).
    static _SetOf(ids) {
        set := Map()
        for id in ids
            set[id] := true
        return set
    }
}
