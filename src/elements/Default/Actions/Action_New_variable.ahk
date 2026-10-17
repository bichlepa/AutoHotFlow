#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action New variable of the package Default (WI-0052): creates a variable with a value. Specification: the help text
; of v1 (help/en/Actions/New_Variable.html) and the checkbox "Write only if variable does not exist". Class ID,
; parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/New_Variable.ahk).
;
;   Varname        the name of the variable; its prefix decides the scope (global_, static_, any other name: instance)
;   VarValue       the value: a text with %var% (content "string") or an expression (content "expression"), selected in
;                  the parameter "expression" (contentID; a flow without it means string)
;   onlyIfNotExist 1: an existing variable of that name (of any scope, also a built-in one) is not changed
;
; A name that SetVar refuses (an A_ name, which is a loop or thread variable) ends the element with "exception"
; (MIGRATION M-0051); v1 only logged it.
class Action_New_variable extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "new Variable.png"

    static Name() => Lang("New_variable")
    static Category() => Lang("Variable") "|" Lang("Text") "|" Lang("Maths")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Variable_name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Value")},
        {type: "multilineEdit", id: "VarValue", default: "New element", content: ["String", "Expression"]
            , contentID: "expression", contentDefault: "string"},
        {type: "Label", label: Lang("Options")},
        {type: "Checkbox", id: "onlyIfNotExist", default: 0, label: Lang("Write only if variable does not exist")}
    ]

    ; "New variable - name = value" (v1 Element_GenerateName_Action_New_variable)
    static GenerateName(ctx, params) {
        name := params.HasProp("Varname") ? params.Varname : "NewVariable"
        value := params.HasProp("VarValue") ? params.VarValue : "New element"
        return Lang("New_variable") " - " name " = " value
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (p.onlyIfNotExist && ctx.GetVarLocation(p.Varname) != "") {
            ctx.Finish("normal", "Variable was not written, because it already exists.")
            return
        }
        if (!ctx.SetVar(p.Varname, p.VarValue))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
