#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk

; Action Get index of element in list of the package Default (WI-0053): writes the key of the first member with a given
; value to a variable. Specification: the help text of v1 (help/en/Actions/Get_index_of_element_in_list.html). Class
; ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Get_index_of_element_in_list.ahk). The list logic is in lib/ListOps.ahk (KeyOfValue).
;
;   Varname        the variable that gets the key
;   ListName       an expression that gives the list (usually the name of the variable)
;   SearchContent  the value to look for (numbers compare as numbers, texts without regard to case)
;
; A list without such a value ends the element with "exception".
class Action_Get_index_of_element_in_list extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "New variable.png"

    static Name() => Lang("Get position of element in list")
    static Category() => Lang("List")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input list")},
        {type: "Edit", id: "ListName", default: "MyList", content: "expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Seeked content")},
        {type: "Edit", id: "SearchContent", default: "keyName", content: ["String", "Expression"]
            , contentID: "expression", contentDefault: "string", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Get position of element in list") " - " (params.HasProp("Varname") ? params.Varname : "") " - "
            . (params.HasProp("ListName") ? params.ListName : "") " - " (params.HasProp("SearchContent") ? params.SearchContent : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        ListOps.Require(p.ListName, Lang("Variable '%1%' does not contain a list.", params.ListName))
        key := ListOps.KeyOfValue(p.ListName, p.SearchContent)
        if (key == ListOps.NONE)
            throw ElementError(Lang("The list '%1%' does not contain the value '%2%'.", params.ListName, p.SearchContent))
        if (!ctx.SetVar(p.Varname, key))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
