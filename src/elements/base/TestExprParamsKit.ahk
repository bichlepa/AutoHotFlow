#Requires AutoHotkey v2.0
#Include ..\..\core\Json.ahk

; Shared parts of Action_TestExprParams (inline) and Action_TestExprParamsWorker (worker), WI-0039 and WI-0042: the
; parameter list, the evaluation and the report. No element class and no ElementRegistry.Register here: a class file
; that includes this file must not register a class in a role that does not hold it (F-0081, E0041).
class TestExprParamsKit {
    static Parameters(ctx) => [
        {type: "Label", label: "Test"},
        {type: "Edit", id: "Expr", content: "Expression", default: "1"},
        {type: "Edit", id: "Num", content: "number", default: "1"},
        {type: "Edit", id: "PosNum", content: "positiveNumber", default: "1"},
        {type: "Edit", id: "Int", content: "integer", default: "1"},
        {type: "Edit", id: "PosInt", content: "positiveInteger", default: "1"},
        {type: "Edit", id: "PosIntOrZero", content: "positiveIntegerOrZero", default: "0"},
        {type: "Edit", id: "NeededExpr", content: "Expression", default: "1", WarnIfEmpty: true},
        {type: "Edit", id: "Either", content: ["String", "Expression"], contentID: "EitherType", contentDefault: "string"},
        {type: "Edit", id: "Text", content: "String"},
        {type: "Edit", id: "Json", content: "String", contentConvertObjects: true},
        {type: "Edit", id: "Needed", content: "String", default: "x", WarnIfEmpty: true},
        {type: "Edit", id: "VarName", content: "VariableName"},
        {type: "Edit", id: "NeededVar", content: "VariableName", default: "v", WarnIfEmpty: true},
        {type: "Edit", id: "Raw", content: "RawString"},
        {type: "Edit", id: "NeededRaw", content: "RawString", default: "r", WarnIfEmpty: true},
        {type: "File", id: "File"},
        {type: "File", id: "NeededFile", default: "f", WarnIfEmpty: true},
        {type: "Folder", id: "Folder"},
        {type: "Edit", id: "Script"},
        {type: "Edit", id: "Condition"},
        {type: "Radio", id: "EitherType", default: "string", result: "enum", enum: ["string", "expression"]},
        {type: "Button", id: "Pick", label: "..."},
        {type: "Edit", id: ["Tag", "Skip", "More"], content: "RawString", default: ["", "", ""]}
    ]

    ; ctx.EvalParams with the skip list Skip, then ctx.EvalMoreParams for More.
    static Evaluate(ctx, params) {
        p := ctx.EvalParams(params, params.HasProp("Skip") ? params.Skip : "")
        if (params.HasProp("More") && params.More != "")
            p := ctx.EvalMoreParams(p, params, params.More)
        return p
    }

    static ResultName(params) => "global_evalresult" ((params.HasProp("Tag") && params.Tag != "") ? "_" params.Tag : "")

    ; JSON text: id -> {"type": Type(value), "value": value}. Tag, Skip and More are left out.
    static Report(p) {
        out := Map()
        for id, value in p.OwnProps() {
            if (id = "Tag" || id = "Skip" || id = "More")
                continue
            out[id] := Map("type", Type(value), "value", value)
        }
        return Json.Stringify(out)
    }
}
