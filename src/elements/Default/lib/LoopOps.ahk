#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; Shared parts of the loop elements of the package Default (WI-0054): Loop_SimpleLoop, Loop_Condition,
; Loop_Work_through_a_list and Loop_Parse_A_String.
;
; How a loop runs (ELEMENT-API-V2 section 7, ARCHITECTURE 5.2). A loop element has three entry points, named by the
; part of the element that the incoming connection ends at (ctx.entryPoint, any case):
;
;   head   the flow enters the loop. The engine has pushed the loop variables of the thread (Scheduler.Advance), so
;          what the loop sets now is restored when it is left. The element starts the first pass (result "head") or
;          leaves at once without a pass (result "tail").
;   tail   the end of the body. The element starts the next pass ("head") or leaves ("tail").
;   break  a connection to the break part: the element leaves ("tail").
;
; The result "head" follows the connections that leave the head part, "tail" the ones that leave the tail part. Leaving
; with "tail" or "exception" pops the loop variables (once, M-0019), so A_Index and the other variables of the loop are
; gone afterwards and those of an outer loop are back. The loop variables belong to the thread, not to the element: a
; pass that branches into two threads gives each its own copy.
class LoopOps {
    ; The hidden loop variable that holds the snapshot of the values that the list loops walk through
    static SNAPSHOT := "A_LoopCurrentList"
    static NONE := Object()

    ; The entry point as "head", "tail" or "break". A connection that names no part gives the error of v1.
    static Entry(ctx) {
        entry := StrLower(String(ctx.entryPoint))
        if (entry = "head" || entry = "tail" || entry = "break")
            return entry
        throw ElementError(Lang("No information whether the connection leads to head or tail"))
    }

    ; The truth value of a parameter or a result: the empty text, 0 and a text that is a number with the value 0 are false.
    static IsTrue(value) => IsObject(value) ? true : (value ? true : false)

    ; The value of a number parameter, or ElementError with the text of the parameter evaluation ("is not a number").
    static Number(value, text) {
        if (IsObject(value) || !IsNumber(value))
            throw ElementError(Lang("Result of expression '%1%' is not a number", text))
        return value + 0
    }

    ; Sets A_Index (a loop variable) and returns the value.
    static SetIndex(ctx, index) {
        ctx.SetVar("A_Index", index, "loop")
        return index
    }

    ; The index of the next pass: A_Index of the running pass plus 1. A missing or broken A_Index counts as 0, as in v1.
    static NextIndex(ctx) {
        index := ctx.GetVar("A_Index", 0)
        return (IsObject(index) || !IsNumber(index) ? 0 : index + 0) + 1
    }

    ; The truth value of the expression text of a loop condition. The text is evaluated here and not by ctx.EvalParams:
    ; with WarnIfEmpty the parameter evaluation turns an empty RESULT into an error, but an empty result is "false".
    ; An empty expression TEXT, an unreadable expression and, in strict mode (E0034), a type error end the element with
    ; "exception" (the texts of ctx.EvalParams).
    static Condition(ctx, text) {
        if (IsObject(text) || Trim(text, " `t`r`n") = "")
            throw ElementError(Lang("Parameter '%1%' is empty", "Expression"))
        try {
            value := ctx.EvaluateExpression(text)
        } catch ElementError as e {
            throw ElementError(Lang("An error occured while parsing expression '%1%'", text) "`n`n" e.Message)
        }
        return LoopOps.IsTrue(value)
    }

    ; A new Map for the snapshot: the keys are the positions 1..n, names do not matter.
    static NewMap() {
        m := Map()
        m.CaseSense := "Off"
        return m
    }

    ; Stores the snapshot (a Map position -> value) as the hidden loop variable. The list loops read one member per
    ; pass (Item), so a pass costs the size of that member and not of the list. The snapshot is the copy that v1 made
    ; at the start: a change of the list in the body does not change the passes of the loop.
    static SetSnapshot(ctx, items) {
        if (!ctx.SetVar(LoopOps.SNAPSHOT, items, "loop", true))
            throw ElementError("The loop could not store its values (the reason is in the log).")
    }

    ; The member `index` of the snapshot, or LoopOps.NONE if the loop has no such pass (the end of the list). A member
    ; can be the empty text (an empty field), so the empty text cannot mean "none".
    static Item(ctx, index) => ctx.GetVar(LoopOps.SNAPSHOT "." index, LoopOps.NONE, true)

    ; True if item is the answer "no such pass" of Item
    static IsNone(item) => IsObject(item) && ObjPtr(item) = ObjPtr(LoopOps.NONE)
}
