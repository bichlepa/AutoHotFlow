#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Change character case of the package Default (WI-0119): writes a string in upper case, in lower case, or with
; the first letter of every word in upper case (title case) to a variable. Specification: the help text of v1
; (help/en/Actions/Change_character_case.md). Class ID, parameter IDs, enum values, defaults and language keys are those
; of v1 (Source_Elements/Default/Actions/Change_character_case.ahk).
;
; The title case is StrTitle (the other letters of a word become lower case). Letters outside A-Z are converted by
; AutoHotkey's Unicode rules (the test uses umlauts). Not checked: the title case of v1 on a text with several spaces.
class Action_Change_character_case extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Change character case")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output Variable_name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which case #character case")},
        {type: "Radio", id: "CharCase", default: "upper", result: "enum", choices: [Lang("Uppercase"), Lang("Lowercase"), Lang("First character of a word is uppercase")], enum: ["upper", "lower", "firstUp"]}
    ]

    static GenerateName(ctx, params) {
        switch TextOps.Par(params, "CharCase") {
            case "lower": caseText := Lang("Lowercase")
            case "firstUp": caseText := Lang("First character uppercase")
            default: caseText := Lang("Uppercase")
        }
        return Lang("Change character case") " - " caseText " - " TextOps.Par(params, "Varname") " - "
            . TextOps.Par(params, "VarValue")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        text := TextOps.Text(p.VarValue, params.VarValue)
        result := TextOps.ChangeCase(text, p.CharCase)
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
