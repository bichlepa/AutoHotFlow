#Requires AutoHotkey v2.0
; Unit tests for the literals, names and keywords of the expression language (WI-0037, doc/EXPRESSION-LANGUAGE.md sections 2 and 3).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\ExprCheck.ahk

; The first node of a parsed expression.
Ast(text) {
    res := ExprCheck.Parse(text)
    if (!res["ok"])
        throw AssertFailed("should parse: " Expr.FormatErrors(res))
    return res["ast"]
}

CheckIntegers() {
    n := Ast("42")
    Assert.Equal(n["type"], "Number")
    Assert.Equal(n["value"], 42)
    Assert.Equal(n["text"], "42")
    Assert.Equal(Ast("0")["value"], 0)
    Assert.Equal(Ast("007")["value"], 7)
    Assert.Equal(Ast("007")["text"], "007")
    Assert.Equal(Ast("9223372036854775807")["value"], 9223372036854775807)
}

CheckHex() {
    Assert.Equal(Ast("0x10")["value"], 16)
    Assert.Equal(Ast("0xFF")["value"], 255)
    Assert.Equal(Ast("0Xff")["value"], 255)
    Assert.Equal(Ast("0x7FFFFFFFFFFFFFFF")["value"], 9223372036854775807)
    Assert.Equal(Ast("0x00000000000000001")["value"], 1)
}

CheckFloats() {
    Assert.Equal(Ast("0.5")["value"], 0.5)
    Assert.Equal(Ast("1.50")["value"], 1.5)
    Assert.Equal(Ast("1.50")["text"], "1.50")
    Assert.Equal(Ast(".5")["value"], 0.5)
    Assert.Equal(Ast("1e3")["value"], 1000.0)
    Assert.Equal(Ast("1E3")["value"], 1000.0)
    Assert.Equal(Ast("1.5e-3")["value"], 0.0015)
    Assert.Equal(Ast("2E+2")["value"], 200.0)
    Assert.Equal(Ast("7.0")["value"], 7.0)
}

CheckBigIntegerBecomesFloat() {
    n := Ast("12345678901234567890")
    Assert.Equal(Type(n["value"]), "Float")
    Assert.Equal(Type(Ast("9223372036854775808")["value"]), "Float")
    Assert.Equal(Type(Ast("9223372036854775807")["value"]), "Integer")
    Assert.Equal(Type(Ast("00000000000000000000000001")["value"]), "Integer")
}

CheckBadNumbers() {
    ExprCheck.ErrorTable([
        ["12abc", 1, 1, "invalid number"],
        ["1x", 1, 1, "invalid number"],
        ["1_000", 1, 1, "invalid number"],
        ["1.2.3", 1, 1, "invalid number"],
        ["0x", 1, 1, "invalid number"],
        ["0xG", 1, 1, "invalid number"],
        ["1e", 1, 1, "invalid number"],
        ["0xFFFFFFFFFFFFFFFF", 1, 1, "too large"],
        ["0x8000000000000000", 1, 1, "too large"],
        ["0x1FFFFFFFFFFFFFFFF", 1, 1, "too large"],
        ["5.", 1, 2, "needs a space"],
        ["1,000", 1, 2, "unexpected ','"],
    ])
}

CheckKeywordsTrueFalse() {
    n := Ast("true")
    Assert.Equal(n["type"], "Number")
    Assert.Equal(n["value"], 1)
    Assert.Equal(n["text"], "true")
    Assert.Equal(Ast("FALSE")["value"], 0)
    Assert.Equal(Ast("False")["text"], "False")
}

CheckStringBasics() {
    Assert.Equal(Ast('"abc"')["value"], "abc")
    Assert.Equal(Ast('""')["value"], "")
    Assert.Equal(Ast("''")["value"], "")
    Assert.Equal(Ast("'abc'")["value"], "abc")
    Assert.Equal(Ast('"it' "'" 's"')["value"], "it's")
    Assert.Equal(Ast("'say " '"hi"' "'")["value"], 'say "hi"')
    Assert.Equal(Ast('"  a  "')["value"], "  a  ")
    Assert.Equal(Ast('"a;b"')["value"], "a;b")
    Assert.Equal(Ast('"a `;b"')["value"], "a `;b")
    Assert.Equal(Ast('"%x%"')["value"], "%x%")
    Assert.Equal(Ast('"50%"')["value"], "50%")
    Assert.Equal(Ast('"\n"')["value"], "\n")
    Assert.Equal(Ast('"C:\Users\x"')["value"], "C:\Users\x")
    Assert.Equal(Ast('"{ } ( ) [ ]"')["value"], "{ } ( ) [ ]")
}

CheckStringEscapes() {
    Assert.Equal(Ast('"a``nb"')["value"], "a`nb")
    Assert.Equal(Ast('"a``tb"')["value"], "a`tb")
    Assert.Equal(Ast('"a``rb"')["value"], "a`rb")
    Assert.Equal(Ast('"a``bb"')["value"], "a" Chr(8) "b")
    Assert.Equal(Ast('"a``vb"')["value"], "a" Chr(11) "b")
    Assert.Equal(Ast('"a``ab"')["value"], "a" Chr(7) "b")
    Assert.Equal(Ast('"a``fb"')["value"], "a" Chr(12) "b")
    Assert.Equal(Ast('"a```"b"')["value"], 'a"b')
    Assert.Equal(Ast("'a```'b'")["value"], "a'b")
    Assert.Equal(Ast('"a````b"')["value"], "a``b")
    Assert.Equal(Ast('"a``;b"')["value"], "a;b")
    Assert.Equal(Ast('"a``%b"')["value"], "a%b")
    Assert.Equal(Ast('"a``,b"')["value"], "a,b")
    Assert.Equal(Ast('"a``:b"')["value"], "a:b")
    Assert.Equal(Ast('"a``{b"')["value"], "a{b")
    Assert.Equal(Ast('"a``}b"')["value"], "a}b")
    ; a quote of the other kind needs no escape, an escaped one is fine too
    Assert.Equal(Ast('"a``' "'" 'b"')["value"], "a'b")
}

CheckEscapeIsCaseSensitive() {
    ; `N is not `n
    ExprCheck.ErrorTable([['"a``Nb"', 1, 3, "unknown escape"]])
}

CheckBadEscapes() {
    ExprCheck.ErrorTable([
        ['"a``xb"', 1, 3, "unknown escape sequence ``x"],
        ['"a``1b"', 1, 3, "unknown escape sequence ``1"],
        ['"a`` b"', 1, 3, "unknown escape"],
        ['"a``0b"', 1, 3, "unknown escape"],
        ['"a``😀b" + )', 1, 3, "unknown escape sequence ``😀"],
    ])
}

CheckUnclosedStrings() {
    ExprCheck.ErrorTable([
        ['"abc', 1, 1, "not closed"],
        ["'abc", 1, 1, "not closed"],
        ['"abc``', 1, 1, "not closed"],
        ['"a``"', 1, 1, "not closed"],
        ['x := "abc', 1, 6, "not closed"],
        ['"', 1, 1, "not closed"],
    ])
    ; a line break ends the string with an error
    res := ExprCheck.Fails('"a`nb"')
    Assert.Equal(res["errors"][1]["line"], 1)
    Assert.Equal(res["errors"][1]["message"], "the string is not closed")
}

CheckDoubledQuotes() {
    ; v1 wrote a quote in a string as "": two strings that touch are an error, with a hint
    ExprCheck.ErrorTable([
        ['"a""b"', 1, 4, "two string literals"],
        ['""""', 1, 3, "two string literals"],
        ["'a''b'", 1, 4, "two string literals"],
    ])
    ; a space between them is a normal concatenation
    Assert.Equal(ExprCheck.Sexp('"a" "b"'), '(. "a" "b")')
}

CheckUnicodeInStrings() {
    Assert.Equal(Ast('"ä ö ü ß €"')["value"], "ä ö ü ß €")
    Assert.Equal(Ast('"😀"')["value"], "😀")
    Assert.Equal(Ast("'Привет'")["value"], "Привет")
    n := Ast('"😀x"')
    Assert.Equal(n["end"] - n["pos"], 5)  ; columns count UTF-16 code units: the emoji has two
}

CheckUnicodeInNames() {
    Assert.Equal(ExprCheck.Sexp("größe + 1"), "(+ größe 1)")
    Assert.Equal(ExprCheck.Sexp("ä"), "ä")
    Assert.Equal(ExprCheck.Sexp("Привет.мир"), '(mem Привет "мир")')
    Assert.Equal(ExprCheck.Sexp("x😀"), "x😀")
}

CheckNamesAreKept() {
    Assert.Equal(Ast("_a")["name"], "_a")
    Assert.Equal(Ast("A_Index")["name"], "A_Index")
    Assert.Equal(Ast("global_x")["name"], "global_x")
    Assert.Equal(Ast("ABC")["name"], "ABC")
    Assert.Equal(Ast("abc")["name"], "abc")
    Assert.Equal(Ast("x1")["name"], "x1")
    Assert.Equal(Ast("  x  ")["name"], "x")
}

CheckNameRulesLikeV1() {
    ; same answers as v1 Var_CheckName(name, true) for the golden cases
    Assert.Equal(ExprNames.Check("abc"), "OK")
    Assert.Equal(ExprNames.Check(""), "Empty")
    Assert.Equal(ExprNames.Check("1abc"), "StartsWithNumber")
    Assert.Equal(ExprNames.Check("0"), "StartsWithNumber")
    Assert.Equal(ExprNames.Check("1.5"), "StartsWithNumber")
    for name in ["-1", "a b", " a", "a ", "a.b", "a-b", "a,b", "a;b", "a:b", "a[1]", "a?b", "a(b", 'a"b', "a%b",
        "a``b", "a`nb", "a`tb", "a+b", "a=b", "a*b", "a/b", "a\b", "a<b", "a&b", "a|b", "a^b", "a~b", "a!b", "a{b"]
        Assert.Equal(ExprNames.Check(name), "ForbiddenCharacter", "name " name)
    for name in ["ä", "_x", "x1", "A_x", "global_x", "a@b", "$x", "a#b", "😀", "if", "true", "A_Index", "x", "٣a"]
        Assert.Equal(ExprNames.Check(name), "OK", "name " name)
    n253 := StrReplace(Format("{:253}", ""), " ", "x")
    Assert.Equal(ExprNames.Check(n253), "OK")
    Assert.Equal(ExprNames.Check(n253 "x"), "ForbiddenCharacter")
    Assert.True(ExprNames.IsValid("abc"))
    Assert.True(!ExprNames.IsValid("a b"))
    Assert.Equal(Expr.CheckName("1x"), "StartsWithNumber")
}

CheckKeywordsAreCaseInsensitive() {
    Assert.Equal(ExprCheck.Sexp("1 AND 0"), "(&& 1 0)")
    Assert.Equal(ExprCheck.Sexp("0 Or 1"), "(|| 0 1)")
    Assert.Equal(ExprCheck.Sexp("NOT 1"), "(! 1)")
    Assert.Equal(ExprNames.Keyword("And"), "and")
    Assert.Equal(ExprNames.Keyword("andy"), "")
    Assert.Equal(ExprNames.Keyword("true"), "true")
}

CheckKeywordLookalikesAreNames() {
    ; a word that only starts like a keyword is a name
    Assert.Equal(ExprCheck.Sexp("andy"), "andy")
    Assert.Equal(ExprCheck.Sexp("ory or notx"), "(|| ory notx)")
    Assert.Equal(ExprCheck.Sexp("iffy"), "iffy")
    Assert.Equal(ExprCheck.Sexp("elsewhere"), "elsewhere")
    Assert.Equal(ExprCheck.Sexp("trueish"), "trueish")
    Assert.Equal(ExprCheck.Sexp("a.and"), '(mem a "and")')   ; after a dot a keyword is a plain name
    Assert.Equal(ExprCheck.Sexp("a.if.true"), '(mem (mem a "if") "true")')
}

CheckKeywordsAreNotNames() {
    ExprCheck.ErrorTable([
        ["and", 1, 1, "unexpected 'and'"],
        ["or", 1, 1, "unexpected 'or'"],
        ["1 and or 2", 1, 7, "unexpected 'or'"],
        ["if", 1, 1, "'if' is only valid"],
        ["else", 1, 1, "'else' is only valid"],
        ["x := if", 1, 6, "'if' is only valid"],
    ])
}

CheckCommentsAndWhitespace() {
    Assert.Equal(ExprCheck.Sexp("1 `; comment"), "1")
    Assert.Equal(ExprCheck.Sexp("1`t`; comment"), "1")
    Assert.Equal(ExprCheck.Sexp("; only a comment"), "(empty)")
    Assert.Equal(ExprCheck.Sexp("  `t  "), "(empty)")
    Assert.Equal(ExprCheck.Sexp(""), "(empty)")
    Assert.Equal(ExprCheck.Sexp("`n"), "(empty)")
    Assert.Equal(ExprCheck.Sexp("1`r`n+`r`n2"), "(+ 1 2)")
    Assert.Equal(ExprCheck.Sexp("1 +`n 2 `; c`n + 3"), "(+ (+ 1 2) 3)")
    ; a semicolon needs whitespace before it (AutoHotkey rule); inside a string it is text
    ExprCheck.ErrorTable([["1;x", 1, 2, "comment must be preceded"]])
}

CheckBadCharacters() {
    ExprCheck.ErrorTable([
        ["$x", 1, 1, "unexpected character '$'"],
        ["@", 1, 1, "unexpected character '@'"],
        ["#", 1, 1, "unexpected character '#'"],
        ["``", 1, 1, "escape character"],
        ["\", 1, 1, "unexpected character"],
        ["a ``n", 1, 3, "escape character"],
    ])
}

TestRun.Init()

TestRun.Case("integer literals keep value and spelling", CheckIntegers)
TestRun.Case("hexadecimal literals", CheckHex)
TestRun.Case("float literals and exponents", CheckFloats)
TestRun.Case("an integer literal beyond 63 bits becomes a Float", CheckBigIntegerBecomesFloat)
TestRun.Case("malformed numbers are errors", CheckBadNumbers)
TestRun.Case("true and false are the numbers 1 and 0", CheckKeywordsTrueFalse)
TestRun.Case("strings in double and single quotes", CheckStringBasics)
TestRun.Case("escape sequences with the backtick", CheckStringEscapes)
TestRun.Case("escape letters are case sensitive", CheckEscapeIsCaseSensitive)
TestRun.Case("unknown escape sequences are errors", CheckBadEscapes)
TestRun.Case("unclosed strings are errors", CheckUnclosedStrings)
TestRun.Case("doubled quotes are an error with a hint", CheckDoubledQuotes)
TestRun.Case("Unicode in strings", CheckUnicodeInStrings)
TestRun.Case("Unicode in names", CheckUnicodeInNames)
TestRun.Case("names keep their spelling", CheckNamesAreKept)
TestRun.Case("name rules give the answers of v1 Var_CheckName", CheckNameRulesLikeV1)
TestRun.Case("keywords ignore case", CheckKeywordsAreCaseInsensitive)
TestRun.Case("words that start like a keyword are names", CheckKeywordLookalikesAreNames)
TestRun.Case("keywords cannot be used as names", CheckKeywordsAreNotNames)
TestRun.Case("comments, whitespace and empty input", CheckCommentsAndWhitespace)
TestRun.Case("characters outside the language are errors", CheckBadCharacters)

TestRun.Finish()
