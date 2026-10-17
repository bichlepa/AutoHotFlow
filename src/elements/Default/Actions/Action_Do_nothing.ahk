#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Do nothing of the package Default (doc/ELEMENT-API-V2.md section 2): finishes at once with the chosen result.
; Metadata, parameters and language keys are those of v1 (Source_Elements/Default/Actions/Do_nothing.ahk).
class Action_Do_nothing extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "yellow.png"

    static Name() => Lang("Do nothing")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Result")},
        {type: "Radio", id: "executionResult", result: "enum", default: "Normal"
            , choices: [Lang("Normal"), Lang("Exception")], enum: ["Normal", "Exception"]}
    ]

    static GenerateName(ctx, params) => Lang("Do nothing")

    ; A flow without the parameter (written before it existed) means "Normal", the default of the parameter.
    static Run(ctx, params) {
        result := params.HasProp("executionResult") ? params.executionResult : "Normal"
        ctx.Finish((result = "normal") ? "normal" : "exception")
    }
}
