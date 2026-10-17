#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\LoopOps.ahk

; Loop Simple loop of the package Default (WI-0054): repeats the body a number of times, or until a connection leads to
; the break part. Specification: the help text of v1 (help/en/Loops/simpleloop.html). Class ID, parameter IDs, defaults
; and language keys are those of v1 (Source_Elements/Default/Loops/SimpleLoop.ahk). The entry points and the loop
; variables: lib/LoopOps.ahk.
;
;   Infinite     the loop never ends by itself; repeatCount is ignored (and not evaluated)
;   repeatCount  an expression: the number of passes. 0 or less: no pass
;
; Loop variable: A_Index (1 in the first pass). The number of passes is evaluated at every entry, so it may change
; while the loop runs (as in v1).
class Loop_SimpleLoop extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Simple loop")
    static Category() => Lang("General")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Repeats")},
        {type: "Checkbox", id: "Infinite", default: 0, label: Lang("Endless loop")},
        {type: "Edit", id: "repeatCount", default: 5, content: "Expression", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        if (params.HasProp("Infinite") && LoopOps.IsTrue(params.Infinite))
            return Lang("Simple loop") ": " Lang("Endless loop")
        return Lang("Simple loop") ": " (params.HasProp("repeatCount") ? params.repeatCount : "") " " Lang("Repeats")
    }

    static Run(ctx, params) {
        entry := LoopOps.Entry(ctx)
        if (entry = "break") {
            ctx.Finish("tail")
            return
        }
        ; An endless loop does not need the count, so an empty or broken count does not stop it
        infinite := params.HasProp("Infinite") && LoopOps.IsTrue(params.Infinite)
        p := ctx.EvalParams(params, infinite ? "repeatCount" : "")
        if (!infinite)
            count := LoopOps.Number(p.repeatCount, params.HasProp("repeatCount") ? params.repeatCount : "")
        index := (entry = "head") ? 1 : LoopOps.NextIndex(ctx)
        if (infinite || count >= index) {
            LoopOps.SetIndex(ctx, index)
            ctx.Finish("head")
        } else {
            ctx.Finish("tail")
        }
    }
}
