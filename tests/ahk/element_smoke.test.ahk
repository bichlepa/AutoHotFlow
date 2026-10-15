#Requires AutoHotkey v2.0
; L0001 smoke test of every registered element (WI-0048, doc/TEST-STRATEGY.md section 2). The classes are those that the
; engine of the product registers (src/entry/generated/Elements_engine.ahk: all packages, all modes), so a new element
; is covered as soon as it is registered, without test code. The checks are in lib\ElementSmoke.ahk.
; The second half is the test of the test: deliberately broken classes must fail with the right rule.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include lib\ElementSmoke.ahk
#Include ..\..\src\entry\generated\Elements_engine.ahk

Log.Configure(Log.Memory)

PACKAGES_DIR := A_ScriptDir "\..\..\src\elements"
V1_DIR := A_ScriptDir "\..\..\v1\Source_Elements"

; Broken classes, one rule each. They are not registered (they are not in a package folder); Check takes the class.
class Broken {
    class BadMode extends AhfElement {
        static Mode := "remote"
        static Name() => "x"
        static Category() => "x"
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class BadLevel extends AhfElement {
        static Level := "Expert"
        static Name() => "x"
        static Category() => "x"
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class EmptyName extends AhfElement {
        static Name() => ""
        static Category() => "x"
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class MissingIcon extends AhfElement {
        static Icon := "no_such_icon.png"
        static Name() => "x"
        static Category() => "x"
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class TimeoutOnInline extends AhfElement {
        static JobTimeoutMs := 5000
        static Name() => "x"
        static Category() => "x"
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class DuplicateIds extends AhfElement {
        static Name() => "x"
        static Category() => "x"
        static Parameters(ctx) => [{type: "Edit", id: "Text"}, {type: "Edit", id: "text"}]
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class UnknownContent extends AhfElement {
        static Name() => "x"
        static Category() => "x"
        static Parameters(ctx) => [{type: "Edit", id: "Text", content: "Formula"}]
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class EnumLengths extends AhfElement {
        static Name() => "x"
        static Category() => "x"
        static Parameters(ctx) => [{type: "Radio", id: "Unit", result: "enum", choices: ["a", "b"], enum: ["A"]}]
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class BadContentId extends AhfElement {
        static Name() => "x"
        static Category() => "x"
        static Parameters(ctx) => [{type: "Edit", id: "Text", content: ["String", "Expression"], contentID: "Kind"}]
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class V1SyntaxUnknown extends AhfElement {
        static V1Syntax := Map("Script", "script")
        static Name() => "x"
        static Category() => "x"
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class NoGenerateName extends AhfElement {
        static Name() => "x"
        static Category() => "x"
        static Run(ctx, params) {
        }
    }
    class MissingLangKey extends AhfElement {
        static Name() => Lang("A key that has no text anywhere")
        static Category() => "x"
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class NoRun extends AhfElement {
        static Name() => "x"
        static Category() => "x"
        static GenerateName(ctx, params) => "x"
    }
    class TriggerWithoutEnable extends AhfElement {
        static Mode := "trigger"
        static Name() => "x"
        static Category() => "x"
        static GenerateName(ctx, params) => "x"
        static Disable(ctx) {
        }
        static TriggerVariables(params, data) => Map()
    }
    class ParametersThrow extends AhfElement {
        static Name() => "x"
        static Category() => "x"
        static Parameters(ctx) {
            ctx.Form.Add()                  ; needs the editor
        }
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    ; v1 Loops/Condition.ahk evaluates the parameter Expression itself (x_EvaluateExpression)
    class Loop_Condition extends AhfElement {
        static Mode := "inline"
        static Name() => "x"
        static Category() => "x"
        static Parameters(ctx) => [{type: "Edit", id: "Expression", content: "RawString"}]
        static GenerateName(ctx, params) => "x"
        static Run(ctx, params) {
        }
    }
    class Loop_ConditionDeclared extends Broken.Loop_Condition {
        static V1Syntax := Map("Expression", "expression")
    }
    ; A class that is fine: the control of the table below.
    class Fine extends AhfElement {
        static Name() => "x"
        static Category() => "x"
        static Parameters(ctx) => [{type: "Edit", id: "Text", content: "String", default: "a"}]
        static GenerateName(ctx, params) => "x " params.Text
        static Run(ctx, params) {
        }
    }
}

TestRun.Init()

TestRun.Case("Smoke: the product registers elements", ProductRegistersElements)
TestRun.Case("Smoke: every registered element passes the checks of its contract", EveryElementPasses)
TestRun.Case("Smoke: v1 self-evaluated parameters are to be checked by hand", NothingToCheckByHand)
TestRun.Case("Smoke of the smoke: a fine class passes", FineClassPasses)
TestRun.Case("Smoke of the smoke: a broken class fails with the rule that it breaks", BrokenClassesFail)
TestRun.Case("Smoke of the smoke: a parameter that v1 evaluates itself needs an expression type or V1Syntax", V1SelfEvaluatedParameter)
TestRun.Case("Smoke of the smoke: the failure names the class and the rule", FailureTextNamesClassAndRule)

ProductRegistersElements() {
    Assert.True(ElementRegistry.All().Length >= 3, "the product registers fewer than 3 elements")
}

; One failure lists every violation of every class: "Package.Class [rule] what is wrong".
EveryElementPasses() {
    failures := []
    for cls in ElementRegistry.All() {
        res := ElementSmoke.Check(cls, PACKAGES_DIR, V1_DIR)
        for text in res["errors"]
            failures.Push(ElementRegistry.IdOf(cls) " " text)
    }
    if (failures.Length)
        throw AssertFailed(failures.Length " violation(s):`n" Join(failures, "`n"))
}

; What the test cannot decide goes to a person, never to a silent pass: the case is reported as a skip then.
NothingToCheckByHand() {
    list := []
    for cls in ElementRegistry.All() {
        res := ElementSmoke.Check(cls, PACKAGES_DIR, V1_DIR)
        for text in res["byHand"]
            list.Push(ElementRegistry.IdOf(cls) ": " text)
    }
    if (list.Length)
        throw AssertSkipped("check by hand:`n" Join(list, "`n"))
}

FineClassPasses() {
    res := ElementSmoke.Check(Broken.Fine, PACKAGES_DIR, V1_DIR)
    Assert.Equal(Join(res["errors"], "; "), "")
}

BrokenClassesFail() {
    table := [["BadMode", "[mode]"], ["BadLevel", "[level]"], ["EmptyName", "[name]"], ["MissingIcon", "[icon]"]
        , ["TimeoutOnInline", "[jobtimeout]"], ["DuplicateIds", "[param-id]"], ["UnknownContent", "[param-content]"]
        , ["EnumLengths", "[param-enum]"], ["BadContentId", "[param-contentid]"], ["V1SyntaxUnknown", "[v1syntax]"]
        , ["NoGenerateName", "[generatename]"], ["MissingLangKey", "[lang]"], ["NoRun", "[methods]"]
        , ["TriggerWithoutEnable", "[methods]"], ["ParametersThrow", "[parameters]"]]
    for row in table {
        res := ElementSmoke.Check(Broken.%row[1]%, PACKAGES_DIR, V1_DIR)
        text := Join(res["errors"], "`n")
        Assert.True(InStr(text, row[2]), "Broken." row[1] " did not fail with " row[2] ", errors: '" text "'")
    }
}

; The v1 file of the class evaluates a parameter itself: a RawString without V1Syntax fails, with V1Syntax it passes.
V1SelfEvaluatedParameter() {
    res := ElementSmoke.Check(Broken.Loop_Condition, PACKAGES_DIR, V1_DIR, "Default")
    Assert.Equal(res["errors"].Length, 1, Join(res["errors"], "; "))
    Assert.True(InStr(res["errors"][1], "[v1-self-evaluated] v1 evaluates the parameter 'Expression'"), res["errors"][1])
    res := ElementSmoke.Check(Broken.Loop_ConditionDeclared, PACKAGES_DIR, V1_DIR, "Default")
    Assert.Equal(res["errors"].Length, 0, Join(res["errors"], "; "))
}

FailureTextNamesClassAndRule() {
    res := ElementSmoke.Check(Broken.EnumLengths, PACKAGES_DIR, V1_DIR)
    Assert.Equal(res["errors"].Length, 1)
    Assert.Equal(res["errors"][1], "[param-enum] parameter 'Unit' has 2 choices but 1 enum values")
    Assert.Equal(ElementRegistry.IdOf(Broken.EnumLengths), "Broken.EnumLengths")
}

Join(list, sep) {
    out := ""
    for item in list
        out .= (A_Index = 1 ? "" : sep) item
    return out
}

TestRun.Finish()
