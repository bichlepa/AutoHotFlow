#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk

; Action Delete from list of the package Default (WI-0053): deletes a member of a list and can keep its value.
; Specification: the help text of v1 (help/en/Actions/Delete_from_list.html). Class ID, parameter IDs, enum values,
; defaults and language keys are those of v1 (Source_Elements/Default/Actions/Delete_from_list.ahk). The list logic is
; in lib/ListOps.ahk (Delete).
;
;   ListName        the variable that holds the list
;   WhichPosition   First / Last: the lowest / highest Integer key; Specified: Position (a number or a key name)
;   DeleteMethod    Decrement: the Integer keys above the deleted one move down by one; KeepGap: they stay
;   WriteToVariable 1: the deleted value goes to the variable Varname
;
; A list without an Integer key (First, Last) or without the key (Specified) ends the element with "exception".
class Action_Delete_from_list extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Delete_From_List")
    static Category() => Lang("List")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Variable_name")},
        {type: "Edit", id: "ListName", default: "myList", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which element")},
        {type: "Radio", id: "WhichPosition", default: "Last", result: "enum"
            , choices: [Lang("First integer position"), Lang("Last integer position"), Lang("Following position or key")]
            , enum: ["First", "Last", "Specified"]},
        {type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"]
            , contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true},
        {type: "Label", id: "DeleteMethodLabel", size: "small"
            , label: Lang("Deletion method if position is an integer and list contains values at this or higher positions")},
        {type: "Radio", id: "DeleteMethod", default: "Decrement", result: "enum"
            , choices: [Lang("Delete and decrement all higher positions"), Lang("Delete and keep the gap")]
            , enum: ["Decrement", "KeepGap"]},
        {type: "Label", label: Lang("Deleted value")},
        {type: "Checkbox", id: "WriteToVariable", default: 0, label: Lang("Write deleted value to variable")},
        {type: "Edit", id: "Varname", default: "RemovedValue", content: "VariableName", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        which := params.HasProp("WhichPosition") ? params.WhichPosition : "Last"
        if (which = "First")
            positionText := Lang("First value")
        else if (which = "Specified")
            positionText := Lang("At position '%1%'", params.HasProp("Position") ? params.Position : "")
        else
            positionText := Lang("Last value")
        text := Lang("Delete from list %1%", params.HasProp("ListName") ? params.ListName : "") " - " positionText
        if (params.HasProp("WriteToVariable") && params.WriteToVariable)
            text .= " - " Lang("Write deleted value to '%1%'", params.HasProp("Varname") ? params.Varname : "")
        return text
    }

    static CheckSettings(form, params, staticValues) {
        form.Enable("Position", params.WhichPosition = "Specified")
        method := params.WhichPosition = "First" || params.WhichPosition = "Specified"
        form.Enable("DeleteMethodLabel", method)
        form.Enable("DeleteMethod", method)
        form.Enable("Varname", params.WriteToVariable)
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "Position,Varname")
        write := p.WriteToVariable ? true : false
        if (write)
            ctx.EvalMoreParams(p, params, "Varname")
        if (StrLower(String(p.WhichPosition)) = "specified")
            ctx.EvalMoreParams(p, params, "Position")
        else
            p.Position := ""
        list := ListOps.Load(ctx, p.ListName)
        removed := ListOps.Delete(list, p.WhichPosition, p.Position, p.DeleteMethod, p.ListName)
        if (write && !ctx.SetVar(p.Varname, removed))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        if (!ctx.SetVar(p.ListName, list))
            throw ElementError("The variable '" p.ListName "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
