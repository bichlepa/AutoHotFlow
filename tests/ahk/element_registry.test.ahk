#Requires AutoHotkey v2.0
; Unit tests for src/elements/base/ElementRegistry.ahk and the skeleton element files (WI-09,
; doc/ELEMENT-API-V2.md sections 2 and 6).
#Include lib\Assert.ahk
#Include ..\..\src\elements\base\ElementRegistry.ahk
#Include ..\..\src\elements\skeleton\Trigger_Manual.ahk
#Include ..\..\src\elements\skeleton\Action_Sleep.ahk
#Include ..\..\src\elements\skeleton\Action_Do_nothing.ahk
#Include ..\..\src\elements\skeleton\Action_TestThrow.ahk
#Include ..\..\src\elements\skeleton\Action_TestBlockWorker.ahk
#Include ..\..\src\elements\skeleton\Action_TestHangWorker.ahk

; Element classes that are only used by these tests. They are not registered unless a test does it.
class Test_BadMode extends AhfElement {
    static Mode := "remote"
}

; Reads a skeleton source file as text (UTF-8, BOM removed).
ReadSource(name) {
    text := FileRead(A_ScriptDir "\..\..\src\elements\skeleton\" name, "UTF-8")
    if (SubStr(text, 1, 1) = Chr(0xFEFF))
        text := SubStr(text, 2)
    return text
}

TestRun.Init()

TestRun.Case("Registry: lookup is case-insensitive", LookupIsCaseInsensitive)
TestRun.Case("Registry: unknown class id gives an empty result", UnknownIdGivesEmpty)
TestRun.Case("Registry: duplicate registration is rejected", DuplicateIsRejected)
TestRun.Case("Registry: invalid Mode is rejected", InvalidModeIsRejected)
TestRun.Case("Registry: a class that is not an element is rejected", NonElementIsRejected)
TestRun.Case("Registry: ModeOf reports the declared mode", ModeOfReportsMode)
TestRun.Case("Registry: All lists the skeleton classes", AllListsSkeleton)
TestRun.Case("Registry: IdOf gives the class name even though Name() is defined", IdOfIgnoresNameMethod)
TestRun.Case("Skeleton: no x_ helpers and no global variables", SkeletonUsesNoV1Helpers)

LookupIsCaseInsensitive() {
    Assert.Equal(ElementRegistry.Get("trigger_manual"), Trigger_Manual)
    Assert.Equal(ElementRegistry.Get("TRIGGER_MANUAL"), Trigger_Manual)
    Assert.Equal(ElementRegistry.Get("Action_Sleep"), Action_Sleep)
}

UnknownIdGivesEmpty() {
    Assert.Equal(ElementRegistry.Get("Action_Nope"), "")
    Assert.Equal(ElementRegistry.ModeOf("Action_Nope"), "")
}

DuplicateIsRejected() {
    Assert.Throws(() => ElementRegistry.Register(Action_Sleep), AhfError)
    Assert.Equal(ElementRegistry.Get("Action_Sleep"), Action_Sleep, "the first registration stays")
}

InvalidModeIsRejected() {
    Assert.Throws(() => ElementRegistry.Register(Test_BadMode), AhfError)
    Assert.Equal(ElementRegistry.Get("Test_BadMode"), "")
}

NonElementIsRejected() {
    Assert.Throws(() => ElementRegistry.Register(Map), AhfError)
    Assert.Throws(() => ElementRegistry.Register("Action_Sleep"), AhfError)
}

ModeOfReportsMode() {
    Assert.Equal(ElementRegistry.ModeOf("trigger_manual"), "trigger")
    Assert.Equal(ElementRegistry.ModeOf("Action_Sleep"), "inline")
    Assert.Equal(ElementRegistry.ModeOf("Action_TestBlockWorker"), "worker")
    Assert.Equal(ElementRegistry.ModeOf("Action_TestHangWorker"), "worker")
}

AllListsSkeleton() {
    all := ElementRegistry.All()
    Assert.Equal(all.Length, 6, "skeleton registers six classes")
    found := 0
    for cls in all
        if (cls = Action_Sleep || cls = Trigger_Manual)
            found += 1
    Assert.Equal(found, 2)
}

IdOfIgnoresNameMethod() {
    Assert.Equal(ElementRegistry.IdOf(Action_Sleep), "Action_Sleep")
    Assert.Equal(ElementRegistry.IdOf(Trigger_Manual), "Trigger_Manual")
    Assert.Equal(Action_Sleep.Name(), "Sleep")
}

SkeletonUsesNoV1Helpers() {
    files := ["Action_Sleep.ahk", "Action_Do_nothing.ahk", "Action_TestThrow.ahk",
              "Action_TestBlockWorker.ahk", "Action_TestHangWorker.ahk", "Trigger_Manual.ahk"]
    for name in files {
        text := ReadSource(name)
        Assert.Equal(RegExMatch(text, "\bx_[A-Za-z]"), 0, name ": uses an x_ helper")
        Assert.Equal(RegExMatch(text, "im)^\s*global\s"), 0, name ": declares a global")
    }
}

TestRun.Finish()
