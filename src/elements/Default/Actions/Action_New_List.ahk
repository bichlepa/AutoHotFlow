#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk

; Action New list of the package Default (WI-0053): creates a list, empty or with values. Specification: the help text
; of v1 (help/en/Actions/New_List.html). Class ID, parameter IDs, enum values, defaults and language keys are those of
; v1 (Source_Elements/Default/Actions/New_List.ahk). The list logic is in lib/ListOps.ahk.
;
;   Varname           the name of the variable that gets the list (an existing variable is replaced)
;   NumberOfElements  None (empty list), One (VarValue), Multiple (VarValues, split at the selected delimiters)
;   VarValue          one value: a text with %var% or an expression (selected in the parameter "expression")
;   VarValues         several values as a text; Delimiter* select the separators
;   WhichPosition     First: key 1; Specified: key Position (any key). Not used with Multiple (the form disables it,
;                     as in v1): the values get the keys 1, 2, ...
class Action_New_List extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "New variable.png"

    static Name() => Lang("New_List")
    static Category() => Lang("Variable") "|" Lang("List")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Variable_name")},
        {type: "Edit", id: "Varname", default: "myList", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Number of elements")},
        {type: "Radio", id: "NumberOfElements", default: "None", result: "enum"
            , choices: [Lang("Empty list"), Lang("Initialize with one element"), Lang("Initialize with multiple elements")]
            , enum: ["None", "One", "Multiple"]},
        {type: "Label", label: Lang("Initial content")},
        {type: "Edit", id: "VarValue", default: "New element", content: ["String", "Expression"]
            , contentID: "expression", contentDefault: "string", WarnIfEmpty: true},
        {type: "multilineEdit", id: "VarValues", content: "String", default: "Element one`nElement two", WarnIfEmpty: true},
        {type: "Checkbox", id: "DelimiterLinefeed", default: 1, label: Lang("Use linefeed as delimiter")},
        {type: "Checkbox", id: "DelimiterComma", default: 0, label: Lang("Use comma as delimiter")},
        {type: "Checkbox", id: "DelimiterSemicolon", default: 0, label: Lang("Use semicolon as delimiter")},
        {type: "Checkbox", id: "DelimiterSpace", default: 0, label: Lang("Use space as delimiter")},
        {type: "Label", label: Lang("Key")},
        {type: "Radio", id: "WhichPosition", default: "First", result: "enum"
            , choices: [Lang("Numerically as first element"), Lang("Following key")], enum: ["First", "Specified"]},
        {type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"]
            , contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        howMany := params.HasProp("NumberOfElements") ? params.NumberOfElements : "None"
        positionText := ""
        if (howMany != "None") {
            positionText := " - "
            if ((params.HasProp("WhichPosition") ? params.WhichPosition : "First") = "Specified")
                positionText .= Lang("At position '%1%'", params.HasProp("Position") ? params.Position : "")
            else
                positionText .= Lang("As first value")
        }
        if (howMany = "None")
            valueText := Lang("Empty")
        else if (howMany = "One")
            valueText := Lang("Value '%1%'", params.HasProp("VarValue") ? params.VarValue : "")
        else
            valueText := Lang("Multiple values '%1%'", params.HasProp("VarValues") ? params.VarValues : "")
        return Lang("New list %1%", params.HasProp("Varname") ? params.Varname : "") positionText " - " valueText
    }

    static CheckSettings(form, params, staticValues) {
        one := params.NumberOfElements = "One"
        multiple := params.NumberOfElements = "Multiple"
        form.Enable("VarValue", one)
        form.Enable("WhichPosition", one)
        form.Enable("Position", one && params.WhichPosition = "Specified")
        for id in ["VarValues", "DelimiterLinefeed", "DelimiterComma", "DelimiterSemicolon", "DelimiterSpace"]
            form.Enable(id, multiple)
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "VarValue,VarValues,Position")
        list := ListOps.NewList()
        switch StrLower(String(p.NumberOfElements)) {
            case "none":
            case "one":
                ctx.EvalMoreParams(p, params, "VarValue")
                if (StrLower(String(p.WhichPosition)) = "specified") {
                    ctx.EvalMoreParams(p, params, "Position")
                    ListOps.Add(list, [p.VarValue], "Specified", p.Position, "Overwrite")
                } else {
                    ListOps.Add(list, [p.VarValue], "First")
                }
            case "multiple":
                ctx.EvalMoreParams(p, params, "VarValues")
                ListOps.Add(list, ListOps.Split(p.VarValues, ListOps.Delimiters(p)), "Last")
            default:
                throw ElementError("New list: unknown number of elements '" p.NumberOfElements "'")
        }
        if (!ctx.SetVar(p.Varname, list))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
