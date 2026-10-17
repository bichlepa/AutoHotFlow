#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Condition Do nothing of the package Default (WI-0052): finishes at once with the chosen result, "yes", "no" or
; "exception". Specification: the help text of v1 (help/en/Conditions/Do_nothing.html); parameter, defaults and language
; keys are those of v1 (Source_Elements/Default/Conditions/Do_nothing.ahk). A flow without the parameter (written before
; it existed) means "Yes", the default of the parameter. A value that is none of the three ends with "exception".
class Condition_Do_nothing extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "yellow.png"

    static Name() => Lang("Do nothing")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Result")},
        {type: "Radio", id: "executionResult", result: "enum", default: "Yes"
            , choices: [Lang("Yes"), Lang("No"), Lang("Exception")], enum: ["Yes", "No", "Exception"]}
    ]

    static GenerateName(ctx, params) => Lang("Do nothing")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        result := StrLower(String(p.executionResult))
        ctx.Finish((result = "yes" || result = "no") ? result : "exception")
    }
}
