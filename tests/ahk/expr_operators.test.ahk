#Requires AutoHotkey v2.0
; Unit tests for operators, precedence, paths and calls of the expression language (WI-0037, doc/EXPRESSION-LANGUAGE.md sections 4 to 7).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\ExprCheck.ahk

CheckArithmeticPrecedence() {
    ExprCheck.Table([
        ["1+2", "(+ 1 2)"],
        ["1 + 2 * 3", "(+ 1 (* 2 3))"],
        ["2*3+4", "(+ (* 2 3) 4)"],
        ["(1+2)*3", "(* (+ 1 2) 3)"],
        ["10-4-3", "(- (- 10 4) 3)"],
        ["100/10/5", "(/ (/ 100 10) 5)"],
        ["100/(10/5)", "(/ 100 (/ 10 5))"],
        ["7/2*2", "(* (/ 7 2) 2)"],
        ["7//2", "(// 7 2)"],
        ["8 // 2 * 3", "(* (// 8 2) 3)"],
        ["1 + 2 // 3", "(+ 1 (// 2 3))"],
        ["  1  +   2  ", "(+ 1 2)"],
        ["((1+2)*(3+4))", "(* (+ 1 2) (+ 3 4))"],
        ["(5)", "5"],
        ["1+2+3+4", "(+ (+ (+ 1 2) 3) 4)"],
    ])
}

CheckUnaryMinus() {
    ExprCheck.Table([
        ["-5", "(neg 5)"],
        ["- 5", "(neg 5)"],
        ["-x", "(neg x)"],
        ["-(2+3)", "(neg (+ 2 3))"],
        ["5 - -3", "(- 5 (neg 3))"],
        ["2*-3", "(* 2 (neg 3))"],
        ["2*-(1+1)", "(* 2 (neg (+ 1 1)))"],
        ["- -x", "(neg (neg x))"],
        ["-a.b", "(neg (mem a `"b`"))"],
        ["-2*3", "(* (neg 2) 3)"],
        ["3 -2", "(- 3 2)"],
        ["x-1", "(- x 1)"],
        ["x -1", "(- x 1)"],
    ])
}

CheckLogicPrecedence() {
    ExprCheck.Table([
        ["1 and 0", "(&& 1 0)"],
        ["1 && 0", "(&& 1 0)"],
        ["0 or 1", "(|| 0 1)"],
        ["0 || 1", "(|| 0 1)"],
        ["1 or 2 and 0", "(|| 1 (&& 2 0))"],
        ["0 and 1 or 1", "(|| (&& 0 1) 1)"],
        ["(1 or 0) and 0", "(&& (|| 1 0) 0)"],
        ["1 and 2 and 3", "(&& (&& 1 2) 3)"],
        ["`"`" || 0 || `"z`"", "(|| (|| `"`" 0) `"z`")"],
        ["1 = 2 or 3 = 3", "(|| (= 1 2) (= 3 3))"],
        ["1 < 2 and 2 < 3", "(&& (< 1 2) (< 2 3))"],
        ["a and not b", "(&& a (! b))"],
        ["a and !b", "(&& a (! b))"],
        ["0 or not 0", "(|| 0 (! 0))"],
        ["not(1)", "(! 1)"],
        ["1 and(0)", "(&& 1 0)"],
        ["0 or(1)", "(|| 0 1)"],
        ["0 and (x := 5)", "(&& 0 (:= x 5))"],
    ])
}

CheckNotAndBang() {
    ; ! binds tight (like unary minus), "not" binds loose (below the comparisons), as in AutoHotkey v2
    ExprCheck.Table([
        ["!1 = 2", "(= (! 1) 2)"],
        ["not 1 = 2", "(! (= 1 2))"],
        ["!(1=2)", "(! (= 1 2))"],
        ["not (1=2)", "(! (= 1 2))"],
        ["!!1", "(! (! 1))"],
        ["not not 1", "(! (! 1))"],
        ["!x.y", "(! (mem x `"y`"))"],
        ["!-1", "(! (neg 1))"],
        ["-!1", "(neg (! 1))"],
        ["not a and b", "(&& (! a) b)"],
        ["not a or b", "(|| (! a) b)"],
        ["!a and b", "(&& (! a) b)"],
        ["x := not 0", "(:= x (! 0))"],
        ["!`"`"", "(! `"`")"],
    ])
}

CheckComparisons() {
    ExprCheck.Table([
        ["1<2", "(< 1 2)"],
        ["2>1", "(> 2 1)"],
        ["1<=1", "(<= 1 1)"],
        ["2>=3", "(>= 2 3)"],
        ["1=1", "(= 1 1)"],
        ["1==1", "(== 1 1)"],
        ["1!=2", "(!= 1 2)"],
        ["`"a`"!==`"A`"", "(!== `"a`" `"A`")"],
        ["1=1=1", "(= (= 1 1) 1)"],
        ["1<2<3", "(< (< 1 2) 3)"],
        ["1+1=2", "(= (+ 1 1) 2)"],
        ["1 < 2 = 1", "(= (< 1 2) 1)"],
        ["a . b = c", "(= (. a b) c)"],
        ["x<y", "(< x y)"],
        ["x!=-1", "(!= x (neg 1))"],
        ["x>=-1", "(>= x (neg 1))"],
        ["x=-1", "(= x (neg 1))"],
        ["x<-1", "(< x (neg 1))"],
    ])
}

CheckConcatenation() {
    ExprCheck.Table([
        ["`"a`" . `"b`"", "(. `"a`" `"b`")"],
        ["`"a`" `"b`"", "(. `"a`" `"b`")"],
        ["`"a`" `"b`" `"c`"", "(. (. `"a`" `"b`") `"c`")"],
        ["`"a`" . 1", "(. `"a`" 1)"],
        ["1 . 2", "(. 1 2)"],
        ["1 2", "(. 1 2)"],
        ["x y", "(. x y)"],
        ["x `"-`" y", "(. (. x `"-`") y)"],
        ["x`"-`"y", "(. (. x `"-`") y)"],
        ["`"a`"1", "(. `"a`" 1)"],
        ["1`"a`"", "(. 1 `"a`")"],
        ["`"a`" 1 + 2", "(. `"a`" (+ 1 2))"],
        ["1 + 2 `"a`"", "(. (+ 1 2) `"a`")"],
        ["1 . 2 + 3", "(. 1 (+ 2 3))"],
        ["`"a`" . 2 * 3", "(. `"a`" (* 2 3))"],
        ["`"a`" (1+2)", "(. `"a`" (+ 1 2))"],
        ["(`"a`" . `"b`") . `"c`"", "(. (. `"a`" `"b`") `"c`")"],
        ["x . y . z", "(. (. x y) z)"],
        ["a.b . c.d", "(. (mem a `"b`") (mem c `"d`"))"],
        ["x y = z", "(= (. x y) z)"],
        ["x true", "(. x true)"],
        ["round (2.5)", "(. round 2.5)"],
        ["round(1) round(2)", "(. (call round 1) (call round 2))"],
        ["x 1.5", "(. x 1.5)"],
    ])
}

CheckDotNeedsSpaces() {
    ExprCheck.ErrorTable([
        ["`"a`".`"b`"", 1, 4, "needs a space"],
        ["1 .x", 1, 3, "needs a space"],
        ["1. x", 1, 2, "needs a space"],
        ["a. b", 1, 2, "needs a space"],
        ["a..b", 1, 2, "needs a space"],
        ["a.", 1, 2, "needs a space"],
        ["x .", 1, 4, "operand is expected"],
    ])
}

CheckAssignment() {
    ExprCheck.Table([
        ["x := 5", "(:= x 5)"],
        ["x := y := 3", "(:= x (:= y 3))"],
        ["x := (y := 3)", "(:= x (:= y 3))"],
        ["(x := 3) + 1", "(+ (:= x 3) 1)"],
        ["x += 1", "(+= x 1)"],
        ["x -= 1", "(-= x 1)"],
        ["x *= 3", "(*= x 3)"],
        ["x /= 2", "(/= x 2)"],
        ["x //= 2", "(//= x 2)"],
        ["x .= `"z`"", "(.= x `"z`")"],
        ["x := 1 + 2", "(:= x (+ 1 2))"],
        ["x := 1 = 1", "(:= x (= 1 1))"],
        ["x := a or b", "(:= x (|| a b))"],
        ["x := a . b", "(:= x (. a b))"],
        ["x:=1", "(:= x 1)"],
        ["x:=-1", "(:= x (neg 1))"],
        ["x+=-1", "(+= x (neg 1))"],
        ["a.b := 5", "(:= (mem a `"b`") 5)"],
        ["a[1] := 5", "(:= (idx a 1) 5)"],
        ["a.b.c += 1", "(+= (mem (mem a `"b`") `"c`") 1)"],
        ["a%i% := 5", "(:= $(`"a`" i) 5)"],
        ["%n% := 5", "(:= $(n) 5)"],
        ["x := f(y := 2)", "(:= x (call f (:= y 2)))"],
    ])
}

CheckAssignmentTargets() {
    ExprCheck.ErrorTable([
        ["1 := 2", 1, 1, "left side of ':='"],
        ["x + 1 := 2", 1, 1, "left side of ':='"],
        ["`"a`" := 2", 1, 1, "left side of ':='"],
        ["a b := 1", 1, 1, "left side of ':='"],
        ["f(x) := 1", 1, 1, "left side of ':='"],
        ["-x := 1", 1, 1, "left side of ':='"],
        ["1 += 2", 1, 1, "left side of '+='"],
        ["x := 1 + y := 2", 1, 6, "left side of ':='"],
    ])
}

CheckDotPaths() {
    ExprCheck.Table([
        ["a.b", "(mem a `"b`")"],
        ["a.B", "(mem a `"B`")"],
        ["a.b.c", "(mem (mem a `"b`") `"c`")"],
        ["a.1", "(mem a 1)"],
        ["a.0", "(mem a 0)"],
        ["a.l.2", "(mem (mem a `"l`") 2)"],
        ["m.1.x", "(mem (mem m 1) `"x`")"],
        ["a.and", "(mem a `"and`")"],
        ["a.b + a.c", "(+ (mem a `"b`") (mem a `"c`"))"],
        ["a.007", "(mem a `"007`")"],
        ["a.1x", "(mem a `"1x`")"],
        ["a.b1", "(mem a `"b1`")"],
        ["a . b", "(. a b)"],
    ])
}

CheckIndexPaths() {
    ExprCheck.Table([
        ["a[1]", "(idx a 1)"],
        ["a[i]", "(idx a i)"],
        ["a[i+1]", "(idx a (+ i 1))"],
        ["a[`"b`"]", "(idx a `"b`")"],
        ["m[1][2]", "(idx (idx m 1) 2)"],
        ["m[1].x", "(mem (idx m 1) `"x`")"],
        ["m.x[2]", "(idx (mem m `"x`") 2)"],
        ["a[b[1]]", "(idx a (idx b 1))"],
        ["a[ 1 ]", "(idx a 1)"],
        ["a[x := 1]", "(idx a (:= x 1))"],
        ["a[i].b := 1", "(:= (mem (idx a i) `"b`") 1)"],
    ])
}

CheckDynamicNames() {
    ExprCheck.Table([
        ["a%i%", "$(`"a`" i)"],
        ["%n%", "$(n)"],
        ["%p%a", "$(p `"a`")"],
        ["a%i%b", "$(`"a`" i `"b`")"],
        ["ro%x%nd", "$(`"ro`" x `"nd`")"],
        ["%a%%b%", "$(a b)"],
        ["a%i+1%", "$(`"a`" (+ i 1))"],
        ["a%i%1", "$(`"a`" i `"1`")"],
        ["a%i%.b", "(mem $(`"a`" i) `"b`")"],
        ["a.%k%", "(mem a k)"],
        ["a.%k+1%", "(mem a (+ k 1))"],
        ["a.x%i%", "(mem a (. `"x`" i))"],
        ["a.%k%y", "(mem a (. k `"y`"))"],
        ["a[%k%]", "(idx a $(k))"],
        ["%a.b%", "$((mem a `"b`"))"],
        ["%(a)%", "$(a)"],
        ["a %i%", "(. a $(i))"],
        ["x := %n% + 1", "(:= x (+ $(n) 1))"],
    ])
}

CheckDynamicNameErrors() {
    ExprCheck.ErrorTable([
        ["a%i", 1, 2, "'%' is not closed"],
        ["%%", 1, 2, "expression is expected between the '%'"],
        ["a%%", 1, 3, "expression is expected between the '%'"],
        ["%", 1, 2, "unexpected end"],
        ["a % i %", 1, 3, "modulo"],
        ["7 % 3", 1, 3, "modulo"],
        ["7%3", 1, 2, "'%' is not closed"],
        ["x %= 2", 1, 3, "'%='"],
    ])
}

CheckCalls() {
    ExprCheck.Table([
        ["round(3)", "(call round 3)"],
        ["round()", "(call round)"],
        ["round( 2.5 )", "(call round 2.5)"],
        ["round(2.5, 1)", "(call round 2.5 1)"],
        ["round(1/3, 2)", "(call round (/ 1 3) 2)"],
        ["round(round(2.5))", "(call round (call round 2.5))"],
        ["round(2.5) + 1", "(+ (call round 2.5) 1)"],
        ["ROUND(2.5)", "(call ROUND 2.5)"],
        ["round", "round"],
        ["a.b()", "(call (mem a `"b`"))"],
        ["a.b.c(1)", "(call (mem (mem a `"b`") `"c`") 1)"],
        ["a[1](2)", "(call (idx a 1) 2)"],
        ["(round)(1)", "(call round 1)"],
        ["ro%x%nd(2.5)", "(call $(`"ro`" x `"nd`") 2.5)"],
        ["f(1,`n 2)", "(call f 1 2)"],
        ["f(a, b, c)", "(call f a b c)"],
        ["f(x := 1)", "(call f (:= x 1))"],
        ["f(1 2)", "(call f (. 1 2))"],
        ["f(a.b(1))", "(call f (call (mem a `"b`") 1))"],
        ["f(`"a,b`")", "(call f `"a,b`")"],
        ["f(-1)", "(call f (neg 1))"],
    ])
}

CheckCallErrors() {
    ExprCheck.ErrorTable([
        ["round(2.5", 1, 6, "'(' is not closed"],
        ["round(,)", 1, 7, "argument is expected"],
        ["round(2.5,)", 1, 11, "argument is expected"],
        ["round(,2)", 1, 7, "argument is expected"],
        ["`"a`"(1)", 1, 4, "can be called"],
        ["5(1)", 1, 2, "can be called"],
        ["f(1)(2)", 1, 5, "can be called"],
        ["(1)(2)", 1, 4, "can be called"],
        ["f(1 +)", 1, 6, "an operand is expected"],
        ["f(1; 2)", 1, 4, "comment must be preceded"],
    ])
}

CheckBrackets() {
    ExprCheck.ErrorTable([
        ["(1+2", 1, 1, "'(' is not closed"],
        ["1+2)", 1, 4, "unexpected ')'"],
        ["(", 1, 1, "'(' is not closed"],
        [")", 1, 1, "unexpected ')'"],
        ["()", 1, 2, "expression is expected between '(' and ')'"],
        ["((((1", 1, 4, "'(' is not closed"],
        ["a[", 1, 2, "'[' is not closed"],
        ["a[1", 1, 2, "'[' is not closed"],
        ["a[]", 1, 3, "between '[' and ']'"],
        ["a]", 1, 2, "unexpected ']'"],
        ["a[1)", 1, 4, "expected ']'"],
        ["(1]", 1, 3, "expected ')'"],
        ["{}", 1, 1, "unexpected '{'"],
        ["a.", 1, 2, "needs a space"],
    ])
}

CheckUnsupportedOperators() {
    ; these exist in AutoHotkey v2 but not in this language: each gets its own message
    ExprCheck.ErrorTable([
        ["7 % 3", 1, 3, "modulo operator '%' is not supported"],
        ["2**3", 1, 2, "power operator"],
        ["1 ? 2 : 3", 1, 3, "conditional operator"],
        ["x ? 1 : 2", 1, 3, "conditional operator"],
        ["a ?? b", 1, 3, "'??'"],
        ["x++", 1, 2, "increment"],
        ["x--", 1, 2, "decrement"],
        ["++x", 1, 1, "increment"],
        ["1 << 2", 1, 3, "bitwise"],
        ["1 >> 2", 1, 3, "bitwise"],
        ["1 & 2", 1, 3, "bitwise"],
        ["1 | 2", 1, 3, "bitwise"],
        ["1 ^ 2", 1, 3, "bitwise"],
        ["~1", 1, 1, "bitwise"],
        ["x ^= 2", 1, 3, "bitwise"],
        ["x %= 2", 1, 3, "'%='"],
        ["a ~= b", 1, 3, "regular expression"],
        ["a => b", 1, 3, "'=>'"],
        ["1 <> 2", 1, 3, "'!='"],
        ["+5", 1, 1, "unary '+'"],
        ["1 + + 2", 1, 5, "unary '+'"],
        ["a, b", 1, 2, "unexpected ','"],
        ["x := 1, y := 2", 1, 7, "unexpected ','"],
        ["5--3", 1, 2, "decrement"],
    ])
}

CheckNodePositions() {
    res := ExprCheck.Parse("  a + bc ")
    n := res["ast"]
    Assert.Equal(n["pos"], 3)
    Assert.Equal(n["end"], 9)
    Assert.Equal(n["line"], 1)
    Assert.Equal(n["col"], 3)
    Assert.Equal(n["left"]["pos"], 3)
    Assert.Equal(n["left"]["end"], 4)
    Assert.Equal(n["right"]["pos"], 7)
    Assert.Equal(n["right"]["end"], 9)
    Assert.Equal(n["right"]["col"], 7)
    ; second line
    res := ExprCheck.Parse("1 +`n  foo(2)")
    n := res["ast"]
    Assert.Equal(n["right"]["line"], 2)
    Assert.Equal(n["right"]["col"], 3)
    Assert.Equal(n["right"]["pos"], 7)
    Assert.Equal(n["right"]["end"], 13)
    Assert.Equal(n["right"]["args"][1]["pos"], 11)
    ; strings: the span includes the quotes
    n := ExprCheck.Parse('"ab"')["ast"]
    Assert.Equal(n["end"] - n["pos"], 4)
    ; index and call: the end is behind the closing bracket
    n := ExprCheck.Parse("x[12]")["ast"]
    Assert.Equal(n["end"], 6)
    n := ExprCheck.Parse("f(1, 2)")["ast"]
    Assert.Equal(n["end"], 8)
    n := ExprCheck.Parse("a.bc")["ast"]
    Assert.Equal(n["end"], 5)
    Assert.Equal(n["key"]["pos"], 3)
    ; empty input
    n := ExprCheck.Parse("  ")["ast"]
    Assert.Equal(n["type"], "Empty")
    Assert.Equal(n["pos"], 3)
}

CheckNodeDepth() {
    Assert.Equal(ExprCheck.Parse("1")["ast"]["depth"], 1)
    Assert.Equal(ExprCheck.Parse("1+2")["ast"]["depth"], 2)
    Assert.Equal(ExprCheck.Parse("1+2*3")["ast"]["depth"], 3)
    Assert.Equal(ExprCheck.Parse("f(1, g(2))")["ast"]["depth"], 3)
    Assert.Equal(ExprCheck.Parse("a.b.c")["ast"]["depth"], 3)
    Assert.Equal(ExprCheck.Parse("a%i%")["ast"]["depth"], 2)
}

TestRun.Init()

TestRun.Case("arithmetic precedence and associativity", CheckArithmeticPrecedence)
TestRun.Case("unary minus", CheckUnaryMinus)
TestRun.Case("logic operators and their precedence", CheckLogicPrecedence)
TestRun.Case("! binds tight, not binds loose", CheckNotAndBang)
TestRun.Case("comparison operators", CheckComparisons)
TestRun.Case("concatenation with a dot and by writing operands next to each other", CheckConcatenation)
TestRun.Case("the concatenation dot needs a space on both sides", CheckDotNeedsSpaces)
TestRun.Case("assignments are right associative", CheckAssignment)
TestRun.Case("only variables and paths can be assigned to", CheckAssignmentTargets)
TestRun.Case("paths with a dot", CheckDotPaths)
TestRun.Case("paths with brackets", CheckIndexPaths)
TestRun.Case("dynamic names with percent signs", CheckDynamicNames)
TestRun.Case("errors in dynamic names", CheckDynamicNameErrors)
TestRun.Case("function and method calls", CheckCalls)
TestRun.Case("errors in calls", CheckCallErrors)
TestRun.Case("brackets that do not match", CheckBrackets)
TestRun.Case("operators the language does not have", CheckUnsupportedOperators)
TestRun.Case("node positions", CheckNodePositions)
TestRun.Case("node depth", CheckNodeDepth)

TestRun.Finish()
