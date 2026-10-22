#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Substring2 of the package Default (WI-0119): writes the part of a string between a start and an end, which are
; positions or texts. A start or end text that is not found gives the empty text and no error, as in v1 (decision of
; WI-0119, MIGRATION M-0111). Specification: the help text of v1 (help/en/Actions/Substring2.md). Class ID, parameter
; IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Substring2.ahk).
;
; The element sets the thread variables A_startPos and A_length (as v1). A_startPos is 0 when a start text is not
; found; A_length is the empty text when the end is not known.
;
;   Start text: the first field is not part of the result, the second one is (v1 wording). The search starts at StartPos.
;   End text:   the first field is part of the result, the second one is not (v1 wording).
class Action_Substring2 extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Substring2")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable_name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true},
        {type: "Label", label: Lang("Start position")},
        {type: "Radio", id: "WhereToBegin", default: "FromLeft", choices: [Lang("Start from left"), Lang("Start from following position"), Lang("Search for a string and start there")], result: "enum", enum: ["FromLeft", "Position", "String"]},
        {type: "Label", label: Lang("Start position"), size: "small"},
        {type: "Edit", id: "StartPos", default: 1, content: "positiveInteger", WarnIfEmpty: true},
        {type: "Label", label: Lang("Text (excluding and including)"), size: "small"},
        {type: "Edit", id: ["StartTextExcluding", "StartTextIncluding"], default: 1, content: ["String", "Expression"], contentID: "expressionStart", contentDefault: "string"},
        {type: "Checkbox", id: "StartTextCaseSensitive", default: 0, label: Lang("Case sensitive")},
        {type: "Label", label: Lang("End position")},
        {type: "Radio", id: "WhereToEnd", default: "CountOfChars", choices: [Lang("End at the end of the string"), Lang("End after a count of characters"), Lang("End at following position"), Lang("Search for a string and end there")], result: "enum", enum: ["AtTheEnd", "CountOfChars", "Position", "String"]},
        {type: "Label", label: Lang("Count of characters"), size: "small"},
        {type: "Edit", id: "Length", default: 5, content: "positiveIntegerOrZero", WarnIfEmpty: true},
        {type: "Label", label: Lang("End position"), size: "small"},
        {type: "Edit", id: "EndPos", default: 5, content: "positiveInteger", WarnIfEmpty: true},
        {type: "Label", label: Lang("Text (including and excluding)"), size: "small"},
        {type: "Edit", id: ["EndTextIncluding", "EndTextExcluding"], default: 1, content: ["String", "Expression"], contentID: "expressionEnd", contentDefault: "String"},
        {type: "Checkbox", id: "EndTextCaseSensitive", default: 0, label: Lang("Case sensitive")}
    ]

    static GenerateName(ctx, params) {
        return Lang("Substring") "2 - " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "VarValue")
    }

    static CheckSettings(form, params, staticValues) {
        if (params.WhereToBegin = "Position") {
            form.Enable("StartPos")
            form.Disable("StartTextExcluding")
            form.Disable("StartTextIncluding")
            form.Disable("StartTextCaseSensitive")
        } else if (params.WhereToBegin = "String") {
            form.Enable("StartPos")
            form.Enable("StartTextExcluding")
            form.Enable("StartTextIncluding")
            form.Enable("StartTextCaseSensitive")
        } else if (params.WhereToBegin = "FromLeft") {
            form.Disable("StartPos")
            form.Disable("StartTextExcluding")
            form.Disable("StartTextIncluding")
            form.Disable("StartTextCaseSensitive")
        }
        if (params.WhereToEnd = "AtTheEnd") {
            form.Disable("Length")
            form.Disable("EndPos")
            form.Disable("EndTextIncluding")
            form.Disable("EndTextExcluding")
            form.Disable("EndTextCaseSensitive")
        } else if (params.WhereToEnd = "CountOfChars") {
            form.Enable("Length")
            form.Disable("EndPos")
            form.Disable("EndTextIncluding")
            form.Disable("EndTextExcluding")
            form.Disable("EndTextCaseSensitive")
        } else if (params.WhereToEnd = "Position") {
            form.Disable("Length")
            form.Enable("EndPos")
            form.Disable("EndTextIncluding")
            form.Disable("EndTextExcluding")
            form.Disable("EndTextCaseSensitive")
        } else if (params.WhereToEnd = "String") {
            form.Disable("Length")
            form.Disable("EndPos")
            form.Enable("EndTextIncluding")
            form.Enable("EndTextExcluding")
            form.Enable("EndTextCaseSensitive")
        }
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "StartPos,StartTextExcluding,StartTextIncluding,Length,EndPos,EndTextIncluding,EndTextExcluding")
        haystack := TextOps.Text(p.VarValue, params.VarValue)
        startPos := 1
        endPos := 0
        length := ""
        valid := true
        switch p.WhereToBegin {
            case "FromLeft":
                startPos := 1
            case "Position":
                p := ctx.EvalMoreParams(p, params, "StartPos")
                startPos := TextOps.Count(p.StartPos)
            case "String":
                p := ctx.EvalMoreParams(p, params, "StartPos,StartTextExcluding,StartTextIncluding")
                startNeedle := String(p.StartTextExcluding) String(p.StartTextIncluding)
                if (startNeedle = "")
                    throw ElementError(Lang("Start text not specified"))
                startPos := InStr(haystack, startNeedle, p.StartTextCaseSensitive ? true : false, TextOps.Count(p.StartPos))
                if (startPos)
                    startPos += StrLen(String(p.StartTextExcluding))
                else
                    valid := false
            default:
                throw ElementError("Substring2: unknown start position '" p.WhereToBegin "'")
        }
        if (valid) {
            switch p.WhereToEnd {
                case "AtTheEnd":
                    length := ""
                case "CountOfChars":
                    p := ctx.EvalMoreParams(p, params, "Length")
                    length := TextOps.Count(p.Length)
                case "Position":
                    p := ctx.EvalMoreParams(p, params, "EndPos")
                    length := TextOps.Count(p.EndPos) - startPos + 1
                    if (length < 0)
                        throw ElementError(Lang("End position is higher than start position"))
                case "String":
                    p := ctx.EvalMoreParams(p, params, "EndTextIncluding,EndTextExcluding")
                    endNeedle := String(p.EndTextIncluding) String(p.EndTextExcluding)
                    if (endNeedle = "")
                        throw ElementError(Lang("End text not specified"))
                    endPos := InStr(haystack, endNeedle, p.EndTextCaseSensitive ? true : false, startPos)
                    if (endPos) {
                        endPos += StrLen(String(p.EndTextIncluding))
                        length := endPos - startPos
                    } else {
                        valid := false
                    }
                default:
                    throw ElementError("Substring2: unknown end position '" p.WhereToEnd "'")
            }
        }
        result := ""
        if (valid)
            result := (length = "") ? SubStr(haystack, startPos) : TextOps.Left(SubStr(haystack, startPos), length)
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.SetVar("A_startPos", startPos, "thread")
        ctx.SetVar("A_length", length, "thread")
        ctx.Finish("normal")
    }
}
