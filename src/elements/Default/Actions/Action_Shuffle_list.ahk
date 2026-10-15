#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk

; Action Shuffle list of the package Default (WI-0053): writes a copy of a list to a variable in which the members with
; a numeric key are in random order. Specification: the help text of v1 (help/en/Actions/Shuffle_list.html). Class ID,
; parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Shuffle_list.ahk). The list
; logic is in lib/ListOps.ahk (Shuffle).
;
;   Varname   the variable that gets the shuffled list (it may be the input list)
;   VarValue  an expression that gives the list (usually the name of the variable)
;
; The values of the members with a numeric key come back with the keys 1..n; members with another key stay as they are.
; The element has no seed (v1 had none either).
class Action_Shuffle_list extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Shuffle_list")
    static Category() => Lang("List")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output list name")},
        {type: "Edit", id: "Varname", default: "shuffledList", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input list")},
        {type: "Edit", id: "VarValue", default: "myList", content: "Expression", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Shuffle_list") " - " (params.HasProp("Varname") ? params.Varname : "") " - "
            . (params.HasProp("VarValue") ? params.VarValue : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        list := ListOps.Require(p.VarValue, Lang("Variable '%1%' does not contain a list.", params.VarValue))
        ListOps.Shuffle(list)
        if (!ctx.SetVar(p.Varname, list))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
