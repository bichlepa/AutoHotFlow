#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test trigger of WI-0061: fires every Interval ms (default 100) with the counter `count` in its data (1, 2, ...). The
; timer is a chain of one-shot timers (ctx.After), so a disarm cancels the next one.
class Trigger_TestTimer extends AhfElement {
    static Mode := "trigger"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: timer trigger"
    static Category() => "Test"
    ; The interval is a declared parameter, so a flow can set it (WI-0062 tests of the arming). Empty: 100 ms.
    static Parameters(ctx) => [{id: "Interval", content: "integer"}]
    ; The counter of the event is the thread variable A_TestCount (as a v1 trigger sets its A_ variables).
    static TriggerVariables(params, data) => Map("A_TestCount", (IsObject(data) && data.Has("count")) ? data["count"] : 0)

    static Enable(ctx, params) {
        interval := params.HasProp("Interval") && params.Interval != "" ? Integer(params.Interval) : 100
        ctx.State.count := 0
        this._Schedule(ctx, interval)
    }

    static Disable(ctx) {
    }

    static _Schedule(ctx, interval) {
        ctx.After(interval, () => this._Tick(ctx, interval))
    }

    static _Tick(ctx, interval) {
        ctx.State.count += 1
        ctx.Fire(Map("count", ctx.State.count))
        this._Schedule(ctx, interval)
    }
}
