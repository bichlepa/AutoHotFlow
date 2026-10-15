#Requires AutoHotkey v2.0
#Include Errors.ahk

; JSON reader and writer (WI-0002, doc/ARCHITECTURE.md section 7, v2-phase2-final:work_items/phase2/README.md contract).
;
; Types are kept: a JSON string becomes String, a JSON number without point or exponent becomes
; Integer, any other number becomes Float. So "zoomFactor": "0.700000" stays a String and "x": 7
; stays a number after a round trip.
; A JSON object becomes a Map with CaseSense "Off". Lookup is case-insensitive, and enumeration
; returns the spelling of the first insertion (verified, see tests/ahk/json.test.ahk).
; Keys that differ only in case inside one object are rejected, because the Map would merge them.
;
; Errors are JsonError with line and column. Nothing is repaired silently.
; Booleans: Parse reads true as 1 and false as 0 (so `if x` works in AHK code). Stringify writes
; Json.True and Json.False as true and false, and Integers as numbers. A round trip therefore does
; not keep Booleans: true comes back as 1.
; Output: keys sorted, indent as in v1 Jxon_Dump (indent 2), no BOM. Line breaks are "`n";
; writing the file as UTF-8-RAW keeps it without BOM.
class Json {
    ; Nested classes first, so the static initializer below can refer to them.

    ; Type of the JSON null value. Use it through Json.Null only.
    class NullValue {
    }

    ; Types of the JSON true and false values for writing. Use them through Json.True, Json.False and
    ; Json.Bool only. AHK v2 has no Bool type and every object is truthy, so Json.False is TRUTHY in an
    ; `if`. Never keep these values in program state: use 1 and 0 there and convert with Json.Bool
    ; when the message is built (doc/PROTOCOL.md section 2).
    class TrueValue {
    }

    class FalseValue {
    }

    ; Parser state for one Parse call. Positions are zero-based code units of this.text.
    ; Plain runs (whitespace, string contents) are cut with one RegExMatch call each, which is
    ; much faster than a call per character.
    class Reader {
        __New(text) {
            this.text := text
            this.len := StrLen(text)
            ; UTF-16 copy for NumGet in At(): reading a code unit does not allocate a string.
            this.buf := Buffer(this.len * 2 + 2, 0)
            StrPut(text, this.buf, "UTF-16")
            this.pos := 0
            this.depth := 0
        }

        ParseDocument() {
            value := this.ParseValue()
            this.SkipWs()
            if (this.pos < this.len)
                this.Fail("unexpected text after the value")
            return value
        }

        ; Code unit at zero-based index i, -1 past the end.
        At(i) {
            return (i < this.len) ? NumGet(this.buf, i * 2, "UShort") : -1
        }

        ; Code unit at the current position, -1 at the end.
        Peek() {
            return this.At(this.pos)
        }

        SkipWs() {
            ; Most positions hold no whitespace (compact JSON), so the regex runs only when needed.
            if (this.pos >= this.len || NumGet(this.buf, this.pos * 2, "UShort") > 0x20)
                return
            RegExMatch(this.text, "[ \t\r\n]*", &run, this.pos + 1)
            this.pos += StrLen(run[0])
        }

        ParseValue() {
            this.SkipWs()
            c := this.Peek()
            if (c = -1)
                this.Fail("unexpected end of text")
            if (c = 0x7B)  ; {
                return this.ParseObject()
            if (c = 0x5B)  ; [
                return this.ParseArray()
            if (c = 0x22)  ; "
                return this.ParseString()
            if (c = 0x2D || (c >= 0x30 && c <= 0x39))  ; - or digit
                return this.ParseNumber()
            if (c = 0x74)  ; t
                return this.ParseLiteral("true", 1)
            if (c = 0x66)  ; f
                return this.ParseLiteral("false", 0)
            if (c = 0x6E)  ; n
                return this.ParseLiteral("null", Json.Null)
            this.Fail("unexpected character '" Chr(c) "'")
        }

        ParseLiteral(word, value) {
            n := StrLen(word)
            if (this.pos + n > this.len || SubStr(this.text, this.pos + 1, n) !== word)
                this.Fail("invalid literal, expected " word)
            this.pos += n
            return value
        }

        ParseNumber() {
            start := this.pos
            isFloat := false
            if (this.Peek() = 0x2D)
                this.pos++
            if (this.Peek() = 0x30) {
                this.pos++
            } else if (this.IsDigit()) {
                while (this.IsDigit())
                    this.pos++
            } else {
                this.Fail("invalid number")
            }
            if (this.Peek() = 0x2E) {  ; .
                isFloat := true
                this.pos++
                if (!this.IsDigit())
                    this.Fail("digit expected after decimal point")
                while (this.IsDigit())
                    this.pos++
            }
            if (this.Peek() = 0x65 || this.Peek() = 0x45) {  ; e E
                isFloat := true
                this.pos++
                if (this.Peek() = 0x2B || this.Peek() = 0x2D)  ; + -
                    this.pos++
                if (!this.IsDigit())
                    this.Fail("digit expected in exponent")
                while (this.IsDigit())
                    this.pos++
            }
            text := SubStr(this.text, start + 1, this.pos - start)
            digits := this.pos - start - ((SubStr(text, 1, 1) = "-") ? 1 : 0)
            ; Integers with more than 18 digits do not fit safely into an AHK Integer, so they become Float.
            if (isFloat || digits > 18) {
                value := Float(text)
                if (value - value != 0)  ; inf or NaN
                    this.Fail("number out of range")
                return value
            }
            return Integer(text)
        }

        IsDigit() {
            c := this.Peek()
            return (c >= 0x30 && c <= 0x39)
        }

        ParseString() {
            this.pos++  ; opening quote
            out := ""
            loop {
                ; Plain run up to the next quote, backslash or control character.
                RegExMatch(this.text, '[^"\\\x00-\x1F]*', &run, this.pos + 1)
                out .= run[0]
                this.pos += StrLen(run[0])
                c := this.Peek()
                if (c = 0x22) {
                    this.pos++
                    return out
                }
                if (c = -1)
                    this.Fail("unterminated string")
                if (c < 0x20)
                    this.Fail("unescaped control character in string")
                ; Here c is a backslash.
                this.pos++
                e := this.Peek()
                if (e = -1)
                    this.Fail("unterminated string")
                this.pos++
                out .= this.Unescape(e)
            }
        }

        ; Returns the text for the escape character e (already consumed). \u reads four more digits.
        Unescape(e) {
            if (e = 0x22)
                return '"'
            if (e = 0x5C)
                return "\"
            if (e = 0x2F)
                return "/"
            if (e = 0x62)
                return Chr(8)
            if (e = 0x66)
                return Chr(12)
            if (e = 0x6E)
                return "`n"
            if (e = 0x72)
                return "`r"
            if (e = 0x74)
                return "`t"
            if (e = 0x75)
                return this.UnicodeEscape()
            this.Fail("unknown escape sequence \" Chr(e))
        }

        ; Reads XXXX after \u. A surrogate must be followed by a low surrogate \uXXXX, otherwise JsonError.
        UnicodeEscape() {
            cp := this.Hex4()
            if (cp >= 0xDC00 && cp <= 0xDFFF)
                this.Fail("lone low surrogate in \u escape")
            if (cp >= 0xD800 && cp <= 0xDBFF) {
                if (this.Peek() != 0x5C || this.At(this.pos + 1) != 0x75)
                    this.Fail("lone high surrogate in \u escape")
                this.pos += 2
                lo := this.Hex4()
                if (lo < 0xDC00 || lo > 0xDFFF)
                    this.Fail("high surrogate not followed by low surrogate")
                return Chr(cp) Chr(lo)
            }
            return Chr(cp)
        }

        Hex4() {
            if (this.pos + 4 > this.len)
                this.Fail("incomplete \u escape")
            v := 0
            loop 4 {
                d := Json.HexValue(this.At(this.pos))
                if (d < 0)
                    this.Fail("invalid hex digit in \u escape")
                v := v * 16 + d
                this.pos++
            }
            return v
        }

        ParseObject() {
            this.Enter()
            this.pos++  ; {
            m := Map()
            m.CaseSense := "Off"
            this.SkipWs()
            if (this.Peek() = 0x7D) {  ; }
                this.pos++
                this.depth--
                return m
            }
            loop {
                this.SkipWs()
                if (this.Peek() != 0x22)
                    this.Fail("expected a string as object key")
                key := this.ParseString()
                this.SkipWs()
                if (this.Peek() != 0x3A)  ; :
                    this.Fail("expected ':' after object key")
                this.pos++
                if (m.Has(key))
                    this.Fail("duplicate key '" key "'")
                m[key] := this.ParseValue()
                this.SkipWs()
                c := this.Peek()
                if (c = 0x2C) {  ; ,
                    this.pos++
                } else if (c = 0x7D) {
                    this.pos++
                    break
                } else {
                    this.Fail("expected ',' or '}' in object")
                }
            }
            this.depth--
            return m
        }

        ParseArray() {
            this.Enter()
            this.pos++  ; [
            arr := Array()
            this.SkipWs()
            if (this.Peek() = 0x5D) {  ; ]
                this.pos++
                this.depth--
                return arr
            }
            loop {
                arr.Push(this.ParseValue())
                this.SkipWs()
                c := this.Peek()
                if (c = 0x2C) {
                    this.pos++
                } else if (c = 0x5D) {
                    this.pos++
                    break
                } else {
                    this.Fail("expected ',' or ']' in array")
                }
            }
            this.depth--
            return arr
        }

        Enter() {
            this.depth++
            if (this.depth > Json.MAX_DEPTH)
                this.Fail("nesting deeper than " Json.MAX_DEPTH " levels")
        }

        ; Throws JsonError with line and column (1-based) of the current position.
        Fail(message) {
            limit := (this.pos < this.len) ? this.pos : this.len
            pieces := StrSplit(SubStr(this.text, 1, limit), "`n")
            if (pieces.Length = 0)
                pieces.Push("")
            line := pieces.Length
            column := StrLen(pieces[pieces.Length]) + 1
            throw JsonError(message " at line " line ", column " column)
        }
    }

    ; Singleton for JSON null. Compare with ==, not with =.
    static Null := Json.NullValue()

    ; Singletons for JSON true and false, for writing only (see TrueValue). Compare with ==.
    static True := Json.TrueValue()
    static False := Json.FalseValue()

    ; Maximum nesting depth of arrays and objects. Protects against runaway recursion.
    static MAX_DEPTH := 256

    ; Json.True or Json.False for the truthiness of x as AHK sees it (0, "", "0" and Json.False are false,
    ; any other number or string and any other object is true). Call it where a message is built.
    static Bool(x) {
        if (x == Json.False)
            return Json.False
        if (x == Json.True)
            return Json.True
        if (IsObject(x))
            return Json.True
        return x ? Json.True : Json.False
    }

    ; Parses JSON text. Returns Map | Array | String | Integer | Float, true/false as 1/0, null as Json.Null.
    static Parse(text) {
        reader := Json.Reader(String(text))
        return reader.ParseDocument()
    }

    ; Parses JSON from a Buffer with UTF-8 bytes (for example FileRead(path, "RAW")).
    ; Invalid UTF-8 throws JsonError. A leading UTF-8 BOM is skipped, the rest is strict.
    static ParseBytes(buf) {
        ptr := buf.Ptr
        size := buf.Size
        if (size >= 3 && NumGet(ptr, 0, "UChar") = 0xEF && NumGet(ptr, 1, "UChar") = 0xBB && NumGet(ptr, 2, "UChar") = 0xBF) {
            ptr += 3
            size -= 3
        }
        if (size = 0)
            throw JsonError("empty input")
        ; MB_ERR_INVALID_CHARS (8) makes the conversion strict. Invalid input returns 0.
        count := DllCall("MultiByteToWideChar", "uint", 65001, "uint", 8, "ptr", ptr, "int", size, "ptr", 0, "int", 0, "int")
        lastError := A_LastError
        if (count = 0)
            throw JsonError("input is not valid UTF-8 (system error " lastError ")")
        wide := Buffer(count * 2 + 2, 0)
        DllCall("MultiByteToWideChar", "uint", 65001, "uint", 8, "ptr", ptr, "int", size, "ptr", wide.Ptr, "int", count, "int")
        return Json.Parse(StrGet(wide.Ptr, count, "UTF-16"))
    }

    ; Writes JSON text. indent 0 gives one line, indent n > 0 gives one value per line with n spaces per level.
    ; Map keys are written sorted. Values: String as JSON string, Integer and Float as numbers,
    ; Map and Array as object and array, Json.True and Json.False as true and false, Json.Null as null. Other types throw JsonError.
    static Stringify(value, indent := 0) {
        if (!IsInteger(indent) || indent < 0)
            throw JsonError("indent must be a non-negative integer", ErrCode.BAD_ARGS)
        out := ""
        Json.Emit(value, indent, 0, &out)
        return out
    }

    static Emit(value, indent, level, &out) {
        if (value == Json.Null) {
            out .= "null"
            return
        }
        if (value == Json.True) {
            out .= "true"
            return
        }
        if (value == Json.False) {
            out .= "false"
            return
        }
        t := Type(value)
        if (t = "String")
            out .= Json.Quote(value)
        else if (t = "Integer")
            out .= String(value)
        else if (t = "Float")
            out .= Json.FormatFloat(value)
        else if (value is Map)
            Json.EmitMap(value, indent, level, &out)
        else if (value is Array)
            Json.EmitArray(value, indent, level, &out)
        else
            throw JsonError("cannot write a value of type " t)
    }

    static EmitMap(m, indent, level, &out) {
        keys := Json.SortedKeys(m)
        if (keys.Length = 0) {
            out .= "{}"
            return
        }
        out .= "{"
        for i, key in keys {
            if (i > 1)
                out .= ","
            Json.Newline(indent, level + 1, &out)
            out .= Json.Quote(String(key)) . ((indent > 0) ? ": " : ":")
            Json.Emit(m[key], indent, level + 1, &out)
        }
        Json.Newline(indent, level, &out)
        out .= "}"
    }

    static EmitArray(arr, indent, level, &out) {
        if (arr.Length = 0) {
            out .= "[]"
            return
        }
        out .= "["
        for i, item in arr {
            if (i > 1)
                out .= ","
            Json.Newline(indent, level + 1, &out)
            Json.Emit(item, indent, level + 1, &out)
        }
        Json.Newline(indent, level, &out)
        out .= "]"
    }

    static Newline(indent, level, &out) {
        if (indent <= 0)
            return
        out .= "`n"
        loop indent * level
            out .= " "
    }

    ; Keys in ascending order. Map enumeration is already sorted (verified); the insertion sort
    ; makes the order explicit and does not depend on it.
    static SortedKeys(m) {
        keys := []
        for key, v in m
            keys.Push(key)
        loop keys.Length - 1 {
            i := A_Index + 1
            j := i
            while (j > 1 && Json.Less(keys[j], keys[j - 1])) {
                tmp := keys[j]
                keys[j] := keys[j - 1]
                keys[j - 1] := tmp
                j--
            }
        }
        return keys
    }

    ; Compares by UTF-16 code unit. AHK's < operator converts strings to numbers, so it is not used here.
    static Less(a, b) {
        na := StrLen(a)
        nb := StrLen(b)
        n := (na < nb) ? na : nb
        loop n {
            ca := Ord(SubStr(a, A_Index, 1))
            cb := Ord(SubStr(b, A_Index, 1))
            if (ca != cb)
                return ca < cb
        }
        return na < nb
    }

    ; Returns the JSON string literal for s, with quotes and escapes.
    static Quote(s) {
        if (!RegExMatch(s, '[\x00-\x1F"\\]'))
            return '"' s '"'
        out := '"'
        len := StrLen(s)
        loop len {
            c := SubStr(s, A_Index, 1)
            code := Ord(c)
            if (c = '"')
                out .= '\"'
            else if (c = "\")
                out .= "\\"
            else if (code = 8)
                out .= "\b"
            else if (code = 12)
                out .= "\f"
            else if (code = 10)
                out .= "\n"
            else if (code = 13)
                out .= "\r"
            else if (code = 9)
                out .= "\t"
            else if (code < 0x20)
                out .= "\u00" SubStr("0123456789abcdef", (code >> 4) + 1, 1) SubStr("0123456789abcdef", (code & 0xF) + 1, 1)
            else
                out .= c
        }
        return out '"'
    }

    ; Shortest of 15 or 17 significant digits that reads back as the same Float. A Float always
    ; contains "." or "e", so it reads back as Float and not as Integer.
    static FormatFloat(f) {
        if (f - f != 0)
            throw JsonError("non-finite number cannot be written as JSON")
        s := Format("{:.15g}", f)
        if (Float(s) != f)
            s := Format("{:.17g}", f)
        if (!InStr(s, ".") && !InStr(s, "e") && !InStr(s, "E"))
            s .= ".0"
        return s
    }

    static HexValue(c) {
        if (c >= 0x30 && c <= 0x39)
            return c - 0x30
        if (c >= 0x41 && c <= 0x46)
            return c - 0x37
        if (c >= 0x61 && c <= 0x66)
            return c - 0x57
        return -1
    }
}
