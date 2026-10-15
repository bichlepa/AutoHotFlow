#Requires AutoHotkey v2.0
; Unit tests for the converter of v1 expressions (WI-0039, doc/EXPRESSION-LANGUAGE.md section 15).
; The comparison with the golden data of v1 is tests/golden/test_golden_v2.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\expr\V1ExprConverter.ahk

; Converts and checks status and text; returns the result.
Conv(input, status, expected := "", kind := "expression") {
    res := V1ExprConverter.Convert(input, kind)
    Assert.Equal(res["status"], status, "status of " Show(input))
    Assert.Equal(res["text"], status = "converted" ? expected : input, "text of " Show(input))
    return res
}

; A text with a backtick, written with ~ in the source (a backtick would be an AHK escape there).
B(text) => StrReplace(text, "~", Chr(96))

Show(text) => '"' StrReplace(StrReplace(text, "`n", "``n"), "`r", "``r") '"'

CheckUnchangedTexts() {
    for text in ["", "   ", "x", "x + 1", '"a" . b', "a.b.c", "o[1].x", "a%i%b", "round(2.5)", "1.5 * 2", "0.5", "10",
        "x := 5", "0x1F", "1e3", "true", B('"a~nb"'), '"a;b"', "x `; comment", "5 - -3", "1.0", "0", "100.25"]
        Conv(text, "unchanged")
    Conv("a := 1`nb := 2", "unchanged", , "script")
}

CheckBacktickInStrings() {
    ; v2 does not know these escapes: the backtick goes (v1 dropped it)
    Conv(B('"a~xb"'), "converted", '"axb"')
    Conv(B('"a~1b" . "c~yd"'), "converted", '"a1b" . "cyd"')
    Conv(B('"a~ b"'), "converted", '"a b"')
    ; v2 knows these: they stay (a documented deviation: v1 dropped the backtick)
    for esc in ["n", "r", "t", "b", "v", "a", "f", '"', "'", "``", ";", "%", ",", ":", "{", "}"]
        Conv('"a' Chr(96) esc 'b"', "unchanged")
    ; the escape is case sensitive: `N is not an escape
    Conv(B('"a~Nb"'), "converted", '"aNb"')
    ; outside of a string a backtick is not touched (the parser reports it)
    res := Conv("``n", "failed")
    Assert.True(InStr(res["messages"][1], "escape"))
}

CheckConcatenationDot() {
    Conv('"a"."b"', "converted", '"a" . "b"')
    Conv('"a" ."b"', "converted", '"a" . "b"')
    Conv('"a". "b"', "converted", '"a" . "b"')
    Conv('(1).x', "converted", '(1) . x')
    Conv('a ."b"', "converted", 'a . "b"')
    Conv('"a".1', "converted", '"a" . 1')
    ; a dot that touches a name before it is a member, as in v1
    Conv("a.b", "unchanged")
    Conv("m[1].x", "unchanged")
    Conv("a.1", "unchanged")
    ; a dot inside a string is text
    Conv('"a.b"."c"', "converted", '"a.b" . "c"')
}

CheckNumberLiterals() {
    ; where the text form counts
    Conv("1.50", "converted", '"1.50"')
    Conv("007", "converted", '"007"')
    Conv("0.50", "converted", '"0.50"')
    Conv("5.", "converted", '"5."')
    ; AutoHotkey v2 writes most decimals with 17 digits (0.1 is 0.10000000000000001), v1 passed the spelling on
    Conv("3.14", "converted", '"3.14"')
    Conv("0.1", "converted", '"0.1"')
    Conv("x := 1.10", "converted", 'x := "1.10"')
    Conv("x .= 1.50", "converted", 'x .= "1.50"')
    Conv('"v" . 2.10', "converted", '"v" . "2.10"')
    Conv("round(2.50)", "converted", 'round("2.50")')
    Conv("12345678901234567890", "converted", '"12345678901234567890"')
    ; in a calculation or a comparison it stays a number
    Conv("1.50 + 1", "unchanged")
    Conv("x = 1.50", "unchanged")
    Conv("x < 007", "unchanged")
    Conv("-1.50", "unchanged")
    Conv("o[01]", "unchanged")
    Conv("1.50 and x", "unchanged")
    ; spellings that are already the text form of the value
    Conv("1.5", "unchanged")
    Conv("5.0", "unchanged")
    Conv("0", "unchanged")
    ; hexadecimal and exponent are not decimal literals
    Conv("0x10", "unchanged")
    Conv("1e3", "unchanged")
    ; in a script
    Conv("a := 1.50`nb := 2.0`nc := a + 1.50", "converted", 'a := "1.50"`nb := 2.0`nc := a + 1.50', "script")
}

CheckUnsupportedSyntax() {
    for text in ["7 % 3", "x ^= 2", "x %= 2", "1 <> 2", '"a""b"', "2 ** 3", "1 | 2", "x ? 1 : 2", "x++"] {
        res := V1ExprConverter.Convert(text)
        Assert.Equal(res["status"], "unsupported", "status of " Show(text))
        Assert.Equal(res["text"], text)
        Assert.Equal(res["messages"].Length, 1)
        Assert.True(InStr(res["messages"][1], "unsupported syntax: "), res["messages"][1])
        Assert.True(InStr(res["messages"][1], "line 1"))
    }
    ; in a script the line is reported
    res := V1ExprConverter.Convert("a := 1`nb %= 2", "script")
    Assert.Equal(res["status"], "unsupported")
    Assert.True(InStr(res["messages"][1], "line 2"), res["messages"][1])
}

CheckTextsThatCannotBeRead() {
    for text in ["(", "1 +", "round(", "12abc", "1,000", "x..y", "1 2 )", '"abc'] {
        res := V1ExprConverter.Convert(text)
        Assert.True(res["status"] = "failed" || res["status"] = "unsupported", Show(text) " is " res["status"])
        Assert.Equal(res["text"], text)
        Assert.Equal(res["changes"].Length, 0)
        Assert.Equal(res["messages"].Length, 1)
    }
}

CheckChangesAreListed() {
    res := V1ExprConverter.Convert(B('x := 1.50 . "a"."b" . "c~xd"'))
    Assert.Equal(res["status"], "converted")
    Assert.Equal(res["text"], 'x := "1.50" . "a" . "b" . "cxd"')
    rules := ""
    for ch in res["changes"]
        rules .= ch["rule"] ";"
    Assert.Equal(rules, "concatenation dot;concatenation dot;backtick;number literal spelling;")
    Assert.Equal(res["changes"][4]["old"], "1.50")
    Assert.Equal(res["changes"][4]["new"], '"1.50"')
}

CheckIdempotence() {
    for text in ['"a"."b"', "x := 1.50", '"a`xb"', "5.", "007", 'x := 1.50 . "a"."b"', "round(2.50) . 007"] {
        once := V1ExprConverter.Convert(text)
        twice := V1ExprConverter.Convert(once["text"])
        Assert.Equal(twice["text"], once["text"], Show(text))
        Assert.Equal(twice["status"], "unchanged", Show(text))
    }
}

CheckCommentsAndStrings() {
    ; the content of comments and strings is not scanned
    Conv('x `; "a"."b" 1.50', "unchanged")
    Conv('"1.50"', "unchanged")
    Conv("1.50 `; the price", "converted", '"1.50" `; the price')
    Conv("a := 1.50 `; x`nb := 2", "converted", 'a := "1.50" `; x`nb := 2', "script")
}

CheckKinds() {
    Assert.Throws(() => V1ExprConverter.Convert("x", "bogus"), ValueError)
    ; the same text is an error as an expression and fine as a script
    Assert.Equal(V1ExprConverter.Convert("x := 1`ny := 2")["status"], "failed")
    Assert.Equal(V1ExprConverter.Convert("x := 1`ny := 2", "script")["status"], "unchanged")
}

TestRun.Init()

TestRun.Case("texts that need no change stay as they are", CheckUnchangedTexts)
TestRun.Case("backticks in strings: unknown escapes lose the backtick", CheckBacktickInStrings)
TestRun.Case("the concatenation dot gets spaces", CheckConcatenationDot)
TestRun.Case("number literals become strings where the text form counts", CheckNumberLiterals)
TestRun.Case("unsupported syntax is reported and left unchanged", CheckUnsupportedSyntax)
TestRun.Case("texts that cannot be read stay as they are", CheckTextsThatCannotBeRead)
TestRun.Case("the changes are listed in the order of the text", CheckChangesAreListed)
TestRun.Case("converting twice changes nothing", CheckIdempotence)
TestRun.Case("comments and strings are not scanned", CheckCommentsAndStrings)
TestRun.Case("expression and script form", CheckKinds)

TestRun.Finish()
