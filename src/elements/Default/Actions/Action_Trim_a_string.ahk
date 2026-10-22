#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Trim a string of the package Default (WI-0119): removes a count of characters, or the characters of a list, from the
; left and/or the right side of a string and writes the result. Specification: the help text of v1
; (help/en/Actions/Trim_a_string.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Trim_a_string.ahk).
;
;   TrimWhat  Number: Length characters are removed from the chosen sides. Specified: every character of OmitChars
;             is removed from the start and/or the end (AutoHotkey Trim, LTrim, RTrim).
;   LeftSide, RightSide  the sides. The check of the form keeps at least one side ticked (as v1).
;
; With no side ticked the text is written unchanged; a count of 0 or less removes nothing (decision of WI-0119,
; MIGRATION M-0111).
class Action_Trim_a_string extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Trim a string")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Operation")},
        {type: "Radio", id: "TrimWhat", default: "Number", choices: [Lang("Remove a number of characters"), Lang("Remove Specified caracters")], result: "enum", enum: ["Number", "Specified"]},
        {type: "Label", label: Lang("Remove from which side")},
        {type: "CheckBox", id: "LeftSide", default: 1, label: Lang("Left-hand side")},
        {type: "CheckBox", id: "RightSide", default: 0, label: Lang("Right-hand side")},
        {type: "Label", label: Lang("Count of characters")},
        {type: "Edit", id: "Length", default: 6, content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which characters")},
        {type: "Edit", id: "OmitChars", default: "%a_space%%a_tab%%a_lf%%a_cr%", content: "String", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        left := TextOps.Par(params, "LeftSide")
        right := TextOps.Par(params, "RightSide")
        if (left && right)
            sideText := Lang("both sides")
        else if (left)
            sideText := Lang("left side")
        else if (right)
            sideText := Lang("right side")
        else
            sideText := ""
        if (TextOps.Par(params, "TrimWhat") = "Specified")
            what := Lang("Remove characters '%1%' from %2%", TextOps.Par(params, "OmitChars"), sideText)
        else
            what := Lang("Remove '%1%' characters from %2%", TextOps.Par(params, "Length"), sideText)
        return Lang("Trim a string") " - " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "VarValue") " - " what
    }

    static CheckSettings(form, params, staticValues) {
        if (params.TrimWhat = "Number") {
            form.Enable("Length")
            form.Disable("OmitChars")
        } else {
            form.Disable("Length")
            form.Enable("OmitChars")
        }
        if (!params.LeftSide && !params.RightSide) {
            ; keep one side: the one that was not ticked last (v1 kept it in static variables)
            if (IsObject(staticValues) && staticValues.Has("previousRightSide") && staticValues["previousRightSide"]) {
                form.SetValue("LeftSide", 1)
                staticValues["previousLeftSide"] := 1
                staticValues["previousRightSide"] := 0
            } else {
                form.SetValue("RightSide", 1)
                if (IsObject(staticValues)) {
                    staticValues["previousRightSide"] := 1
                    staticValues["previousLeftSide"] := 0
                }
            }
        } else if (IsObject(staticValues)) {
            staticValues["previousLeftSide"] := params.LeftSide ? 1 : 0
            staticValues["previousRightSide"] := params.RightSide ? 1 : 0
        }
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "Length,OmitChars")
        result := TextOps.Text(p.VarValue, params.VarValue)
        if (p.TrimWhat = "Number") {
            p := ctx.EvalMoreParams(p, params, "Length")
            count := TextOps.Count(p.Length)
            if (p.LeftSide && count > 0)
                result := TextOps.Mid(result, count + 1)
            if (p.RightSide && count > 0)
                result := TextOps.Left(result, StrLen(result) - count)
        } else if (p.TrimWhat = "Specified") {
            p := ctx.EvalMoreParams(p, params, "OmitChars")
            omit := TextOps.Text(p.OmitChars, params.OmitChars)
            if (p.LeftSide && p.RightSide)
                result := Trim(result, omit)
            else if (p.LeftSide)
                result := LTrim(result, omit)
            else if (p.RightSide)
                result := RTrim(result, omit)
        } else {
            throw ElementError("Trim a string: unknown operation '" p.TrimWhat "'")
        }
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
