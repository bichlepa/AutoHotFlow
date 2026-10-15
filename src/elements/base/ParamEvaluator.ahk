#Requires AutoHotkey v2.0
#Include ..\..\core\Lang.ahk
#Include ..\..\expr\Expr.ahk
#Include ..\..\expr\ExprDiag.ahk
#Include ..\..\expr\ExprNames.ahk

; Evaluation of the parameters of an element (WI-0042, doc/ELEMENT-API-V2.md section 3.1): the port of v1
; x_AutoEvaluateOneParameter (v1/Source_Execution/API/API for Elements.ahk:171) with the new expression language.
; Used by ExecContext.EvalParams (inline elements, on call) and by the engine for worker elements, which evaluates
; every parameter before the job is sent (E0026).
;
; A parameter description is an entry of Parameters() of the class (an object literal or a Map) with
;   id                  the parameter, or an Array of parameters that share the description
;   type                "file" and "folder" are paths; "Label" and "Button" are skipped
;   content             String, Expression, number, positiveNumber, integer, positiveInteger, positiveIntegerOrZero,
;                       VariableName, RawString or empty; an Array: the user selects the type in the parameter
;                       named by contentID (default contentDefault)
;   WarnIfEmpty         an empty value (or result) is an error
;   contentConvertObjects  String: an object in %var% gives its JSON text
;   default             the value when the flow does not have the parameter (v1 fills it in when it loads a flow)
;
; The evaluation needs a source: an object with
;   vars        the variable access of the element run (VarAccess of the engine: Replace, and the resolver of Expr)
;   workingDir  the working directory of the flow (relative paths of file and folder parameters)
;   strict      1 in strict mode (flow option strictTypes, E0034): a warning of the evaluator is an error
;   logFn       logFn(level, text) for the log entries of the evaluator, or ""
; One result is a Map: id, value, error ("" if there is none). The error texts are those of v1 (Lang).
class ParamEvaluator {
    static EXPRESSION_CONTENT := Map("expression", 1, "number", 1, "positivenumber", 1, "integer", 1
        , "positiveinteger", 1, "positiveintegerorzero", 1)

    ; The parameters that are evaluated, in the order of Parameters(ctx): an Array of Maps id, spec, n (the index of
    ; the id in an Array of ids, else 0). Labels and buttons are skipped (v1 skips labels; it meant to skip buttons
    ; too, but its check had a typo).
    static List(cls, ctx) {
        out := []
        for spec in cls.Parameters(ctx) {
            ids := ParamEvaluator.Field(spec, "id")
            if (!IsObject(ids) && ids = "")
                continue
            kind := ParamEvaluator.Field(spec, "type")
            if (!IsObject(kind) && (kind = "label" || kind = "button"))
                continue
            if (ids is Array) {
                for i, id in ids
                    out.Push(Map("id", id, "spec", spec, "n", i))
            } else {
                out.Push(Map("id", ids, "spec", spec, "n", 0))
            }
        }
        return out
    }

    ; Evaluates one entry of List. params: the parameters of the element (object with case-insensitive properties).
    static One(item, params, src) {
        id := item["id"]
        spec := item["spec"]
        raw := ParamEvaluator.RawValue(item, params)
        content := ParamEvaluator.Field(spec, "content")
        if (content is Array) {
            cid := ParamEvaluator.Field(spec, "contentID")
            content := (cid != "" && params.HasProp(cid)) ? params.%cid% : ParamEvaluator.Field(spec, "contentDefault")
        }
        kind := ParamEvaluator.Field(spec, "type")
        warnIfEmpty := ParamEvaluator.Truthy(ParamEvaluator.Field(spec, "WarnIfEmpty"))
        err := ""
        if (!IsObject(kind) && (kind = "file" || kind = "folder")) {
            ; a path: %var% substitution, then the full path in the working directory of the flow
            value := src.vars.Replace(String(raw))
            if (warnIfEmpty && value = "")
                err := Lang("String '%1%' is empty", id)
            value := ParamEvaluator.FullPath(value, src.workingDir)
            return ParamEvaluator._Result(id, value, err)
        }
        c := IsObject(content) ? "?" : StrLower(String(content))
        if (c = "string") {
            value := src.vars.Replace(String(raw), ParamEvaluator.Truthy(ParamEvaluator.Field(spec, "contentConvertObjects")))
            if (warnIfEmpty && value = "")
                err := Lang("String '%1%' is empty", id)
        } else if (ParamEvaluator.EXPRESSION_CONTENT.Has(c)) {
            text := String(raw)
            res := Expr.Evaluate(text, src.vars, src.logFn)
            value := res["value"]
            if (res["errors"].Length)
                err := Lang("An error occured while parsing expression '%1%'", text) "`n`n" ExprDiag.FormatAll(res["errors"])
            else if (src.strict && res["warnings"].Length)
                err := Lang("An error occured while parsing expression '%1%'", text) "`n`n" ExprDiag.FormatAll(res["warnings"])
            empty := !IsObject(value) && value = ""
            if (warnIfEmpty && empty) {
                err := Lang("Result of expression '%1%' is empty", text)
            } else if (!empty) {
                ; the checks of v1 run one after the other; the last one that fails gives the message
                if ((c = "number" || c = "positivenumber") && !IsNumber(value))
                    err := Lang("Result of expression '%1%' is not a number", text)
                if ((c = "integer" || c = "positiveinteger" || c = "positiveintegerorzero") && !IsInteger(value))
                    err := Lang("Result of expression '%1%' is not an integer", text)
                if (c = "positiveinteger" && !ParamEvaluator.V1AtLeast(value, 1))
                    err := Lang("Result of expression '%1%' is not a positive number", text)
                if ((c = "positiveintegerorzero" || c = "positivenumber") && !ParamEvaluator.V1AtLeast(value, 0))
                    err := Lang("Result of expression '%1%' is not a positive number or zero", text)
            }
        } else if (c = "variablename") {
            value := src.vars.Replace(String(raw))
            if ((warnIfEmpty || value != "") && ExprNames.Check(value) != "OK")
                err := Lang("%1% is not valid.", Lang("Variable name '%1%'", value))
        } else if (c = "rawstring" || c = "") {
            value := raw
            if (warnIfEmpty && !IsObject(value) && value = "")
                err := Lang("Parameter '%1%' is empty", id)
        } else {
            value := raw
            err := Lang("Parameter '%1%' has unsupported content type", id)
        }
        return ParamEvaluator._Result(id, value, err)
    }

    ; The stored value of a parameter, or the default of its description if the flow does not have it (v1 sets the
    ; defaults of missing parameters when it loads a flow, Load.ahk:128). An object is the empty text.
    static RawValue(item, params) {
        id := item["id"]
        if (params.HasProp(id)) {
            v := params.%id%
            return IsObject(v) ? "" : v
        }
        d := ParamEvaluator.Field(item["spec"], "default")
        if (d is Array)
            d := (item["n"] >= 1 && item["n"] <= d.Length && d.Has(item["n"])) ? d[item["n"]] : ""
        return IsObject(d) ? "" : d
    }

    ; v1 "value >= n" after "is number": numbers compare as numbers; a text that is not a number compares
    ; alphabetically with the text of n, without case (v1 rules; "abc" >= 1 is true there). An object is false.
    static V1AtLeast(value, n) {
        if (IsObject(value))
            return false
        if (IsNumber(value))
            return Number(value) >= n
        return StrCompare(String(value), String(n)) >= 0
    }

    ; The full path (v1 xx_GetFullPath): a relative path is put below the working directory. As in v1 an empty path
    ; is relative too (Shlwapi PathIsRelative).
    static FullPath(path, workingDir) {
        if (DllCall("Shlwapi.dll\PathIsRelativeW", "Str", path, "Int"))
            return workingDir "\" path
        return path
    }

    ; A set (Map, case-insensitive) of parameter ids from an Array, a text with commas, or "".
    static NameSet(names) {
        m := Map()
        m.CaseSense := "Off"
        if (names is Array) {
            for name in names
                m[String(name)] := true
        } else if (!IsObject(names) && names != "") {
            for name in StrSplit(names, ",", " `t")
                if (name != "")
                    m[name] := true
        }
        return m
    }

    ; A field of a parameter description (object literal or Map); "" if absent.
    static Field(spec, name) {
        if (spec is Map)
            return spec.Has(name) ? spec[name] : ""
        return (IsObject(spec) && spec.HasProp(name)) ? spec.%name% : ""
    }

    ; True for a set flag of a description: true, 1, "1", "true" (a description may come from a parsed file).
    static Truthy(v) => !IsObject(v) && v != "" && v != 0 && v != "0" && v != "false"

    static _Result(id, value, err) => Map("id", id, "value", value, "error", err)
}
