#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element of WI-39 (used by WI-42 as well): one parameter of each content type of v1, so that loading with
; the conversion of expression texts can be checked end to end. Run does nothing but finish. Parameter evaluation
; (WI-42) is not part of it.
;   Expr, Num, PosInt   expression content types: converted on load
;   Either              content selectable by the user (EitherType holds "string" or "expression")
;   Text, VarName, Raw  not expressions: stay as they are
;   Script, Condition   evaluated by the element itself: named in V1Syntax
class Action_TestExprParams extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Experimental"

    static V1Syntax := Map("Script", "script", "Condition", "expression")

    static Name() => "Test: parameters of every content type"
    static Category() => "Test"

    static Parameters(ctx) => [
        {type: "Label", label: "Test"},
        {type: "Edit", id: "Expr", content: "Expression", default: "1"},
        {type: "Edit", id: "Num", content: "number", default: "1"},
        {type: "Edit", id: "PosInt", content: "positiveInteger", default: "1"},
        {type: "Edit", id: "Either", content: ["String", "Expression"], contentID: "EitherType", contentDefault: "string"},
        {type: "Edit", id: "Text", content: "String"},
        {type: "Edit", id: "VarName", content: "VariableName"},
        {type: "Edit", id: "Raw", content: "RawString"},
        {type: "Edit", id: "Script"},
        {type: "Edit", id: "Condition"},
        {type: "Radio", id: "EitherType", default: "string", result: "enum", enum: ["string", "expression"]}
    ]

    static Run(ctx, params) {
        ctx.Finish("normal")
    }
}

ElementRegistry.Register(Action_TestExprParams)
