#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Walking-skeleton version of the v1 Action "Do nothing". Phase 2 only.
class Action_Do_nothing extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => "Do nothing"
    static Category() => "Flow_control"

    static Run(ctx, params) {
        ctx.Finish("normal")
    }
}
