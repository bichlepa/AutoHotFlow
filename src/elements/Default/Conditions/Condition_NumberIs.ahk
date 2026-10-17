#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Condition Number is of the package Default (WI-0052): "yes" if a number equals an expected number within a maximum
; difference. Specification: the help text of v1 (help/en/Conditions/Number is.html), with one exception: the help says
; that the relative difference is calculated with the (first) input number, but v1 calculates it with the EXPECTED
; number, and the v1 example flow tests/data/flows/v1_examples/Flow 1087828277.json depends on that
; (5.000500001 against 5 with the relative difference 0.0001 is "no"; with the input number it would be "yes"). The code
; wins here (MIGRATION M-0054). Parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Conditions/NumberIs.ahk).
;
;   expression         the input number (an expression)
;   expectedNumber     the expected number (an expression)
;   absoluteDeviation  maximum absolute difference, an expression for a number of 0 or more; empty means 0
;   relativeDeviation  maximum relative difference (a factor of the expected number); empty means 0
;
; "yes" if expected - d <= input <= expected + d, with d = absoluteDeviation + |expected| * relativeDeviation.
class Condition_NumberIs extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Number is")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Input number")},
        {type: "Edit", id: "expression", default: "5.0001", content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Expected number")},
        {type: "Edit", id: "expectedNumber", default: "5", content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Maximum difference")},
        {type: "Label", label: Lang("Absolute difference"), size: "small"},
        {type: "Edit", id: "absoluteDeviation", default: "0", content: "PositiveNumber"},
        {type: "Label", label: Lang("Relative difference"), size: "small"},
        {type: "Edit", id: "relativeDeviation", default: "0.01", content: "PositiveNumber"}
    ]

    static GenerateName(ctx, params) {
        return Lang("Number is") " - " (params.HasProp("expression") ? params.expression : "") " - "
            . (params.HasProp("expectedNumber") ? params.expectedNumber : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        input := Number(p.expression)
        expected := Number(p.expectedNumber)
        deviation := 0
        if (IsNumber(p.absoluteDeviation))
            deviation += Number(p.absoluteDeviation)
        if (IsNumber(p.relativeDeviation))
            deviation += Abs(expected) * Number(p.relativeDeviation)
        ctx.Finish((input >= expected - deviation && input <= expected + deviation) ? "yes" : "no")
    }
}
