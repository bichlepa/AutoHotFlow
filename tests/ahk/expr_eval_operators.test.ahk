#Requires AutoHotkey v2.0
; Unit tests for the operators of the evaluator and the rules E0025, E0029 to E0032 (WI-0038, doc/EXPRESSION-LANGUAGE.md
; sections 5 and 14). The values of the table "Behavior of AHK v2" of the phase 3 plan are the cross-check.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\EvalCheck.ahk

CheckArithmetic() {
    EvalCheck.Table([
        ["1 + 2", 3],
        ["10 - 4 - 3", 3],
        ["6 * 7", 42],
        ["2 + 3 * 4", 14],
        ["(2 + 3) * 4", 20],
        ["0.5 + 0.25", 0.75],
        ["1.5 * 2", 3.0],
        ["-5", -5],
        ["- -5", 5],
        ["-(2 + 3)", -5],
        ["5 - -3", 8],
        ["007 + 1", 8],
        ["0x1F + 1", 32],
        ["1e3 + 0", 1000.0],
        ["true + true", 2],
        ["9223372036854775807 + 1", -9223372036854775807 - 1],
    ])
}

CheckNumericStrings() {
    ; AutoHotkey v2: a text that looks like a number is a number
    EvalCheck.Table([
        ['"5" + 1', 6],
        ['" 5 " + 1', 6],
        ['"0x10" + 0', 16],
        ['"1e3" + 0', 1000.0],
        ['"2.5" * 2', 5.0],
        ['-"5"', -5],
    ])
}

CheckTypeErrorsGiveEmptyText() {
    ; E0025: AutoHotkey throws a TypeError, the evaluator turns it into "", a warning and an f1 log entry
    EvalCheck.Warns('"" + 1', "'+' failed")
    EvalCheck.Warns('"abc" + 1', "'+' failed")
    EvalCheck.Warns('1 - "x"', "'-' failed")
    EvalCheck.Warns('"x" * 2', "'*' failed")
    EvalCheck.Warns('-""', "'-' failed")
    EvalCheck.Warns('-"abc"', "'-' failed")
    EvalCheck.Warns('object() + 1', "'+' failed")
    EvalCheck.Warns('object() . "x"', "'.' failed")
}

CheckWarningHasPosition() {
    res := EvalCheck.Warns('"" . (2 + "")', "'+' failed")
    w := res["warnings"][1]
    Assert.Equal(w["line"], 1)
    Assert.Equal(w["col"], 6)
    Assert.Equal(w["pos"], 6)
    Assert.Equal(w["length"], 8)
    Assert.Equal(w["marked"], "`"`" . -> (2 + `"`") <-")
    res := EvalCheck.Warns("x := 1`n`ny := 1 + `"`"", "'+' failed", "", "script")
    Assert.Equal(res["warnings"][1]["line"], 3)
    Assert.Equal(res["warnings"][1]["col"], 6)
}

CheckEvaluationContinuesAfterWarning() {
    ; the failed part is "", the rest is calculated
    res := EvalCheck.Run('("" + 1) . "x" . (2 + 3)')
    Assert.Equal(res["value"], "x5")
    Assert.Equal(res["warnings"].Length, 1)
    res := EvalCheck.Run('("" + 1) + ("a" + 1)')
    Assert.Equal(res["warnings"].Length, 3)
}

CheckDivisionRuleE29() {
    ; exact division of two integers gives an Integer; AutoHotkey itself would give 2.0
    EvalCheck.Table([
        ["4/2", 2],
        ["-8/-2", 4],
        ["-8/2", -4],
        ["8/-2", -4],
        ["0/5", 0],
        ["6/-1", -6],
        ["100/10/5", 2],
        ["7/2", 3.5],
        ["1/4", 0.25],
        ["-7/2", -3.5],
        ["4.0/2", 2.0],
        ["4/2.0", 2.0],
        ["4.5/1.5", 3.0],
        ['"4"/"2"', 2],
        ['" 4 "/2', 2],
        ['"0x10"/2', 8],
        ['"4.0"/2', 2.0],
        ["9223372036854775807/1", 9223372036854775807],
    ])
    ; the type matters for the text form
    EvalCheck.TextTable([
        ["4/2", "2"],
        ["4.0/2", "2.0"],
        ["7/2", "3.5"],
    ])
    ; MinInt / -1 does not fit; AutoHotkey gives a Float. The calculation must not end the process.
    res := EvalCheck.Run("(0 - 9223372036854775807 - 1) / -1")
    Assert.True(res["value"] is Float)
    Assert.Equal(res["warnings"].Length, 0)
}

CheckDivisionByZero() {
    EvalCheck.Warns("1/0", "'/' failed")
    EvalCheck.Warns("0/0", "'/' failed")
    EvalCheck.Warns("1.5/0", "'/' failed")
    EvalCheck.Warns("1//0", "'//' failed")
    EvalCheck.Warns("1/(2-2)", "'/' failed")
    EvalCheck.Warns("mod(1, 0)", "'mod' failed")
}

CheckIntegerDivision() {
    EvalCheck.Table([
        ["7//2", 3],
        ["-7//2", -3],
        ["7//-2", -3],
        ["8//2", 4],
        ['"7"//2', 3],
        ["0//3", 0],
    ])
    EvalCheck.Warns("7.0//2", "'//' failed")
    EvalCheck.Warns("7//2.0", "'//' failed")
    EvalCheck.Warns('"a"//2', "'//' failed")
}

CheckMinIntIsNotFatal() {
    ; AutoHotkey ends the whole process (not catchable) for MinInt // -1 and Mod(MinInt, -1)
    EvalCheck.Warns("(0 - 9223372036854775807 - 1) // -1", "integer overflow")
    EvalCheck.Table([["mod(0 - 9223372036854775807 - 1, -1)", 0]])
    EvalCheck.Table([["(0 - 9223372036854775807 - 1) // 1", -9223372036854775807 - 1]])
}

CheckComparisonsOfNumbers() {
    EvalCheck.Table([
        ["1 < 2", 1],
        ["2 < 1", 0],
        ["2 > 1", 1],
        ["1 > 2", 0],
        ["1 <= 1", 1],
        ["2 <= 1", 0],
        ["1 >= 1", 1],
        ["1 >= 2", 0],
        ["1.5 < 2", 1],
        ["-1 < 0", 1],
        ["1 < 2 < 3", 1],
        ["3 > 2 > 1", 0],
    ])
}

CheckComparisonRuleE30() {
    ; numeric strings compare as numbers
    EvalCheck.Table([
        ['"10" < "9"', 0],
        ['"10" > "9"', 1],
        ['"10" < 9', 0],
        ['"2" <= "10"', 1],
        ['"0x10" > 15', 1],
    ])
    ; a text that is not a number: AutoHotkey throws a TypeError, the result is "" plus an f1 log (E0030, E0025)
    EvalCheck.Warns('"a" < "B"', "'<' failed")
    EvalCheck.Warns('"abc" < "ABD"', "'<' failed")
    EvalCheck.Warns('"10" < "9a"', "'<' failed")
    EvalCheck.Warns('"a" > "b"', "'>' failed")
    EvalCheck.Warns('"a" <= "b"', "'<=' failed")
    EvalCheck.Warns('"a" >= "b"', "'>=' failed")
    EvalCheck.Warns('"" < 1', "'<' failed")
    EvalCheck.Warns('1 < ""', "'<' failed")
    ; the empty text is false, so as a condition the comparison does not take the branch
    Assert.Equal(EvalCheck.Value('if "a" < "b" {`nx := 1`n} else {`nx := 2`n}', "", "script"), 2)
}

CheckEquality() {
    EvalCheck.Table([
        ['"abc" = "ABC"', 1],
        ['"abc" == "ABC"', 0],
        ['"abc" == "abc"', 1],
        ['"abc" != "ABC"', 0],
        ['"abc" != "abd"', 1],
        ['"abc" !== "ABC"', 1],
        ['"abc" !== "abc"', 0],
        ["1 = 1.0", 1],
        ['"1.0" = 1', 1],
        ['"" = 0', 0],
        ['"" = ""', 1],
        ["1 = 2", 0],
        ["1 != 2", 1],
        ['"a" = 1', 0],
        ["1 == 1", 1],
        ["true = 1", 1],
        ["false = 0", 1],
    ])
}

CheckLogicRuleE31() {
    ; && and || return the operand, not 1 or 0; the second operand is not evaluated when it is not needed
    EvalCheck.Table([
        ['"a" || 0', "a"],
        ['0 || "a"', "a"],
        ['"" || ""', ""],
        ['"a" && 0', 0],
        ['0 && "x"', 0],
        ['"a" && "b"', "b"],
        ['"" && "b"', ""],
        ['"0" || "x"', "x"],
        ['"0" && "x"', "0"],
        ['2 and 3', 3],
        ['0 or 7', 7],
        ['0 or 0', 0],
        ['1 or 2 and 0', 1],
        ['(1 or 0) and 0', 0],
        ['5 || (1/0)', 5],
        ['0 && (1/0)', 0],
    ])
    res := EvalCheck.Run('0 and (x := 5)')
    Assert.Equal(res["resolver"].vars.Has("x"), false)
    res := EvalCheck.Run('1 or (x := 5)')
    Assert.Equal(res["resolver"].vars.Has("x"), false)
    res := EvalCheck.Run('1 and (x := 5)')
    Assert.Equal(res["resolver"].vars["x"], 5)
    res := EvalCheck.Run('0 or (x := 5)')
    Assert.Equal(res["resolver"].vars["x"], 5)
}

CheckNot() {
    EvalCheck.Table([
        ['!""', 1],
        ['!"0"', 1],
        ['!0', 1],
        ['!1', 0],
        ['!"abc"', 0],
        ['not 1', 0],
        ['not 1 = 2', 1],
        ['!1 = 2', 0],
        ['!!5', 1],
        ['not not ""', 0],
        ['!0.0', 1],
    ])
}

CheckConcatenation() {
    EvalCheck.Table([
        ['"a" . "b"', "ab"],
        ['"a" "b"', "ab"],
        ['"a" 1 + 2', "a3"],
        ['1 . 2', "12"],
        ['"Sum: " (1 + 2)', "Sum: 3"],
        ['1.0 . "x"', "1.0x"],
        ['"" . ""', ""],
        ['"x" . 4/2', "x2"],
    ])
}

CheckFloatTextRuleE32() {
    ; the text form of a Float is the AutoHotkey form, no own formatting
    EvalCheck.TextTable([
        ["0.1 + 0.2", "0.30000000000000004"],
        ["1/3", "0.33333333333333331"],
        ["0.5 + 0.25", "0.75"],
        ["2 / 4", "0.5"],
        ["1.5 * 2", "3.0"],
        ["1e3 + 0", "1000.0"],
        ["0.1 * 3", "0.30000000000000004"],
        ["10 / 4 * 2", "5.0"],
    ])
    EvalCheck.TextTable([['0.1 + 0.2 . ""', "0.30000000000000004"]])
}

CheckPrecedenceAndAssociativity() {
    EvalCheck.Table([
        ["1 + 2 * 3 - 4", 3],
        ["2 * 3 // 2", 3],
        ["10 - 2 - 3", 5],
        ["1 < 2 and 2 < 3", 1],
        ["1 = 1 and 2 = 3 or 1", 1],
        ['"a" . 1 + 1', "a2"],
        ["not 0 and 0", 0],
    ])
}

CheckValuesOfTheVersionTwoTable() {
    ; cross-check against the table "Behavior of AHK v2" (phase 3 plan), E-rules applied
    EvalCheck.Table([
        ["7/2", 3.5],
        ["0.5+0.25", 0.75],
        ['"5" + 1', 6],
        ['" 5 " + 1', 6],
        ["7//2", 3],
        ["-7//2", -3],
        ['"abc" = "ABC"', 1],
        ['"10" < "9"', 0],
        ['"0x10" + 0', 16],
        ['!""', 1],
        ['!"0"', 1],
        ['"a" && 0', 0],
        ['"a" || 0', "a"],
    ])
}

TestRun.Init()

TestRun.Case("arithmetic with integers and floats", CheckArithmetic)
TestRun.Case("numeric strings are numbers", CheckNumericStrings)
TestRun.Case("E0025 type errors give the empty text, a warning and an f1 log", CheckTypeErrorsGiveEmptyText)
TestRun.Case("a warning carries line, column and the marked source", CheckWarningHasPosition)
TestRun.Case("evaluation goes on after a warning", CheckEvaluationContinuesAfterWarning)
TestRun.Case("E0029 exact division of integers gives an integer", CheckDivisionRuleE29)
TestRun.Case("division by zero gives the empty text and a warning", CheckDivisionByZero)
TestRun.Case("integer division as in AutoHotkey", CheckIntegerDivision)
TestRun.Case("MinInt // -1 does not end the process", CheckMinIntIsNotFatal)
TestRun.Case("comparisons of numbers", CheckComparisonsOfNumbers)
TestRun.Case("E0030 comparisons follow AutoHotkey, text operands give the empty text", CheckComparisonRuleE30)
TestRun.Case("equality operators", CheckEquality)
TestRun.Case("E0031 logic operators return the operand and short-circuit", CheckLogicRuleE31)
TestRun.Case("not and the exclamation mark", CheckNot)
TestRun.Case("concatenation", CheckConcatenation)
TestRun.Case("E0032 text form of floats", CheckFloatTextRuleE32)
TestRun.Case("precedence and associativity in evaluation", CheckPrecedenceAndAssociativity)
TestRun.Case("values of the AutoHotkey v2 table of the phase 3 plan", CheckValuesOfTheVersionTwoTable)

TestRun.Finish()
