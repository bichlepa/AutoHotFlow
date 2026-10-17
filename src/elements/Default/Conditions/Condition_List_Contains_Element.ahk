#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk

; Condition List contains element of the package Default (WI-0053): "yes" if a list has a key or a value. Specification:
; the help text of v1 (help/en/Conditions/List_contains_element.html). Class ID, parameter IDs, enum values, defaults
; and language keys are those of v1 (Source_Elements/Default/Conditions/List_Contains_Element.ahk). The list logic is in
; lib/ListOps.ahk (HasKey, KeyOfValue).
;
;   InputList      an expression that gives the list (usually the name of the variable)
;   SearchWhat     Key: is there a member at Position (a number or a key name; "1" and 1 are one key)?
;                  Content: is there a member whose value is SearchContent (numbers compare as numbers, texts without
;                  regard to case)? The thread variable A_FoundKey then holds the key of the first one
;
; The default of SearchWhat is the index 2 (Content) as in v1; a flow file has the enum text.
class Condition_List_Contains_Element extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("List_Contains_Element")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Input list")},
        {type: "Edit", id: "InputList", default: "List", content: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Search for what")},
        {type: "Radio", id: "SearchWhat", default: 2, result: "enum"
            , choices: [Lang("Search for a position or key"), Lang("Search for an element with a specified content")]
            , enum: ["Key", "Content"]},
        {type: "Label", label: Lang("Key or position")},
        {type: "Edit", id: "Position", default: 1, content: ["String", "Expression"]
            , contentID: "isExpressionPosition", contentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Seeked content")},
        {type: "Edit", id: "SearchContent", default: "", content: ["String", "Expression"]
            , contentID: "isExpressionSearchContent", contentDefault: "String", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        list := params.HasProp("InputList") ? params.InputList : ""
        if (ListOps.EnumValue(params.HasProp("SearchWhat") ? params.SearchWhat : 2, ["Key", "Content"]) = "Key")
            text := Lang("Key '%1%' in list '%2%'", params.HasProp("Position") ? params.Position : "", list)
        else
            text := Lang("Value '%1%' in list '%2%'", params.HasProp("SearchContent") ? params.SearchContent : "", list)
        return Lang("List_Contains_Element") " - " text
    }

    static CheckSettings(form, params, staticValues) {
        key := ListOps.EnumValue(params.SearchWhat, ["Key", "Content"]) = "Key"
        form.Enable("Position", key)
        form.Enable("SearchContent", !key)
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "Position,SearchContent")
        ListOps.Require(p.InputList, Lang("Variable '%1%' does not contain a list.", params.InputList))
        if (ListOps.EnumValue(p.SearchWhat, ["Key", "Content"]) = "Key") {
            ctx.EvalMoreParams(p, params, "Position")
            ctx.Finish(ListOps.HasKey(p.InputList, p.Position) ? "yes" : "no")
            return
        }
        ctx.EvalMoreParams(p, params, "SearchContent")
        key := ListOps.KeyOfValue(p.InputList, p.SearchContent)
        if (key == ListOps.NONE) {
            ctx.Finish("no")
            return
        }
        ctx.SetVar("A_FoundKey", key, "thread")
        ctx.Finish("yes")
    }
}
