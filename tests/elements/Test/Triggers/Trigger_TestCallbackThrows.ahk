#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test trigger of WI-0061: every 100 ms its timer callback throws (round 1, 2, ...). The next round is scheduled before
; the throw, so the trigger stays armed and keeps reporting evt.trigger.error.
class Trigger_TestCallbackThrows extends AhfElement {
    static Mode := "trigger"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: trigger whose callback fails"
    static Category() => "Test"

    static Enable(ctx, params) {
        ctx.State.rounds := 0
        this._Schedule(ctx)
    }

    static Disable(ctx) {
    }

    static _Schedule(ctx) {
        ctx.After(100, () => this._Tick(ctx))
    }

    static _Tick(ctx) {
        ctx.State.rounds += 1
        this._Schedule(ctx)
        throw ElementError("test callback fails, round " ctx.State.rounds)
    }
}
