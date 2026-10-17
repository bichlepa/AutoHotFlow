#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\LoopOps.ahk

; Loop Work through a list of the package Default (WI-0054): one pass per member of a list. Specification: the help
; text of v1 (help/en/Loops/Work_through_a_list.html). Class ID, parameter IDs, defaults and language keys are those of
; v1 (Source_Elements/Default/Loops/Work_through_a_list.ahk). The entry points and the loop variables: lib/LoopOps.ahk.
;
;   VarValue  the name of the variable that holds the list
;
; Loop variables: A_Index (1 in the first pass), A_LoopKey (the key of the member: its position or its name),
; A_LoopField (its value). The order is that of a list (doc/EXPRESSION-LANGUAGE.md section 18.3): the Integer keys
; ascending, then the texts.
;
; The loop works through a copy of the list that it makes at the head, as v1 did: a member that the body adds,
; changes or deletes does not change the passes. The copy is the hidden loop variable A_LoopCurrentList (no expression
; sees it); one pass reads one member of it.
class Loop_Work_through_a_list extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Work_through_a_list")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Input list")},
        {type: "Edit", id: "VarValue", default: "List", content: "VariableName", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Work_through_a_list") ": " (params.HasProp("VarValue") ? params.VarValue : "")

    static Run(ctx, params) {
        entry := LoopOps.Entry(ctx)
        if (entry = "break") {
            ctx.Finish("tail")
            return
        }
        if (entry = "head") {
            p := ctx.EvalParams(params)
            list := ctx.GetVar(p.VarValue)
            if (!(list is Map))
                throw ElementError(Lang("Variable '%1%' does not contain a list.", p.VarValue))
            items := LoopOps.NewMap()
            n := 0
            for key, value in list {
                n += 1
                items[n] := Map("key", key, "value", value)
            }
            if (n = 0) {
                ctx.Finish("tail")          ; no pass at all
                return
            }
            LoopOps.SetSnapshot(ctx, items)
            index := 1
        } else {
            index := LoopOps.NextIndex(ctx)
        }
        item := LoopOps.Item(ctx, index)
        if (LoopOps.IsNone(item)) {
            ctx.Finish("tail")              ; the last member was done
            return
        }
        LoopOps.SetIndex(ctx, index)
        ctx.SetVar("A_LoopKey", item["key"], "loop")
        ctx.SetVar("A_LoopField", item["value"], "loop")
        ctx.Finish("head")
    }
}
