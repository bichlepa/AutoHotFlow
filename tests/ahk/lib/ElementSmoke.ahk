#Requires AutoHotkey v2.0
#Include ..\..\..\src\elements\base\AhfElement.ahk
#Include ..\..\..\src\elements\base\ElementRegistry.ahk
#Include ..\..\..\src\elements\base\ParamEvaluator.ahk
#Include ..\..\..\src\core\Log.ahk

; The L0001 smoke test of an element class (WI-0048, doc/ELEMENT-API-V2.md sections 2 and 3.1, doc/TEST-STRATEGY.md).
; Check(cls) looks at one class without any test code of the element: metadata, Parameters, V1Syntax, GenerateName,
; language keys, and the methods that belong to the mode. It returns a Map with
;   errors   an Array of texts "[rule] what is wrong"; empty = the class passes
;   byHand   an Array of texts: v1 evaluates a parameter in a way that the test cannot assign to a parameter with
;            certainty; a person has to look at it (never a silent pass)
; The caller names the class in the output (ElementRegistry.IdOf(cls)). Every call of the class runs under try/catch:
; a class that throws is a finding, not a crash of the test.
class ElementSmoke {
    static MODES := ["inline", "worker", "trigger"]
    static LEVELS := ["Beginner", "Advanced", "Programmer"]
    static STABILITIES := ["Stable", "Experimental"]
    ; The field types of the editor that v1 elements use (checked in v1/Source_Elements: 16 types). EvalParams treats
    ; "label" and "button" as no parameter, "file" and "folder" as paths and every other type by its content.
    static TYPES := ["label", "button", "edit", "multilineedit", "checkbox", "radio", "dropdown", "combobox", "listbox"
        , "slider", "file", "folder", "hotkey", "dateandtime", "weekdays"]
    ; Content types that ParamEvaluator evaluates ("" = none, same as rawstring), and the ones that are expressions.
    static CONTENTS := ["string", "expression", "number", "positivenumber", "integer", "positiveinteger"
        , "positiveintegerorzero", "variablename", "rawstring", ""]
    static EXPRESSION_CONTENTS := ["expression", "number", "positivenumber", "integer", "positiveinteger"
        , "positiveintegerorzero"]
    static TRIGGER_METHODS := ["Enable", "Disable", "TriggerVariables"]

    ; packagesDir: the folder with the element packages (for Icons/). v1Dir: v1/Source_Elements ("" or a missing
    ; folder = the v1 rule is not checked). v1Package: the v1 package folder if it is not the package of the class (a
    ; test of the test).
    static Check(cls, packagesDir, v1Dir := "", v1Package := "") {
        res := Map("errors", [], "byHand", [])
        errors := res["errors"]
        id := ElementRegistry.IdOf(cls)
        package := ElementRegistry.PackageOf(id)
        Log.memoryLines := []
        ElementSmoke._Metadata(cls, errors, packagesDir, package)
        params := ElementSmoke._Parameters(cls, errors)
        ElementSmoke._ParameterRules(params, errors)
        ElementSmoke._V1Syntax(cls, params, errors)
        ElementSmoke._GenerateName(cls, params, errors)
        ElementSmoke._Methods(cls, errors)
        ElementSmoke._LangKeys(errors)
        if (v1Dir != "" && DirExist(v1Dir))
            ElementSmoke._V1SelfEvaluated(cls, id, params, v1Dir, res, v1Package)
        return res
    }

    ; Mode, Level, Stability, Name, Category, Icon, JobTimeoutMs.
    static _Metadata(cls, errors, packagesDir, package) {
        if (!ElementSmoke._In(ElementSmoke.MODES, cls.Mode))
            errors.Push("[mode] Mode must be inline, worker or trigger, not '" ElementSmoke._Show(cls.Mode) "'")
        if (!ElementSmoke._In(ElementSmoke.LEVELS, cls.Level))
            errors.Push("[level] Level must be Beginner, Advanced or Programmer, not '" ElementSmoke._Show(cls.Level) "'")
        if (!ElementSmoke._In(ElementSmoke.STABILITIES, cls.Stability))
            errors.Push("[stability] Stability must be Stable or Experimental, not '" ElementSmoke._Show(cls.Stability) "'")
        for method in ["Name", "Category"] {
            try {
                text := cls.%method%()
                if (IsObject(text) || text = "")
                    errors.Push("[" StrLower(method) "] " method "() must give a non-empty text, not '" ElementSmoke._Show(text) "'")
            } catch as e {
                errors.Push("[" StrLower(method) "] " method "() throws: " e.Message)
            }
        }
        icon := cls.Icon
        if (IsObject(icon) || (icon != "" && !FileExist(packagesDir "\" package "\Icons\" icon)))
            errors.Push("[icon] Icon '" ElementSmoke._Show(icon) "' is not a file in " package "\Icons")
        timeout := cls.JobTimeoutMs
        if (IsObject(timeout) || !IsInteger(timeout) || timeout < 0)
            errors.Push("[jobtimeout] JobTimeoutMs must be an integer >= 0, not '" ElementSmoke._Show(timeout) "'")
        else if (timeout != 0 && cls.Mode != "worker")
            errors.Push("[jobtimeout] JobTimeoutMs is set (" timeout ") but Mode is '" cls.Mode "'; only worker elements have a job deadline")
    }

    ; Parameters("") without the editor: an Array, or an empty Array if the call fails (the error is recorded).
    static _Parameters(cls, errors) {
        try {
            params := cls.Parameters("")
        } catch as e {
            errors.Push("[parameters] Parameters('') throws (it must not need the editor): " e.Message)
            return []
        }
        if (!(params is Array)) {
            errors.Push("[parameters] Parameters('') must return an Array, not " Type(params))
            return []
        }
        return params
    }

    ; Ids, types, contents, enum and contentID.
    static _ParameterRules(params, errors) {
        ids := Map()
        ids.CaseSense := "Off"
        for spec in params {
            for id in ElementSmoke._Ids(spec) {
                if (ids.Has(id))
                    errors.Push("[param-id] parameter id '" id "' is used twice (ids are compared without case)")
                ids[id] := true
            }
        }
        for spec in params {
            what := "parameter " ElementSmoke._Label(spec)
            if (!IsObject(spec) || !(spec is Map || Type(spec) = "Object")) {
                errors.Push("[param-spec] " what " is neither an object nor a Map")
                continue
            }
            ptype := ParamEvaluator.Field(spec, "type")
            if (IsObject(ptype) || !ElementSmoke._In(ElementSmoke.TYPES, StrLower(ptype)))
                errors.Push("[param-type] " what " has the unknown type '" ElementSmoke._Show(ptype) "'")
            content := ParamEvaluator.Field(spec, "content")
            if (content is Array) {
                for c in content
                    ElementSmoke._CheckContent(c, what, errors)
                cid := ParamEvaluator.Field(spec, "contentID")
                if (cid = "" || IsObject(cid) || !ids.Has(cid))
                    errors.Push("[param-contentid] " what " has a list of content types, but contentID '" ElementSmoke._Show(cid) "' is no parameter")
                cdef := ParamEvaluator.Field(spec, "contentDefault")
                if (!IsObject(cdef) && !ElementSmoke._In(ElementSmoke.CONTENTS, StrLower(cdef)))
                    errors.Push("[param-content] " what " has the unknown contentDefault '" cdef "'")
            } else {
                ElementSmoke._CheckContent(content, what, errors)
            }
            if (StrLower(ElementSmoke._Show(ParamEvaluator.Field(spec, "result"))) = "enum") {
                choices := ParamEvaluator.Field(spec, "choices")
                enum := ParamEvaluator.Field(spec, "enum")
                if (!(choices is Array) || !(enum is Array))
                    errors.Push("[param-enum] " what " has result 'enum' and needs choices and enum as Arrays")
                else if (choices.Length != enum.Length)
                    errors.Push("[param-enum] " what " has " choices.Length " choices but " enum.Length " enum values")
            }
        }
    }

    static _CheckContent(content, what, errors) {
        if (IsObject(content) || !ElementSmoke._In(ElementSmoke.CONTENTS, StrLower(content)))
            errors.Push("[param-content] " what " has a content type that EvalParams does not know: '" ElementSmoke._Show(content) "'")
    }

    ; V1Syntax names only existing parameters, with the kind expression or script.
    static _V1Syntax(cls, params, errors) {
        ids := Map()
        ids.CaseSense := "Off"
        for spec in params {
            for id in ElementSmoke._Ids(spec)
                ids[id] := true
        }
        syntax := cls.V1Syntax
        if (!(syntax is Map)) {
            errors.Push("[v1syntax] V1Syntax must be a Map, not " Type(syntax))
            return
        }
        for name, kind in syntax {
            if (!ids.Has(name))
                errors.Push("[v1syntax] V1Syntax names '" name "', which is no parameter")
            if (kind != "expression" && kind != "script")
                errors.Push("[v1syntax] V1Syntax['" name "'] must be 'expression' or 'script', not '" ElementSmoke._Show(kind) "'")
        }
    }

    ; GenerateName("", defaults) gives a non-empty text.
    static _GenerateName(cls, params, errors) {
        if (!HasMethod(cls, "GenerateName")) {
            errors.Push("[generatename] the class has no GenerateName(ctx, params)")
            return
        }
        defaults := {}
        for spec in params {
            ids := ElementSmoke._Ids(spec)
            def := ParamEvaluator.Field(spec, "default")
            for i, id in ids {
                v := (def is Array) ? (def.Has(i) ? def[i] : "") : def
                defaults.%id% := IsObject(v) ? "" : v
            }
        }
        try {
            name := cls.GenerateName("", defaults)
            if (IsObject(name) || name = "")
                errors.Push("[generatename] GenerateName('', defaults) must give a non-empty text, not '" ElementSmoke._Show(name) "'")
        } catch as e {
            errors.Push("[generatename] GenerateName('', defaults) throws: " e.Message)
        }
    }

    ; The methods match the mode.
    static _Methods(cls, errors) {
        if (cls.Mode = "trigger") {
            for m in ElementSmoke.TRIGGER_METHODS {
                if (!ElementSmoke._Defines(cls, m))
                    errors.Push("[methods] a trigger needs " m "()")
            }
        } else if (cls.Mode = "inline" || cls.Mode = "worker") {
            if (!ElementSmoke._Defines(cls, "Run"))
                errors.Push("[methods] an " cls.Mode " element needs its own Run(ctx, params)")
            for m in ElementSmoke.TRIGGER_METHODS {
                if (ElementSmoke._Defines(cls, m))
                    errors.Push("[methods] " m "() belongs to triggers, but Mode is '" cls.Mode "'")
            }
        }
    }

    ; No key without a text: Name, Category, Parameters and GenerateName were called before, with a memory log.
    static _LangKeys(errors) {
        seen := Map()
        for line in Log.memoryLines {
            if (line["level"] = "f3" && line["source"] = "lang" && !seen.Has(line["text"])) {
                seen[line["text"]] := true
                errors.Push("[lang] " line["text"])
            }
        }
    }

    ; v1 evaluates a parameter itself (x_EvaluateExpression / x_EvaluateScript on a RawString, WI-0043): it needs an
    ; expression content type or a V1Syntax entry. v1/Source_Elements/<package>/<Actions|Conditions|Loops|Triggers>/
    ; <name without prefix>.ahk is the file of the class. What cannot be assigned to a parameter goes to byHand.
    static _V1SelfEvaluated(cls, id, params, v1Dir, res, v1Package) {
        package := (v1Package != "") ? v1Package : ElementRegistry.PackageOf(id)
        name := ElementRegistry.ClassOf(id)
        if (!RegExMatch(name, "^(Action|Condition|Loop|Trigger)_(.+)$", &m))
            return
        folder := m[1] "s"
        path := v1Dir "\" package "\" folder "\" m[2] ".ahk"
        if (!FileExist(path))
            return                              ; a new element has no v1 file
        text := FileRead(path, "UTF-8")
        if (SubStr(text, 1, 1) = Chr(0xFEFF))
            text := SubStr(text, 2)
        text := RegExReplace(text, "m);.*$")    ; v1 comments
        syntax := cls.V1Syntax
        exprIds := Map()
        exprIds.CaseSense := "Off"
        for spec in params {
            content := ParamEvaluator.Field(spec, "content")
            list := (content is Array) ? content : [content]
            isExpr := false
            for c in list {
                if (!IsObject(c) && ElementSmoke._In(ElementSmoke.EXPRESSION_CONTENTS, StrLower(c)))
                    isExpr := true
            }
            if (isExpr) {
                for pid in ElementSmoke._Ids(spec)
                    exprIds[pid] := true
            }
        }
        reported := Map()
        reported.CaseSense := "Off"
        pos := 1
        while (pos := RegExMatch(text, "i)\bx_Evaluate(Expression|Script)\s*\(\s*([^,()]+)\s*,\s*([^,()]*)", &mm, pos)) {
            pos += mm.Len
            arg := Trim(mm[3])
            if (!RegExMatch(arg, "i)^ElementParameters\.(\w+)$", &pm)) {
                res["byHand"].Push("v1 " folder "\" m[2] ".ahk calls x_Evaluate" mm[1] " on '" arg "'; is that a parameter?")
                continue
            }
            pid := pm[1]
            if (!exprIds.Has(pid) && !(syntax is Map && syntax.Has(pid)) && !reported.Has(pid)) {
                reported[pid] := true
                res["errors"].Push("[v1-self-evaluated] v1 evaluates the parameter '" pid "' itself (x_Evaluate" mm[1]
                    "), but it has no expression content type and is not in V1Syntax")
            }
        }
    }

    ; True if the class itself or a class between it and AhfElement defines the static method.
    static _Defines(cls, name) {
        c := cls
        while (IsObject(c) && c != AhfElement) {
            if (c.HasOwnProp(name))
                return true
            c := c.Base
        }
        return false
    }

    ; The ids of a parameter description (an id, or an Array of ids; none for a label).
    static _Ids(spec) {
        id := ParamEvaluator.Field(spec, "id")
        if (id is Array)
            return id
        return (IsObject(id) || id = "") ? [] : [String(id)]
    }

    static _Label(spec) {
        ids := ElementSmoke._Ids(spec)
        if (ids.Length)
            return "'" ids[1] "'"
        return "(" ElementSmoke._Show(ParamEvaluator.Field(spec, "type")) ")"
    }

    static _In(list, value) {
        if (IsObject(value))
            return false
        for item in list {
            if (item = value)
                return true
        }
        return false
    }

    static _Show(v) => IsObject(v) ? "<" Type(v) ">" : String(v)
}
