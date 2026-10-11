#Requires AutoHotkey v2.0
; Unit tests for src/core/Json.ahk (WI-02).
#Include lib\Assert.ahk
#Include ..\..\src\core\Json.ahk

; Open check of WI-02 (result: YES, the spelling of the first insertion is kept):
; a Map with CaseSense "Off" keeps the key spelling of the first insertion when enumerated,
; and a later insertion of the same key in another case only replaces the value.
; Enumeration of a Map is sorted (zebra, apple, mango come out as apple, mango, zebra).
; So no own AhfMap class is needed. Measured on AHK v2 (2026-10-10).

; Joins lines with "`n", so expected output reads like the real layout.
JsonLines(parts*) {
    out := ""
    for i, p in parts
        out .= ((i > 1) ? "`n" : "") p
    return out
}

; Returns a Buffer with the given bytes.
JsonBytes(bytes*) {
    buf := Buffer(bytes.Length, 0)
    for i, b in bytes
        NumPut("UChar", b, buf, i - 1)
    return buf
}

CheckOpenCheckKeySpelling() {
    m := Map()
    m.CaseSense := "Off"
    m["ElementIDCounter"] := "5"
    m["elementidcounter"] := "6"
    first := ""
    for key, v in m {
        first := key
        break
    }
    Assert.Equal(first, "ElementIDCounter")
    Assert.Equal(m["ELEMENTIDCOUNTER"], "6")
    Assert.Equal(m.Count, 1)
}

CheckOpenCheckEnumerationSorted() {
    m := Map()
    m.CaseSense := "Off"
    m["zebra"] := 1
    m["apple"] := 2
    m["mango"] := 3
    order := ""
    for key, v in m
        order .= key " "
    Assert.Equal(order, "apple mango zebra ")
}

CheckObjectIsMapWithCaseInsensitiveLookup() {
    m := Json.Parse('{"Name":"x"}')
    Assert.True(m is Map)
    Assert.True(m.Has("NAME"))
    Assert.Equal(m["name"], "x")
}

CheckKeySpellingFromSourceAfterStringify() {
    m := Json.Parse('{"ElementIDCounter":"5","zeta":1,"Alpha":2}')
    Assert.Equal(Json.Stringify(m), '{"Alpha":2,"ElementIDCounter":"5","zeta":1}')
}

CheckDuplicateKeyCaseVariantRejected() {
    err := Assert.Throws(() => Json.Parse('{"a":1,"A":2}'), JsonError)
    Assert.True(InStr(err.Message, "duplicate"))
}

CheckExactDuplicateKeyRejected() {
    Assert.Throws(() => Json.Parse('{"a":1,"a":2}'), JsonError)
}

CheckIntegerFromNumberWithoutPoint() {
    arr := Json.Parse("[7, -3, 0]")
    Assert.Equal(Type(arr[1]), "Integer")
    Assert.Equal(arr[1], 7)
    Assert.Equal(Type(arr[2]), "Integer")
    Assert.Equal(arr[2], -3)
    Assert.Equal(arr[3], 0)
}

CheckFloatFromNumberWithPointOrExponent() {
    arr := Json.Parse("[1.0, 0.5, 1e3, -2.5E-2]")
    for v in arr
        Assert.Equal(Type(v), "Float")
    Assert.True(arr[3] = 1000)
    Assert.True(arr[4] = -0.025)
}

CheckStringStaysStringEvenIfNumeric() {
    m := Json.Parse('{"zoomFactor":"0.700000","ElementIDCounter":"5"}')
    Assert.Equal(Type(m["zoomFactor"]), "String")
    Assert.Equal(m["zoomFactor"], "0.700000")
    Assert.Equal(Type(m["ElementIDCounter"]), "String")
}

CheckTrueFalseNull() {
    arr := Json.Parse("[true, false, null]")
    Assert.Equal(arr[1], 1)
    Assert.Equal(Type(arr[1]), "Integer")
    Assert.Equal(arr[2], 0)
    Assert.True(arr[3] == Json.Null)
}

CheckStringifyKeepsTypesApart() {
    m := Map("a", "1", "b", 1, "c", 1.5)
    Assert.Equal(Json.Stringify(m), '{"a":"1","b":1,"c":1.5}')
}

CheckFloatOneKeepsPoint() {
    Assert.Equal(Json.Stringify(1.0), "1.0")
    Assert.Equal(Type(Json.Parse(Json.Stringify(1.0))), "Float")
}

CheckFloatFullPrecisionRoundTrip() {
    x := 1 / 3
    Assert.True(Json.Parse(Json.Stringify(x)) == x)
    y := 0.1 + 0.2
    Assert.True(Json.Parse(Json.Stringify(y)) == y)
    Assert.Equal(Json.Stringify(0.7), "0.7")
}

CheckNonFiniteFloatRejected() {
    Assert.Throws(() => Json.Stringify(Float("1e400")), JsonError)
}

CheckUnsupportedTypeRejected() {
    Assert.Throws(() => Json.Stringify(Object()), JsonError)
}

CheckNegativeIndentRejected() {
    Assert.Throws(() => Json.Stringify(1, -1), JsonError)
}

CheckIndentTwoLayoutLikeV1() {
    m := Json.Parse('{"b":[1,{"x":"y"}],"a":{},"c":[]}')
    expected := JsonLines(
        "{",
        '  "a": {},',
        '  "b": [',
        "    1,",
        "    {",
        '      "x": "y"',
        "    }",
        "  ],",
        '  "c": []',
        "}")
    Assert.Equal(Json.Stringify(m, 2), expected)
}

CheckEmptyContainersInCompactOutput() {
    Assert.Equal(Json.Stringify(Map()), "{}")
    Assert.Equal(Json.Stringify(Array()), "[]")
    Assert.Equal(Json.Stringify(Json.Null), "null")
}

CheckControlCharactersAreEscaped() {
    s := "a" Chr(1) "b" Chr(10) Chr(9) '"' "\" Chr(8) Chr(12) Chr(13)
    expected := '"a\u0001b\n\t\"\\\b\f\r"'
    Assert.Equal(Json.Stringify(s), expected)
    Assert.Equal(Json.Parse(Json.Stringify(s)), s)
}

CheckEscapesParseBack() {
    v := Json.Parse('"\/\b\f\n\r\t\"\\"')
    expected := "/" Chr(8) Chr(12) "`n" "`r" "`t" '"' "\"
    Assert.Equal(v, expected)
}

CheckUnicodeEscapeBecomesCharacter() {
    Assert.Equal(Json.Parse('"é"'), Chr(0xE9))
    Assert.Equal(Json.Parse('"é"'), Chr(0xE9))
}

CheckSurrogatePairBecomesOneCharacter() {
    v := Json.Parse('"𝄞"')
    Assert.Equal(v, Chr(0xD834) Chr(0xDD1E))
    Assert.Equal(StrLen(v), 2)
    Assert.Equal(Json.Stringify(v), '"' Chr(0xD834) Chr(0xDD1E) '"')
}

CheckNonAsciiWrittenRaw() {
    Assert.Equal(Json.Stringify(Chr(0xE9)), '"' Chr(0xE9) '"')
}

CheckLoneSurrogateRejected() {
    Assert.Throws(() => Json.Parse('"\uD834"'), JsonError)
    Assert.Throws(() => Json.Parse('"\uDD1E"'), JsonError)
    Assert.Throws(() => Json.Parse('"\uD834A"'), JsonError)
}

CheckUnknownEscapeRejected() {
    err := Assert.Throws(() => Json.Parse('"\x"'), JsonError)
    Assert.True(InStr(err.Message, "escape"))
}

CheckInvalidHexRejected() {
    Assert.Throws(() => Json.Parse('"\u00G1"'), JsonError)
}

CheckTruncatedRejected() {
    Assert.Throws(() => Json.Parse('{"a":1'), JsonError)
    Assert.Throws(() => Json.Parse("[1,2"), JsonError)
    Assert.Throws(() => Json.Parse('"abc'), JsonError)
    Assert.Throws(() => Json.Parse('{"a":'), JsonError)
}

CheckDoubledCommaRejected() {
    Assert.Throws(() => Json.Parse("[1,,2]"), JsonError)
    Assert.Throws(() => Json.Parse('{"a":1,,"b":2}'), JsonError)
}

CheckTrailingCommaRejected() {
    Assert.Throws(() => Json.Parse("[1,]"), JsonError)
    Assert.Throws(() => Json.Parse('{"a":1,}'), JsonError)
}

CheckLeadingZeroRejected() {
    Assert.Throws(() => Json.Parse("[01]"), JsonError)
    Assert.Throws(() => Json.Parse("[1.]"), JsonError)
    Assert.Throws(() => Json.Parse("[+1]"), JsonError)
}

CheckTextAfterValueRejected() {
    Assert.Throws(() => Json.Parse("{} x"), JsonError)
}

CheckEmptyTextRejected() {
    Assert.Throws(() => Json.Parse(""), JsonError)
    Assert.Throws(() => Json.Parse("   "), JsonError)
}

CheckRawControlCharacterRejected() {
    Assert.Throws(() => Json.Parse('"a' Chr(10) '"'), JsonError)
}

CheckInvalidLiteralRejected() {
    Assert.Throws(() => Json.Parse("[tru]"), JsonError)
    Assert.Throws(() => Json.Parse("[True]"), JsonError)
}

CheckErrorNamesLineAndColumn() {
    err := Assert.Throws(() => Json.Parse("{`n  " '"a": ,' "`n}"), JsonError)
    Assert.True(InStr(err.Message, "line 2"))
    Assert.True(InStr(err.Message, "column"))
}

CheckDeepNestingRejected() {
    text := ""
    loop 300
        text .= "["
    Assert.Throws(() => Json.Parse(text), JsonError)
}

CheckInvalidUtf8BytesRejected() {
    buf := JsonBytes(0x22, 0xC3, 0x28, 0x22)
    Assert.Throws(() => Json.ParseBytes(buf), JsonError)
}

CheckUtf8BytesWithBomAccepted() {
    buf := JsonBytes(0xEF, 0xBB, 0xBF, 0x22, 0xC3, 0xA9, 0x22)
    Assert.Equal(Json.ParseBytes(buf), Chr(0xE9))
}

CheckUtf8BytesWithoutBom() {
    buf := JsonBytes(0x7B, 0x22, 0x61, 0x22, 0x3A, 0x31, 0x7D)
    m := Json.ParseBytes(buf)
    Assert.Equal(m["a"], 1)
}

CheckEmptyBytesRejected() {
    Assert.Throws(() => Json.ParseBytes(Buffer(0)), JsonError)
}

CheckIntegerBeyond18DigitsBecomesFloat() {
    Assert.Equal(Type(Json.Parse("12345678901234567890")), "Float")
    Assert.Equal(Type(Json.Parse("123456789012345678")), "Integer")
}

CheckNullSingleton() {
    Assert.True(Json.Null == Json.Null)
    Assert.True(Json.Parse("null") == Json.Null)
    Assert.Equal(Type(Json.Null), "Json.NullValue")
}

CheckNestedRoundTripIsStructurallyEqual() {
    text := '{"n":{"Deep":[1,2.5,"3",{"k":"vé"}]},"e":"0.700000"}'
    first := Json.Parse(text)
    second := Json.Parse(Json.Stringify(first, 2))
    Assert.Equal(Json.Stringify(second), Json.Stringify(first))
    Assert.Equal(Type(second["e"]), "String")
    Assert.Equal(Type(second["n"]["deep"][2]), "Float")
    Assert.Equal(Type(second["n"]["deep"][3]), "String")
}

TestRun.Init()

CheckBoolWritesTrueFalse() {
    Assert.Equal(Json.Stringify(Json.True), "true")
    Assert.Equal(Json.Stringify(Json.False), "false")
    m := Map("a", Json.True, "b", Json.False, "c", [Json.True, Json.False, 1, 0])
    Assert.Equal(Json.Stringify(m), '{"a":true,"b":false,"c":[true,false,1,0]}')
}

CheckBoolReadsAsOneAndZero() {
    ; Reading stays 1/0 on purpose: AHK has no Bool type and `if x` must work (doc/PROTOKOLL.md section 2).
    m := Json.Parse('{"a":true,"b":false}')
    Assert.Equal(m["a"], 1)
    Assert.Equal(Type(m["a"]), "Integer")
    Assert.Equal(m["b"], 0)
    Assert.True(!m["b"])
}

CheckBoolRoundTripIsNotTypePreserving() {
    back := Json.Parse(Json.Stringify(Map("a", Json.True, "b", Json.False)))
    Assert.Equal(back["a"], 1)
    Assert.Equal(back["b"], 0)
    Assert.Equal(Json.Stringify(back), '{"a":1,"b":0}')
}

CheckBoolConversion() {
    Assert.True(Json.Bool(1) == Json.True)
    Assert.True(Json.Bool(0) == Json.False)
    Assert.True(Json.Bool("") == Json.False)
    Assert.True(Json.Bool("0") == Json.False)
    Assert.True(Json.Bool("x") == Json.True)
    Assert.True(Json.Bool(5) == Json.True)
    Assert.True(Json.Bool(Map()) == Json.True)
    Assert.True(Json.Bool(Json.False) == Json.False)
    Assert.True(Json.Bool(Json.True) == Json.True)
}

CheckBoolSingletonsAreDistinctFromNull() {
    Assert.True(!(Json.True == Json.False))
    Assert.True(!(Json.True == Json.Null))
    Assert.True(!(Json.False == Json.Null))
    ; The trap: Json.False is an object, so AHK counts it as true.
    Assert.True(Json.False ? true : false)
}

TestRun.Case("Map CaseSense Off keeps the first spelling of a key", CheckOpenCheckKeySpelling)
TestRun.Case("Map CaseSense Off enumerates keys in sorted order", CheckOpenCheckEnumerationSorted)
TestRun.Case("object becomes Map with case-insensitive lookup", CheckObjectIsMapWithCaseInsensitiveLookup)
TestRun.Case("key spelling survives Parse and Stringify", CheckKeySpellingFromSourceAfterStringify)
TestRun.Case("duplicate key differing only in case is rejected", CheckDuplicateKeyCaseVariantRejected)
TestRun.Case("exact duplicate key is rejected", CheckExactDuplicateKeyRejected)
TestRun.Case("number without point or exponent is Integer", CheckIntegerFromNumberWithoutPoint)
TestRun.Case("number with point or exponent is Float", CheckFloatFromNumberWithPointOrExponent)
TestRun.Case("JSON string stays String even if it looks numeric", CheckStringStaysStringEvenIfNumeric)
TestRun.Case("true and false become 1 and 0, null becomes Json.Null", CheckTrueFalseNull)
TestRun.Case("Stringify keeps String, Integer and Float apart", CheckStringifyKeepsTypesApart)
TestRun.Case("Float 1.0 is written with a point", CheckFloatOneKeepsPoint)
TestRun.Case("Float keeps full precision on round trip", CheckFloatFullPrecisionRoundTrip)
TestRun.Case("non-finite Float cannot be written", CheckNonFiniteFloatRejected)
TestRun.Case("unsupported type cannot be written", CheckUnsupportedTypeRejected)
TestRun.Case("negative indent is rejected", CheckNegativeIndentRejected)
TestRun.Case("indent 2 gives the v1 layout", CheckIndentTwoLayoutLikeV1)
TestRun.Case("empty containers and null in compact output", CheckEmptyContainersInCompactOutput)
TestRun.Case("control characters are escaped on output", CheckControlCharactersAreEscaped)
TestRun.Case("escape sequences parse to the right characters", CheckEscapesParseBack)
TestRun.Case("unicode escape becomes the character", CheckUnicodeEscapeBecomesCharacter)
TestRun.Case("surrogate pair becomes one character", CheckSurrogatePairBecomesOneCharacter)
TestRun.Case("non-ASCII characters are written raw", CheckNonAsciiWrittenRaw)
TestRun.Case("lone surrogate is rejected", CheckLoneSurrogateRejected)
TestRun.Case("unknown escape sequence is rejected", CheckUnknownEscapeRejected)
TestRun.Case("invalid hex digit in unicode escape is rejected", CheckInvalidHexRejected)
TestRun.Case("truncated text is rejected", CheckTruncatedRejected)
TestRun.Case("doubled comma is rejected", CheckDoubledCommaRejected)
TestRun.Case("trailing comma is rejected", CheckTrailingCommaRejected)
TestRun.Case("leading zero and bad fraction are rejected", CheckLeadingZeroRejected)
TestRun.Case("text after the value is rejected", CheckTextAfterValueRejected)
TestRun.Case("empty text is rejected", CheckEmptyTextRejected)
TestRun.Case("raw control character in string is rejected", CheckRawControlCharacterRejected)
TestRun.Case("invalid literal is rejected", CheckInvalidLiteralRejected)
TestRun.Case("error message names line and column", CheckErrorNamesLineAndColumn)
TestRun.Case("nesting deeper than the limit is rejected", CheckDeepNestingRejected)
TestRun.Case("invalid UTF-8 bytes are rejected", CheckInvalidUtf8BytesRejected)
TestRun.Case("UTF-8 bytes with BOM are accepted", CheckUtf8BytesWithBomAccepted)
TestRun.Case("UTF-8 bytes without BOM are read", CheckUtf8BytesWithoutBom)
TestRun.Case("empty bytes are rejected", CheckEmptyBytesRejected)
TestRun.Case("integer beyond 18 digits becomes Float", CheckIntegerBeyond18DigitsBecomesFloat)
TestRun.Case("Json.Null is a singleton", CheckNullSingleton)
TestRun.Case("nested round trip keeps structure and types", CheckNestedRoundTripIsStructurallyEqual)

TestRun.Case("Json.True and Json.False are written as true and false", CheckBoolWritesTrueFalse)
TestRun.Case("true and false are read as 1 and 0", CheckBoolReadsAsOneAndZero)
TestRun.Case("boolean round trip is not type preserving", CheckBoolRoundTripIsNotTypePreserving)
TestRun.Case("Json.Bool converts 0, 1, empty, '0' and objects", CheckBoolConversion)
TestRun.Case("Json.True and Json.False are distinct singletons", CheckBoolSingletonsAreDistinctFromNull)

TestRun.Finish()
