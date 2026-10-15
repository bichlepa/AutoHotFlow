#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Trace point of the package Default (WI-0052): records that the flow passed this place, for debugging and for
; the instrumentation of tests. Specification: the help text of v1 (help/en/Actions/Trace_Point.html). Parameter IDs,
; defaults and language keys are those of v1 (Source_Elements/Default/Actions/Trace_Point.ahk).
;
;   ID             name of the trace point (any text, content rawstring)
;   LogMessage     optional text (with %var%), written to the log of the flow with the level f0
;   StopCondition  optional expression; if its value is true, the element ends with "exception" and the instance with
;                  all its threads is stopped (it ends with the reason "element.stop")
;
; The trace point appends "<ID> (<element ID>)" to the hidden instance variable passed_Tracepoints (a list), which
; Action_Trace_Point_Check reads. The variable is hidden: no expression and no %var% can reach it. The list belongs to
; the instance, so it is shared by all threads of the instance and gone when the instance ends.
class Action_Trace_Point extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Stable"
    ; v1: the form is updated after every edit of a parameter (the editor decides how, S0007)
    static UpdateOnEdit := true

    ; The name of the hidden instance variable with the passed trace points (shared with Action_Trace_Point_Check)
    static PASSED_VAR := "passed_Tracepoints"

    ; Words for the default ID (v1 Lib/Random Word List: randomPhrase)
    static ADJECTIVES := ["big", "small", "tall", "large", "great", "little", "noisy", "silent", "tired", "happy", "sad"
        , "boring", "stupid", "silly", "smart", "clever", "bright", "dark", "shiny", "red", "green", "blue", "yellow"]
    static NOUNS := ["house", "door", "window", "ladder", "stairs", "chair", "cupboard", "table", "wall", "car", "boat"
        , "ship", "bus", "train", "bicycle", "plane", "soil", "apple", "banana", "bird", "box", "leg", "tree", "river"]

    static Name() => Lang("Trace_Point")
    static Category() => Lang("Debugging")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("ID")},
        {type: "Edit", id: "ID", content: "rawstring", default: "Tracepoint " this.RandomPhrase()},
        {type: "Label", label: Lang("Log message")},
        {type: "Edit", id: "LogMessage", default: "", content: "String", WarnIfEmpty: false},
        {type: "Label", label: Lang("Stop condition")},
        {type: "Edit", id: "StopCondition", default: "", content: "Expression", WarnIfEmpty: false}
    ]

    ; "Trace point - ID" and " - With stop condition" if there is a stop condition (v1 Element_GenerateName)
    static GenerateName(ctx, params) {
        stopText := ""
        if (params.HasProp("StopCondition") && !IsObject(params.StopCondition) && params.StopCondition != "")
            stopText := " - " Lang("With stop condition")
        return Lang("Trace_Point") " - " (params.HasProp("ID") ? params.ID : "") stopText
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (p.LogMessage != "")
            ctx.Log("f0", p.LogMessage)
        ; The list is changed as a whole: the variable functions hand out and take copies. Nothing else runs between
        ; the read and the write (the engine is one thread, and there is no wait in between).
        passed := ctx.GetVar(this.PASSED_VAR, "", true)
        if (!(passed is Map))
            passed := Map()
        passed[passed.Count + 1] := p.ID " (" ctx.elementId ")"
        ctx.SetVar(this.PASSED_VAR, passed, "", true)
        if (this.IsTrue(p.StopCondition)) {
            ; first the finish, then the stop, as v1 did (finish, then stop the instance). The text names the condition as written
            ; (v1 named its value, MIGRATION M-0055)
            ctx.Finish("exception", Lang("Stopping execution because stop Condition '%1%' is not false"
                , params.HasProp("StopCondition") ? params.StopCondition : ""))
            ctx.StopInstance()
        } else {
            ctx.Finish("normal")
        }
    }

    ; The truth value of the stop condition: the empty text, 0 and a text that is a number with the value 0 are false.
    static IsTrue(value) => IsObject(value) ? true : (value ? true : false)

    ; "<adjective> <noun>" (v1 randomPhrase)
    static RandomPhrase() => this.ADJECTIVES[Random(1, this.ADJECTIVES.Length)] " " this.NOUNS[Random(1, this.NOUNS.Length)]
}
