#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\LoopOps.ahk

; Loop Parse a string of the package Default (WI-0054): one pass per part (field) of a text. Specification: the help
; text of v1 (help/en/Loops/Parse_a_string.html) and the AutoHotkey v2 "Loop Parse". Class ID, parameter IDs, defaults
; and language keys are those of v1 (Source_Elements/Default/Loops/Parse_A_String.ahk). The entry points and the loop
; variables: lib/LoopOps.ahk.
;
;   VarValue    the text (content String, with %var%, or Expression: the parameter Expression names the content type)
;   Delimiters  every character of this text separates two fields (case sensitive). Empty: every character of the
;               input is a field (the help text; the form of v1 warned about an empty text, M-0060)
;   OmitChars   characters that are cut from the start and the end of every field (case sensitive); may be empty
;
; Loop variables: A_Index (1 in the first pass), A_LoopField (the field). Empty fields are passes too (`a,,b` has three).
; Special case, as in v1: the delimiter text "CSV" (any case) switches to the CSV mode of AutoHotkey (see Split).
; The fields are found at the head and kept in the hidden loop variable A_LoopCurrentList (no expression sees it);
; one pass reads one field.
class Loop_Parse_A_String extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Parse_A_String")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello real world, Hello virtual world", content: ["String", "Expression"]
            , contentID: "Expression", ContentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Delimiter characters")},
        {type: "Edit", id: "Delimiters", default: ",", content: "String", WarnIfEmpty: false},
        {type: "Label", label: Lang("Omit characters")},
        {type: "Edit", id: "OmitChars", default: "%a_space%%a_tab%%a_lf%%a_cr%", content: "String"}
    ]

    static GenerateName(ctx, params) {
        text := params.HasProp("VarValue") ? params.VarValue : ""
        delimiters := params.HasProp("Delimiters") ? params.Delimiters : ""
        omitChars := params.HasProp("OmitChars") ? params.OmitChars : ""
        return Lang("Parse_A_String") " - " text " - " delimiters " - " omitChars
    }

    static Run(ctx, params) {
        entry := LoopOps.Entry(ctx)
        if (entry = "break") {
            ctx.Finish("tail")
            return
        }
        if (entry = "head") {
            p := ctx.EvalParams(params)
            if (IsObject(p.VarValue))
                throw ElementError("The input string is an object, not a text.")
            fields := this.Split(String(p.VarValue), String(p.Delimiters), String(p.OmitChars))
            if (fields.Count = 0) {
                ctx.Finish("tail")          ; no pass at all
                return
            }
            LoopOps.SetSnapshot(ctx, fields)
            index := 1
        } else {
            index := LoopOps.NextIndex(ctx)
        }
        field := LoopOps.Item(ctx, index)
        if (LoopOps.IsNone(field)) {
            ctx.Finish("tail")              ; the last field was done
            return
        }
        LoopOps.SetIndex(ctx, index)
        ctx.SetVar("A_LoopField", field, "loop")
        ctx.Finish("head")
    }

    ; The fields of the text as a Map position -> text. The AutoHotkey "Loop Parse" does the work. Like v1 and AutoHotkey
    ; v2 it reads the delimiter text "CSV" (any case) as the CSV mode and not as the characters C, S and V: the fields
    ; are then those of a CSV line (a field in quotes may hold the separator). The help text does not mention it;
    ; checked with the v1 interpreter.
    static Split(text, delimiters, omitChars) {
        fields := LoopOps.NewMap()
        n := 0
        loop parse text, delimiters, omitChars {
            n += 1
            fields[n] := A_LoopField
        }
        return fields
    }
}
