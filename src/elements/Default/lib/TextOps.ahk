#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; The text operations of the package Default (WI-0119): the parts of the string elements (Search in a string, Substring,
; Substring2, Get string length, Replace in a string, Trim a string, Split a string, Change character case, Encode
; string, String contains text) that are more than one AutoHotkey call. Every function is pure (no ctx, no I/O).
; Positions are 1-based as in v1; a count of 0 or less gives the empty text, as v1 did for the left and right parts
; (a negative count is not a value that the v2 functions SubStr and Trim would read the same way, so it is handled here).
class TextOps {
    ; The text of a value of a text parameter. An object (a list or a map from an expression) is an error, as in v1.
    static Text(value, what) {
        if (IsObject(value))
            throw ElementError(Lang("Expression '%1%' does not contain a string.", what))
        return String(value)
    }

    ; An integer from a number parameter (a decimal number is cut off, as v1 did with StringLeft and friends).
    static Count(value) => Integer(Number(value))

    ; The value of a parameter of the parameter description of the element: the stored value or the empty text.
    static Par(params, name) => params.HasProp(name) ? params.%name% : ""

    ; v1 StringLeft: the first `count` characters.
    static Left(text, count) => count <= 0 ? "" : SubStr(text, 1, count)

    ; v1 StringRight: the last `count` characters.
    static Right(text, count) => count <= 0 ? "" : SubStr(text, -count)

    ; v1 StringMid to the right of `start`: `count` characters from `start` (count "" for all of them). A start before
    ; the first character counts as the first one.
    static Mid(text, start, count := "") {
        if (start < 1)
            start := 1
        if (count = "")
            return SubStr(text, start)
        if (count <= 0)
            return ""
        return SubStr(text, start, count)
    }

    ; v1 StringMid with the option L: the `count` characters that end at `start` (start itself included), or all
    ; characters up to `start` (count ""). A start before the first character gives the empty text.
    static MidLeft(text, start, count := "") {
        if (start < 1 || (count != "" && count <= 0))
            return ""
        last := Min(start, StrLen(text))
        first := (count = "") ? 1 : Max(1, start - count + 1)
        if (first > last)
            return ""
        return SubStr(text, first, last - first + 1)
    }

    ; The split of a text into its fields: v1 `loop, parse` with the delimiter characters and the omit characters (the
    ; same rules as the parse loop of Loop_Parse_A_String, also the CSV mode of AutoHotkey). An empty delimiter text
    ; makes every character a field, as in v1. Empty fields are fields.
    static Split(text, delimiters, omitChars) {
        fields := []
        loop parse text, delimiters, omitChars
            fields.Push(A_LoopField)
        return fields
    }

    ; The case change of v1 StringUpper, StringLower and StringUpper with T (title case). kind: "upper", "lower" or
    ; "firstUp" (the first letter of every word is uppercase, the other letters lowercase).
    static ChangeCase(text, kind) {
        switch kind {
            case "upper": return StrUpper(text)
            case "lower": return StrLower(text)
            case "firstUp": return StrTitle(text)
        }
        throw ElementError("Change character case: unknown case '" kind "'")
    }

    ; The URI encoding of the v1 function UriEncode: every byte of the UTF-8 form of the text that is not an unreserved character
    ; (A-Z, a-z, 0-9, '-', '.', '_', '~') becomes %XX with uppercase hex digits. The UTF-8 bytes come from StrPut, so
    ; no DllCall is needed.
    static UriEncode(text) {
        size := StrPut(text, "UTF-8") - 1          ; the bytes without the terminating zero
        buf := Buffer(size + 1, 0)
        StrPut(text, buf, "UTF-8")
        out := ""
        loop size {
            b := NumGet(buf, A_Index - 1, "UChar")
            if ((b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
                || b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E)
                out .= Chr(b)
            else
                out .= Format("%{:02X}", b)
        }
        return out
    }
}
