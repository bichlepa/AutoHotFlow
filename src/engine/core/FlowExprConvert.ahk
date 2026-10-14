#Requires AutoHotkey v2.0
#Include ..\..\core\Log.ahk
#Include ..\..\expr\V1ExprConverter.ahk
#Include ..\..\expr\MigrationClasses.ahk
#Include ..\..\elements\base\ElementRegistry.ahk
#Include FlowDefinition.ahk

; Conversion of the expression texts of a flow from v1 syntax into the new language when the flow is loaded
; (WI-39, E22, doc/EXPRESSION-LANGUAGE.md section 15, doc/ARCHITECTURE.md section 7).
;
; Only the element class knows which parameters are expressions. Per element of the flow:
;   - its class is in the registry: the texts of its expression parameters are converted (V1ExprConverter);
;   - its class is unknown (most of them in S1 to S7, E20): the v1 texts stay, the element is listed in
;     FlowDefinition.Pending. A save writes the element with the marker "v1Text", so the texts are converted as soon
;     as the class exists, even when v2 has saved the flow in the meantime.
; A file that was saved by v2 carries the root key "formatVersion"; there only the marked elements are converted. A
; file without it comes from v1: all elements are candidates. Nothing is converted twice.
;
; Which parameters are expressions (v1 content types): `content` of a parameter of Parameters() is Expression, number,
; positiveNumber, integer, positiveInteger or positiveIntegerOrZero; if `content` is an Array, the parameter named in
; `contentID` holds the selected type. Parameters that the element evaluates itself (v1: x_EvaluateExpression or
; x_EvaluateScript on a RawString) are named by the class in `static V1Syntax := Map("Script", "script", ...)`.
;
; Every conversion is in the log (level f2), every text that cannot be converted at level f1.
;
; Migration markers (WI-45, E35): a text that the converter leaves unchanged or only partly converts, and whose
; behaviour differs from v1 in a way the text shows (V1ExprDetect), is recorded at the element in the key "migration":
; a list of {par, ids, v1}: the parameter ID, the MIGRATION IDs (doc/MIGRATION.md) and the v1 text as it was before the
; conversion. The key is part of the element (unknown keys are kept and written back), it stays until the place is
; resolved, and a place that is marked already is not marked again, so load, save, load is stable.
class FlowExprConvert {
    static EXPRESSION_CONTENT := Map("expression", 1, "number", 1, "positivenumber", 1, "integer", 1
        , "positiveinteger", 1, "positiveintegerorzero", 1)

    ; Converts the flow in place. Returns a Map with the counts: converted (texts), unchanged (texts that need no
    ; change), unsupported, failed, pending (elements that wait for their class).
    static Run(def) {
        counts := Map("converted", 0, "unchanged", 0, "unsupported", 0, "failed", 0, "pending", 0, "marked", 0)
        raw := def.Raw
        versioned := raw.Has(FlowDefinition.FORMAT_KEY)
        elements := raw["allElements"]
        for id, el in elements {
            marked := FlowExprConvert.IsMarked(el)
            if (el.Has(FlowDefinition.MARKER_KEY))
                el.Delete(FlowDefinition.MARKER_KEY)         ; the state is in def.Pending from here on
            if (versioned && !marked)
                continue
            cls := ElementRegistry.Get(FlowDefinition.TextOf(def.FlowId, el, "class", ""))
            if (!IsObject(cls)) {
                def.Pending[id] := true
                counts["pending"] += 1
                continue
            }
            try {
                specs := FlowExprConvert.Specs(cls, el)
            } catch as e {
                def.Pending[id] := true
                counts["pending"] += 1
                Log.Write("f1", "flow load", "element '" id "': the parameters of class '" ElementRegistry.IdOf(cls)
                    . "' cannot be read (" Type(e) ": " e.Message "); its expression texts stay in v1 syntax", def.FlowId)
                continue
            }
            pars := el.Has("pars") ? el["pars"] : ""
            if (!(pars is Map))
                continue
            for parId, kind in specs
                FlowExprConvert._ConvertOne(def, id, el, pars, parId, kind, counts)
        }
        total := counts["converted"] + counts["unsupported"] + counts["failed"] + counts["pending"]
        if (total > 0)
            Log.Write("f2", "flow load", "expression texts: " counts["converted"] " converted, " counts["unsupported"]
                " unsupported, " counts["failed"] " failed, " counts["pending"] " element(s) wait for their class", def.FlowId)
        return counts
    }

    ; True if the element carries the marker "v1Text" (true, 1 or "1").
    static IsMarked(el) {
        if (!el.Has(FlowDefinition.MARKER_KEY))
            return false
        v := el[FlowDefinition.MARKER_KEY]
        return v == Json.True || (!IsObject(v) && (v = 1 || v = "1" || v = "true"))
    }

    ; The parameters of the element (id -> "expression" or "script") that hold v1 syntax. Throws if Parameters() fails.
    static Specs(cls, el) {
        specs := Map()
        specs.CaseSense := "Off"
        pars := el.Has("pars") ? el["pars"] : Map()
        for p in cls.Parameters("") {
            ids := FlowExprConvert.Field(p, "id")
            if (ids == "")
                continue
            content := FlowExprConvert.Field(p, "content")
            if (content is Array) {
                cid := FlowExprConvert.Field(p, "contentID")
                content := ""
                if (cid != "") {
                    content := (pars is Map && pars.Has(cid)) ? pars[cid] : FlowExprConvert.Field(p, "contentDefault")
                }
            }
            if (IsObject(content) || !FlowExprConvert.EXPRESSION_CONTENT.Has(StrLower(content)))
                continue
            for parId in (ids is Array ? ids : [ids])
                specs[parId] := "expression"
        }
        syntax := cls.V1Syntax
        if (syntax is Map) {
            for parId, kind in syntax
                specs[parId] := kind
        }
        return specs
    }

    ; A field of a parameter description, which is an object literal ({id: ...}) or a Map. "" if absent.
    static Field(p, name) {
        if (p is Map)
            return p.Has(name) ? p[name] : ""
        return (IsObject(p) && p.HasProp(name)) ? p.%name% : ""
    }

    static _ConvertOne(def, elementId, el, pars, parId, kind, counts) {
        if (!pars.Has(parId) || IsObject(pars[parId]))
            return
        old := String(pars[parId])
        conv := V1ExprConverter.Convert(old, kind)
        where := "element '" elementId "' parameter '" parId "'"
        ids := MigrationClasses.IdsOf(conv["classes"])
        if (ids.Length && FlowExprConvert.Mark(el, parId, ids, old))
            counts["marked"] += 1
        switch conv["status"] {
            case "converted":
                pars[parId] := conv["text"]
                counts["converted"] += 1
                Log.Write("f2", "flow load", where ": '" FlowExprConvert.OneLine(old) "' -> '"
                    . FlowExprConvert.OneLine(conv["text"]) "'", def.FlowId)
            case "unsupported", "failed":
                counts[conv["status"]] += 1
                Log.Write("f1", "flow load", where " stays in v1 syntax: " conv["messages"][1] " ('"
                    . FlowExprConvert.OneLine(old) "')", def.FlowId)
            default:
                counts["unchanged"] += 1
        }
    }

    ; Records the place in el["migration"] unless the parameter is listed already (the first v1 text stays).
    ; Returns true if an entry was added.
    static Mark(el, parId, ids, v1Text) {
        key := FlowDefinition.MIGRATION_KEY
        list := (el.Has(key) && el[key] is Array) ? el[key] : []
        for entry in list {
            if (entry is Map && entry.Has("par") && entry["par"] == parId)
                return false
        }
        list.Push(Map("par", parId, "ids", ids, "v1", v1Text))
        el[key] := list
        return true
    }

    static OneLine(text) {
        text := StrReplace(text, "`r", "\r")
        text := StrReplace(text, "`n", "\n")
        return StrLen(text) > 300 ? SubStr(text, 1, 297) "..." : text
    }
}
