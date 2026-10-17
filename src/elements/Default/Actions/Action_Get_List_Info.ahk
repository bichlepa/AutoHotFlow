#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk

; Action Get list info of the package Default (WI-0053): writes one piece of information about a list to a variable.
; Specification: the help text of v1 (help/en/Actions/Get_list_info.html). Class ID, parameter IDs, enum values,
; defaults and language keys are those of v1 (Source_Elements/Default/Actions/Get_list_info.ahk). The list logic is in
; lib/ListOps.ahk (Info).
;
;   Varname    the variable that gets the value
;   List       an expression that gives the list (usually the name of the variable)
;   WhichInfo  minIndex / maxIndex: the lowest / highest Integer key ("" if there is none); length: the highest
;              positive key (0 if there is none); count: the number of members of every kind
class Action_Get_List_Info extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Get_list_Info")
    static Category() => Lang("List")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "ListInfo", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input list")},
        {type: "Edit", id: "List", default: "myList", content: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which info")},
        {type: "Radio", id: "WhichInfo", default: "maxIndex", result: "enum"
            , choices: [Lang("Minimum index"), Lang("Maximum index"), Lang("Array length"), Lang("Element count")]
            , enum: ["minIndex", "maxIndex", "length", "count"]}
    ]

    static GenerateName(ctx, params) {
        list := params.HasProp("List") ? params.List : ""
        switch (params.HasProp("WhichInfo") ? params.WhichInfo : "maxIndex") {
            case "minIndex": value := Lang("Minimum index of %1%", list)
            case "length": value := Lang("Array length of %1%", list)
            case "count": value := Lang("Element count of %1%", list)
            default: value := Lang("Maximum index of %1%", list)
        }
        return Lang("Get list info") "`n" (params.HasProp("Varname") ? params.Varname : "") " = " value
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        ListOps.Require(p.List, Lang("'%1%' does not contain a list", params.List))
        value := ListOps.Info(p.List, p.WhichInfo)
        if (!ctx.SetVar(p.Varname, value))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
