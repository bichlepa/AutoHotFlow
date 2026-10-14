#Requires AutoHotkey v2.0

; Converter of v1 expressions (WI-39). Placeholder: returns every text unchanged.
class V1ExprConverter {
    static Convert(text, kind := "expression") {
        return Map("status", "unchanged", "text", text, "changes", [], "messages", [])
    }
}
