#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk

; Action Add to list of the package Default (WI-0053): adds one or several values to a list; a variable that does not
; exist or is empty becomes a new list. Specification: the help text of v1 (help/en/Actions/Add_to_list.html). Class
; ID, parameter IDs, enum values, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Add_to_list.ahk). The list logic is in lib/ListOps.ahk (Add).
;
;   Varname           the variable that holds the list
;   NumberOfElements  One (VarValue) or Multiple (VarValues, split at the selected delimiters)
;   WhichPosition     First (keys 1, 2, ...; the other positions move up), Last (after the highest positive key),
;                     Specified (Position: a position or a key name)
;   InsertMethod      with an Integer position: Insert (the members at that position and above move up) or Overwrite
;
; Adding several values (the v1 code never ran that branch, MIGRATION M-0057) keeps their order also at First.
class Action_Add_To_List extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "New variable.png"

    static Name() => Lang("Add_To_List")
    static Category() => Lang("List")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Variable_name")},
        {type: "Edit", id: "Varname", default: "MyList", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Number of elements")},
        {type: "Radio", id: "NumberOfElements", default: "One", result: "enum"
            , choices: [Lang("Add one element"), Lang("Add multiple elements")], enum: ["One", "Multiple"]},
        {type: "Label", label: Lang("Content to add")},
        {type: "Edit", id: "VarValue", default: "New element", content: ["String", "Expression"]
            , contentID: "Expression", contentDefault: "string", WarnIfEmpty: true},
        {type: "multilineEdit", id: "VarValues", content: "String", default: "Element one`nElement two", WarnIfEmpty: true},
        {type: "Checkbox", id: "DelimiterLinefeed", default: 1, label: Lang("Use linefeed as delimiter")},
        {type: "Checkbox", id: "DelimiterComma", default: 0, label: Lang("Use comma as delimiter")},
        {type: "Checkbox", id: "DelimiterSemicolon", default: 0, label: Lang("Use semicolon as delimiter")},
        {type: "Checkbox", id: "DelimiterSpace", default: 0, label: Lang("Use space as delimiter")},
        {type: "Label", label: Lang("Key")},
        {type: "Radio", id: "WhichPosition", default: "Last", result: "enum"
            , choices: [Lang("First integer position"), Lang("Last integer position"), Lang("Following position or key")]
            , enum: ["First", "Last", "Specified"]},
        {type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"]
            , contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true},
        {type: "Label", id: "InsertMethodLabel", size: "small"
            , label: Lang("Insertion method if position is an integer and list contains values at this or higher positions")},
        {type: "Radio", id: "InsertMethod", default: "Insert", result: "enum"
            , choices: [Lang("Insert and increment all other positions"), Lang("Overwrite value")]
            , enum: ["Insert", "Overwrite"]}
    ]

    static GenerateName(ctx, params) {
        which := params.HasProp("WhichPosition") ? params.WhichPosition : "Last"
        if (which = "First")
            positionText := Lang("As first value")
        else if (which = "Specified")
            positionText := Lang("At position '%1%'", params.HasProp("Position") ? params.Position : "")
        else
            positionText := Lang("As last value")
        if ((params.HasProp("NumberOfElements") ? params.NumberOfElements : "One") = "One")
            valueText := Lang("Value '%1%'", params.HasProp("VarValue") ? params.VarValue : "")
        else
            valueText := Lang("Multiple values '%1%'", params.HasProp("VarValues") ? params.VarValues : "")
        return Lang("Add to list") " - " (params.HasProp("Varname") ? params.Varname : "") " - " positionText " - " valueText
    }

    static CheckSettings(form, params, staticValues) {
        one := params.NumberOfElements = "One"
        specified := params.WhichPosition = "Specified"
        form.Enable("VarValue", one)
        for id in ["VarValues", "DelimiterLinefeed", "DelimiterComma", "DelimiterSemicolon", "DelimiterSpace"]
            form.Enable(id, !one)
        form.Enable("Position", specified)
        form.Enable("InsertMethod", specified)
        form.Enable("InsertMethodLabel", specified)
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "VarValue,VarValues,Position")
        list := ListOps.Load(ctx, p.Varname, true)
        if (StrLower(String(p.NumberOfElements)) = "multiple") {
            ctx.EvalMoreParams(p, params, "VarValues")
            values := ListOps.Split(p.VarValues, ListOps.Delimiters(p))
        } else {
            ctx.EvalMoreParams(p, params, "VarValue")
            values := [p.VarValue]
        }
        if (StrLower(String(p.WhichPosition)) = "specified")
            ctx.EvalMoreParams(p, params, "Position")
        else
            p.Position := ""
        ListOps.Add(list, values, p.WhichPosition, p.Position, p.InsertMethod)
        if (!ctx.SetVar(p.Varname, list))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
