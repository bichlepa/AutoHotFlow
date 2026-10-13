#Requires AutoHotkey v2.0

; Rules for variable names (doc/EXPRESSION-LANGUAGE.md section 3), same answers as v1 Var_CheckName(name, true).
class ExprNames {
    ; Longest name AutoHotkey accepts.
    static MAX_LENGTH := 253

    ; Returns "OK", "Empty", "StartsWithNumber" or "ForbiddenCharacter".
    ; Allowed: the ASCII letters and digits, "_", "#", "@", "$" and every character above U+007F.
    ; A name must not start with an ASCII digit. A name longer than 253 characters is forbidden.
    ; The expression language itself can write only the subset without "#", "@" and "$" (IsWordChar);
    ; the other names are reachable through a dynamic name such as %n%.
    static Check(name) {
        if (name = "")
            return "Empty"
        if (StrLen(name) > ExprNames.MAX_LENGTH)
            return "ForbiddenCharacter"
        c := Ord(name)
        if (c >= 0x30 && c <= 0x39)
            return "StartsWithNumber"
        if (!RegExMatch(name, "^[A-Za-z0-9_#@$\x{80}-\x{10FFFF}]+$"))
            return "ForbiddenCharacter"
        return "OK"
    }

    ; True if name is valid in the sense of Check.
    static IsValid(name) => ExprNames.Check(name) == "OK"

    ; True if the first character of s may be part of a name written in an expression.
    static IsWordChar(ch) {
        c := Ord(ch)
        return (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || (c >= 0x30 && c <= 0x39) || c == 0x5F || c > 0x7F
    }

    ; Lower case spelling if word is a keyword of the language, else "".
    static Keyword(word) {
        switch StrLower(word) {
            case "and", "or", "not", "if", "else", "true", "false":
                return StrLower(word)
        }
        return ""
    }
}
