#Requires AutoHotkey v2.0
; Unit tests for the syntax check of the expression fields of the settings form (WI-0108, REQ-EDT-200, E0096,
; src/editor/form/FormExpressions.ahk and ElementForm.CheckExpressions): a valid text, an invalid one with its position,
; a script field (V1Syntax), a choice of the content type, the text that is not checked (String), the check that runs
; only when CheckExpressions is called (typing), a text that is not parsed twice, and the text length limit. The test
; element is Test.Action_TestExprParams (tests/elements/Test/Actions/), which has an expression, a choice of the type
; and the parameters that v1 evaluates itself (V1Syntax: Script, Condition). Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\form\ElementForm.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk
#Include ..\elements\Test\_includes_engine.ahk

TestRun.Init()

TestRun.Case("Expr check: a valid expression has no warning", ValidExpressionHasNoWarning)
TestRun.Case("Expr check: an invalid expression is warned with its line and column", InvalidExpressionIsWarned)
TestRun.Case("Expr check: a script field (V1Syntax) is checked with the script parser", ScriptFieldIsChecked)
TestRun.Case("Expr check: an expression that V1Syntax names is checked, a script is not an expression", V1ExpressionKind)
TestRun.Case("Expr check: a choice of the content type decides whether the text is checked", ContentChoiceDecides)
TestRun.Case("Expr check: a String text is not checked", StringIsNotChecked)
TestRun.Case("Expr check: nothing is parsed while typing; the check comes with CheckExpressions", CheckWaitsForCheckExpressions)
TestRun.Case("Expr check: a text that was checked is not parsed again", SameTextIsNotParsedAgain)
TestRun.Case("Expr check: a disabled field is not checked", DisabledFieldIsNotChecked)
TestRun.Case("Expr check: a text longer than the limit is not parsed and the warning says so", LongTextIsNotParsed)
TestRun.Case("Expr check: a warning is not a refusal: the value stays and Result keeps it", WarningKeepsTheValue)
TestRun.Case("Expr check: the warning of the first error counts the others", CountsOtherErrors)

; The field of the form that holds the parameter id.
FieldOf(form, id) {
    for field in form.fields {
        for fieldId in field.ids {
            if (fieldId = id)
                return field
        }
    }
    throw ValueError("no field of " id)
}

; The warnings of one field as the form shows them (texts).
Shown(form, id) => form.FieldWarnings(FieldOf(form, id))

ValidExpressionHasNoWarning() {
    form := ElementForm(Test.Action_TestExprParams, Map("Expr", "1 + 2 * x"))
    Assert.True(form.CheckExpressions(), "the first check changes the warnings")
    Assert.Equal(Shown(form, "Expr").Length, 0, "a valid expression")
    Assert.True(!form.CheckExpressions(), "nothing changed: nothing is reported")
}

InvalidExpressionIsWarned() {
    form := ElementForm(Test.Action_TestExprParams, Map("Expr", "1 + * 2"))
    form.CheckExpressions()
    texts := Shown(form, "Expr")
    Assert.Equal(texts.Length, 1, "one warning")
    Assert.True(InStr(texts[1], "line 1, column 5"), "the position of the '*': " texts[1])
    Assert.True(InStr(texts[1], "unexpected '*'"), "the parser's message: " texts[1])
    ; the form warnings list it under the first id of the field
    found := false
    for warning in form.Warnings() {
        if (warning["id"] = "Expr" && InStr(warning["text"], "column 5"))
            found := true
    }
    Assert.True(found, "Warnings() gives the syntax warning of Expr")
}

ScriptFieldIsChecked() {
    form := ElementForm(Test.Action_TestExprParams, Map("Script", "x := 1`ny := (2"))
    form.CheckExpressions()
    texts := Shown(form, "Script")
    Assert.Equal(texts.Length, 1, "the script is checked: " texts.Length)
    Assert.True(InStr(texts[1], "line 2, column 6"), "the position in the second line: " texts[1])
    form.SetValue("Script", "x := 1`ny := 2")
    form.CheckExpressions()
    Assert.Equal(Shown(form, "Script").Length, 0, "a valid script has no warning")
}

V1ExpressionKind() {
    ; Condition is named "expression" in V1Syntax: a statement is a syntax error there; Script is named "script": two lines are fine
    form := ElementForm(Test.Action_TestExprParams, Map("Condition", "if x", "Script", "x := 1`ny := 2"))
    form.CheckExpressions()
    Assert.Equal(Shown(form, "Condition").Length, 1, "a statement is not an expression")
    Assert.True(InStr(Shown(form, "Condition")[1], "line 1, column 1"), "the statement starts the text")
    Assert.Equal(Shown(form, "Script").Length, 0, "two statements are a valid script")
}

ContentChoiceDecides() {
    form := ElementForm(Test.Action_TestExprParams, Map("Either", "1 +", "EitherType", "string"))
    form.CheckExpressions()
    Assert.Equal(Shown(form, "Either").Length, 0, "a string is not checked")
    form.SetValue("EitherType", "expression")
    form.CheckExpressions()
    Assert.Equal(Shown(form, "Either").Length, 1, "the chosen expression type is checked")
    Assert.True(InStr(Shown(form, "Either")[1], "line 1, column 4"), "the end of the input: " Shown(form, "Either")[1])
}

StringIsNotChecked() {
    form := ElementForm(Test.Action_TestExprParams, Map("Text", "%x% + ((", "Json", "%y%)"))
    form.CheckExpressions()
    Assert.Equal(Shown(form, "Text").Length, 0, "String text: %name% is not expression syntax")
    Assert.Equal(Shown(form, "Json").Length, 0, "String text in a JSON field")
    Assert.True(!form.CheckExpressions(), "nothing is checked, nothing changes")
}

CheckWaitsForCheckExpressions() {
    form := ElementForm(Test.Action_TestExprParams, Map("Expr", "1"))
    form.CheckExpressions()
    form.SetValue("Expr", "1 + * 2")
    Assert.Equal(Shown(form, "Expr").Length, 0, "a text that was typed on is not warned about before the check")
    Assert.True(form.CheckExpressions(), "the check of the typed text")
    Assert.Equal(Shown(form, "Expr").Length, 1, "now it is warned about")
    form.SetValue("Expr", "1 + * 2 ")
    Assert.Equal(Shown(form, "Expr").Length, 0, "a change of the text removes the old warning at once")
    form.SetValue("Expr", "1 + 2")
    form.CheckExpressions()
    Assert.Equal(Shown(form, "Expr").Length, 0, "fixed")
}

SameTextIsNotParsedAgain() {
    form := ElementForm(Test.Action_TestExprParams, Map("Expr", "1 + * 2"))
    form.CheckExpressions()
    form.SetValue("Expr", "1 + * 2")          ; the same text again
    Assert.True(!form.CheckExpressions(), "the same text is not checked again")
    Assert.Equal(Shown(form, "Expr").Length, 1, "its warning stays")
}

DisabledFieldIsNotChecked() {
    form := ElementForm(Test.Action_TestExprParams, Map("Expr", "1 + * 2"))
    form.CheckExpressions()
    Assert.Equal(Shown(form, "Expr").Length, 1, "warned while enabled")
    form.Disable("Expr")
    Assert.Equal(Shown(form, "Expr").Length, 0, "a disabled field has no warning")
    Assert.True(form.CheckExpressions(), "the stored warning is dropped")
    form.Enable("Expr")
    form.CheckExpressions()
    Assert.Equal(Shown(form, "Expr").Length, 1, "enabled again: checked again")
}

LongTextIsNotParsed() {
    text := "1"
    loop 2001
        text .= " + 1"
    Assert.True(StrLen(text) > FormExpressions.MAX_CHARS, "the text is longer than the limit")
    form := ElementForm(Test.Action_TestExprParams, Map("Expr", text))
    form.CheckExpressions()
    texts := Shown(form, "Expr")
    Assert.Equal(texts.Length, 1, "one warning")
    Assert.True(InStr(texts[1], String(FormExpressions.MAX_CHARS)), "the warning names the limit: " texts[1])
}

WarningKeepsTheValue() {
    form := ElementForm(Test.Action_TestExprParams, Map("Expr", "1 + * 2"))
    form.CheckExpressions()
    Assert.Equal(Shown(form, "Expr").Length, 1, "warned")
    Assert.Equal(form.Result()["pars"]["Expr"], "1 + * 2", "the text is kept")
}

CountsOtherErrors() {
    ; the script form goes on after a syntax error (EXPRESSION-LANGUAGE section 10): two bad lines, two errors
    form := ElementForm(Test.Action_TestExprParams, Map("Script", "x := * 1`ny := * 2"))
    form.CheckExpressions()
    texts := Shown(form, "Script")
    Assert.Equal(texts.Length, 1, "one line of warning")
    Assert.True(InStr(texts[1], "line 1, column 6"), "the first error: " texts[1])
    Assert.True(InStr(texts[1], "(1 more)"), "the number of the others: " texts[1])
}

TestRun.Finish()
