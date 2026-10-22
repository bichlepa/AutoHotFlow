#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk
#Include ..\lib\ListOps.ahk

; Condition String contains text of the package Default (WI-0119): "yes" if a string starts with, ends with or contains a
; text, else "no". Specification: the help text of v1 (help/en/Conditions/String_Contains_Text.md). Class ID, parameter
; IDs, enum values, defaults and language keys are those of v1 (Source_Elements/Default/Conditions/String_Contains_Text.ahk).
;
; The defaults are the enum values (M-0099 for the numeric defaults of v1). A stored position (3 for "Contains anywhere")
; is read as the enum value at that position (ListOps.EnumValue), as a flow of v1 may hold it.
; An empty search text is refused by the parameter check (WarnIfEmpty); if a flow holds one anyway, it counts as found.
class Condition_String_Contains_Text extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("String Contains Text")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "Expression", ContentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Text to search")},
        {type: "Edit", id: "SearchText", default: "World", content: ["String", "Expression"], contentID: "IsExpressionSearchText", ContentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Search text position")},
        {type: "Radio", id: "WhereToBegin", default: "Anywhere", choices: [Lang("Starts with"), Lang("Ends with"), Lang("Contains anywhere")], result: "enum", enum: ["Start", "End", "Anywhere"]},
        {type: "Label", label: Lang("Case sensitivity")},
        {type: "Radio", id: "CaseSensitive", default: "CaseInsensitive", choices: [Lang("Case insensitive"), Lang("Case sensitive")], result: "enum", enum: ["CaseInsensitive", "CaseSensitive"]}
    ]

    static GenerateName(ctx, params) {
        where := ListOps.EnumValue(TextOps.Par(params, "WhereToBegin"), ["Start", "End", "Anywhere"])
        value := TextOps.Par(params, "VarValue")
        search := TextOps.Par(params, "SearchText")
        switch where {
            case "Start": text := Lang("'%1%' starts with '%2%'", value, search)
            case "End": text := Lang("'%1%' ends with '%2%'", value, search)
            default: text := Lang("'%1%' contains '%2%'", value, search)
        }
        caseText := (ListOps.EnumValue(TextOps.Par(params, "CaseSensitive"), ["CaseInsensitive", "CaseSensitive"])
            = "CaseSensitive") ? Lang("Case sensitive") : Lang("Case insensitive")
        return Lang("String Contains Text") " - " text " - " caseText
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        haystack := TextOps.Text(p.VarValue, params.VarValue)
        needle := TextOps.Text(p.SearchText, params.SearchText)
        caseSense := (ListOps.EnumValue(p.CaseSensitive, ["CaseInsensitive", "CaseSensitive"]) = "CaseSensitive")
        where := ListOps.EnumValue(p.WhereToBegin, ["Start", "End", "Anywhere"])
        cs := caseSense ? "On" : "Off"
        n := StrLen(needle)
        switch where {
            case "Anywhere":
                hit := (n = 0) || InStr(haystack, needle, caseSense) > 0
            case "Start":
                hit := (n = 0) || (n <= StrLen(haystack) && StrCompare(SubStr(haystack, 1, n), needle, cs) = 0)
            case "End":
                hit := (n = 0) || (n <= StrLen(haystack) && StrCompare(SubStr(haystack, StrLen(haystack) - n + 1), needle, cs) = 0)
            default:
                throw ElementError("String contains text: unknown position '" p.WhereToBegin "'")
        }
        ctx.Finish(hit ? "yes" : "no")
    }
}
