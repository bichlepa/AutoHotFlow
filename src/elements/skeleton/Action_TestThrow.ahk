#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element for the skeleton (WI-0009): always throws, the run must end with "exception".
class Action_TestThrow extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: throw"
    static Category() => "Test"

    static Run(ctx, params) {
        throw ElementError("test")
    }
}

ElementRegistry.Register(Action_TestThrow)
