#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Search in a string of the package Default (WI-0119): writes the position of an occurrence of a text in a string
; (1 is the first character) to a variable. A text that is not found ends the element with exception and an empty
; variable, as in v1. Specification: the help text of v1 (help/en/Actions/Search_in_a_string.md). Class ID, parameter
; IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Search_in_a_string.ahk).
;
;   LeftOrRight  GoRight: the start position counts from the left and the occurrence from the left.
;                GoLeft: the start position counts from the right (1 is the last character) and the occurrence
;                from the right. The position written is always counted from the left.
;   Offset       the start position (1 or more)
;   OccurenceNumber  the occurrence (1 or more)
;
; An empty search text is never found (AutoHotkey throws for it; the element reports "not found" instead, decision of
; WI-0119, MIGRATION M-0111).
class Action_Search_in_a_string extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Search in a string")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable")},
        {type: "Edit", id: "Varname", default: "NewPosition", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "Expression", contentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Text to search")},
        {type: "Edit", id: "SearchText", default: "World", content: ["String", "Expression"], contentID: "IsExpressionSearchText", contentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which occurence")},
        {type: "Edit", id: "OccurenceNumber", default: 1, content: "PositiveInteger", WarnIfEmpty: true},
        {type: "Label", label: Lang("Start position")},
        {type: "Radio", id: "LeftOrRight", default: "GoRight", choices: [Lang("Search from left to right"), Lang("Search from right to left")], result: "enum", enum: ["GoRight", "GoLeft"]},
        {type: "Edit", id: "Offset", default: 1, content: "PositiveInteger", WarnIfEmpty: true},
        {type: "Label", label: Lang("Case sensitivity")},
        {type: "Radio", id: "CaseSensitive", default: "CaseInsensitive", choices: [Lang("Case insensitive"), Lang("Case sensitive")], result: "enum", enum: ["CaseInsensitive", "CaseSensitive"]}
    ]

    static GenerateName(ctx, params) {
        return Lang("Search in a string") " - " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "VarValue")
            . " - " TextOps.Par(params, "SearchText")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        haystack := TextOps.Text(p.VarValue, params.VarValue)
        needle := TextOps.Text(p.SearchText, params.SearchText)
        caseSense := (p.CaseSensitive = "CaseSensitive")
        fromRight := (p.LeftOrRight = "GoLeft")
        ; AutoHotkey: a negative start position and a negative occurrence search from the right (v1 used 1 - Offset)
        start := fromRight ? -p.Offset : p.Offset
        occurrence := fromRight ? -p.OccurenceNumber : p.OccurenceNumber
        found := (needle = "") ? 0 : InStr(haystack, needle, caseSense, start, occurrence)
        if (!found) {
            ctx.SetVar(p.Varname, "")
            throw ElementError(Lang("Searched text was not found"))
        }
        if (!ctx.SetVar(p.Varname, found))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
