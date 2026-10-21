#Requires AutoHotkey v2.0
#Include ..\..\core\Lang.ahk
#Include ..\..\expr\ExprNames.ahk
#Include FormField.ahk

; The checks of one value of a settings field (WI-0105, doc/ELEMENT-API-V2.md section 2.1). They give warnings, not
; refusals (v1 warned too). Headless: no variables are known, so a name with %...% is checked with a placeholder, and a
; number content type checks a plain number only; the syntax of an expression is checked by FormExpressions (WI-0108).
class FormChecks {
    static NUMBER_TYPES := Map("number", 1, "positivenumber", 1, "integer", 1, "positiveinteger", 1
        , "positiveintegerorzero", 1)

    ; The content type of an edit field in lower case, or "" when the field has none. A field with one content type has
    ; it; a field with a choice takes the value of contentID (the text of the entry, or its index), else contentDefault,
    ; else the first entry.
    static ContentType(field, values) {
        content := field.content
        if (content.Length = 0)
            return ""
        if (content.Length = 1)
            return StrLower(content[1])
        raw := (field.contentId != "" && values.Has(field.contentId)) ? values[field.contentId] : field.contentDefault
        if (!IsObject(raw) && IsInteger(raw) && raw >= 1 && raw <= content.Length)
            return StrLower(content[raw])
        if (!IsObject(raw))
            for choice in content
                if (StrLower(choice) = StrLower(String(raw)))
                    return StrLower(choice)
        if (field.contentDefault != "")
            for choice in content
                if (StrLower(choice) = StrLower(field.contentDefault))
                    return StrLower(choice)
        return StrLower(content[1])
    }

    ; The warnings of one value of a field as an Array of texts (empty when the value is fine). contentType is the
    ; result of ContentType. An object value (a list, a map) has no text to check.
    static Value(field, value, contentType) {
        out := []
        if (IsObject(value))
            return out
        text := String(value)
        if (text = "") {
            if (field.warnIfEmpty)
                out.Push(Lang("This field must not be empty!"))
            return out
        }
        if (contentType = "variablename") {
            probe := RegExReplace(text, "%[^%]*%", "someVarName")
            if (ExprNames.Check(probe) != "OK")
                out.Push(Lang("%1% is not valid.", Lang("Variable name '%1%'", text)))
        } else if (FormChecks.NUMBER_TYPES.Has(contentType) && IsNumber(text)) {
            if (contentType = "integer" || contentType = "positiveinteger" || contentType = "positiveintegerorzero") {
                if (!IsInteger(text))
                    out.Push(Lang("%1% is not an integer.", text))
            }
            ; positive: at least 0; positiveInteger: at least 1 (v1: "positive integer (0 is not allowed)")
            if (contentType != "number" && contentType != "integer"
                && (Number(text) < 0 || (contentType = "positiveinteger" && Number(text) < 1)))
                out.Push(Lang("%1% is not a positive number.", text))
        }
        return out
    }
}
