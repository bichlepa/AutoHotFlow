#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Replace in a string of the package Default (WI-0119): replaces one or all occurrences of a text in a string and
; writes the result; the number of replacements goes to the thread variable a_numberOfReplacements (as v1).
; Specification: the help text of v1 (help/en/Actions/Replace_in_a_string.md). Class ID, parameter IDs, defaults and
; language keys are those of v1 (Source_Elements/Default/Actions/Replace_in_a_string.ahk).
;
; New in v2 (the owner's request of WI-0119, MIGRATION M-0108): TextMode "RegEx" searches with a regular expression
; (AutoHotkey v2 PCRE, RegExReplace). The plain text mode is the v1 one. In the RegEx mode the replacement can use $1,
; $2, ... for the groups of the pattern, as RegExReplace does; an invalid pattern ends the element with exception.
;
; An empty search text changes nothing (AutoHotkey refuses an empty needle; decision of WI-0119, MIGRATION M-0111).
class Action_replace_in_a_string extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Replace in a string")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Text to search")},
        {type: "Edit", id: "SearchText", default: "World", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Replace by")},
        {type: "Edit", id: "ReplaceText", default: "%a_username%", content: "String"},
        {type: "Label", label: Lang("Number of replacements")},
        {type: "Radio", id: "ReplaceAll", default: "first", choices: [Lang("Replace only the first occurence"), Lang("Replace all occurences")], result: "enum", enum: ["first", "all"]},
        {type: "Label", label: Lang("Case sensitivity")},
        {type: "Radio", id: "CaseSensitive", default: "CaseInsensitive", choices: [Lang("Case insensitive"), Lang("Case sensitive")], result: "enum", enum: ["CaseInsensitive", "CaseSensitive"]},
        {type: "Label", label: Lang("Text mode")},
        {type: "Radio", id: "TextMode", default: "Plain", choices: [Lang("Plain text"), Lang("Regular expression")], result: "enum", enum: ["Plain", "RegEx"]}
    ]

    static GenerateName(ctx, params) {
        return Lang("Replace in a string") " - " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "VarValue")
            . " - " TextOps.Par(params, "SearchText") " - " TextOps.Par(params, "ReplaceText")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        haystack := TextOps.Text(p.VarValue, params.VarValue)
        search := TextOps.Text(p.SearchText, params.SearchText)
        replace := TextOps.Text(p.ReplaceText, params.ReplaceText)
        caseSense := (p.CaseSensitive = "CaseSensitive")
        limit := (p.ReplaceAll = "first") ? 1 : -1
        count := 0
        result := haystack
        if (search != "") {
            if (p.TextMode = "RegEx") {
                pattern := caseSense ? search : "(?i)" search
                try
                    result := RegExReplace(haystack, pattern, replace, &count, limit)
                catch as e
                    throw ElementError(Lang("Regular expression is not valid: %1%", e.Message))
            } else {
                result := StrReplace(haystack, search, replace, caseSense ? "On" : "Off", &count, limit)
            }
        }
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.SetVar("a_numberOfReplacements", count, "thread")
        ctx.Finish("normal")
    }
}
