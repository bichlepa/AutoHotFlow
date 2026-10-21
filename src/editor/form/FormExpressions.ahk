#Requires AutoHotkey v2.0
#Include ..\..\core\Lang.ahk
#Include ..\..\elements\base\ParamEvaluator.ahk
#Include ..\..\expr\Expr.ahk
#Include FormField.ahk
#Include FormChecks.ahk

; The syntax check of the expression fields of the settings form (WI-0108, REQ-EDT-200, E0096). A field whose text is an
; expression or a script is parsed (not evaluated) when the user stops typing; the form (ElementForm.CheckExpressions) asks
; Kind for every value and Warning for the text. Which texts are checked:
;   - an edit field whose content type is an expression type (ParamEvaluator.EXPRESSION_CONTENT, the types chosen by
;     contentID included) is an expression;
;   - a parameter that the element evaluates itself is named in its static V1Syntax (ELEMENT-API-V2 section 2): "expression"
;     or "script" with the matching parser;
;   - a String text is not checked: its %name% parts are variable names of v1 substitution, not expression syntax
;     (EXPRESSION-LANGUAGE section 18.5, ELEMENT-API-V2 section 3.1).
; A text longer than MAX_CHARS is not parsed while typing: the parse of a script takes about 0.4 ms per line on the
; development PC (measured in WI-0108), and the editor role must stay responsive. The warning says so.
class FormExpressions {
    static MAX_CHARS := 4000
    static KINDS := Map("edit", 1, "multilineedit", 1, "combobox", 1)

    ; The syntax to check for the id of a field: "expression", "script", or "" (not checked). The field must be an enabled
    ; text field with a value; values is the value Map of the form (the content type of a choice is read from it).
    static Kind(cls, field, id, values) {
        if (!FormExpressions.KINDS.Has(field.kind) || !field.isEnabled || !field.isValue)
            return ""
        if (field.content.Length) {
            if (ParamEvaluator.EXPRESSION_CONTENT.Has(FormChecks.ContentType(field, values)))
                return "expression"
        }
        return FormExpressions._V1Syntax(cls, id)
    }

    ; The warning for a text of the kind, or "" when the text is fine. The first syntax error with its position (line and
    ; column, as the parser counts them), and the number of the others.
    static Warning(text, kind) {
        if (text = "")
            return ""
        if (StrLen(text) > FormExpressions.MAX_CHARS)
            return Lang("Too long to check while typing: at most %1% characters", FormExpressions.MAX_CHARS)
        try {
            errors := Expr.Parse(text, kind, false)["errors"]
        } catch as e {
            return ""                    ; the parser never throws because of a text; a failure here must not reach the timer
        }
        if (errors.Length = 0)
            return ""
        first := errors[1]
        out := Lang("Syntax error at line %1%, column %2%: %3%", first["line"], first["col"], first["message"])
        if (errors.Length > 1)
            out .= " " Lang("(%1% more)", errors.Length - 1)
        return out
    }

    ; The kind that the V1Syntax of the class names for the parameter id ("" when it names none).
    static _V1Syntax(cls, id) {
        syntax := ""
        try syntax := cls.V1Syntax
        if (!(syntax is Map))
            return ""
        for name, kind in syntax {
            if (StrLower(name) = StrLower(id) && (kind = "expression" || kind = "script"))
                return kind
        }
        return ""
    }
}
