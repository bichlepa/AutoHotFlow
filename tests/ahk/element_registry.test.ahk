#Requires AutoHotkey v2.0
; Unit tests for src/elements/base/ElementRegistry.ahk and the element packages (WI-0009, WI-0047, E0045,
; doc/ELEMENT-API-V2.md sections 2 and 6). The classes come from the generated blocks of the packages Default (product)
; and Test (test elements), as a role entry includes them.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk
#Include ..\elements\Test\_includes_engine.ahk

; Element classes that are only used by these tests. They are not registered unless a test does it.
class RegTest {
    class Test_BadMode extends AhfElement {
        static Mode := "remote"
    }

    class Action_Sleep extends AhfElement {
        static Mode := "worker"
    }
}

; An element class that is not in a package: its type name has no package part.
class Action_Unpackaged extends AhfElement {
    static Mode := "inline"
}

; Reads an element source file of a package as text (UTF-8, BOM removed). path is relative to the repository.
ReadSource(path) {
    text := FileRead(A_ScriptDir "\..\..\" path, "UTF-8")
    if (SubStr(text, 1, 1) = Chr(0xFEFF))
        text := SubStr(text, 2)
    return text
}

TestRun.Init()

TestRun.Case("Registry: lookup by qualified ID is case-insensitive", LookupIsCaseInsensitive)
TestRun.Case("Registry: lookup by package and class, a missing package is Default", LookupByPackageAndClass)
TestRun.Case("Registry: unknown class id gives an empty result", UnknownIdGivesEmpty)
TestRun.Case("Registry: duplicate registration is rejected", DuplicateIsRejected)
TestRun.Case("Registry: invalid Mode is rejected", InvalidModeIsRejected)
TestRun.Case("Registry: a class that is not an element is rejected", NonElementIsRejected)
TestRun.Case("Registry: a class outside a package is rejected", UnpackagedIsRejected)
TestRun.Case("Registry: two packages may have a class of the same name", SameClassNameInTwoPackages)
TestRun.Case("Registry: ModeOf reports the declared mode", ModeOfReportsMode)
TestRun.Case("Registry: All lists the classes of the included blocks", AllListsTheBlocks)
TestRun.Case("Registry: IdOf gives the qualified ID even though Name() is defined", IdOfIgnoresNameMethod)
TestRun.Case("Registry: packages and their versions", PackagesAndVersions)
TestRun.Case("Registry: the text for a missing class names an unknown package", MissingTextNamesThePackage)
TestRun.Case("Packages: no x_ helpers and no global variables", ElementsUseNoV1Helpers)

LookupIsCaseInsensitive() {
    Assert.Equal(ElementRegistry.Get("default.trigger_manual"), Default.Trigger_Manual)
    Assert.Equal(ElementRegistry.Get("DEFAULT.TRIGGER_MANUAL"), Default.Trigger_Manual)
    Assert.Equal(ElementRegistry.Get("Default.Action_Sleep"), Default.Action_Sleep)
    Assert.Equal(ElementRegistry.Get("test.action_testthrow"), Test.Action_TestThrow)
}

LookupByPackageAndClass() {
    Assert.Equal(ElementRegistry.Lookup("", "action_sleep"), Default.Action_Sleep, "missing package")
    Assert.Equal(ElementRegistry.Lookup("default", "Action_Sleep"), Default.Action_Sleep, "v1 writes default")
    Assert.Equal(ElementRegistry.Lookup("Test", "Action_TestThrow"), Test.Action_TestThrow)
    Assert.Equal(ElementRegistry.Lookup("", "Action_TestThrow"), "", "a test class is not in Default")
    Assert.Equal(ElementRegistry.QualifiedId("", "Action_X"), "Default.Action_X")
    Assert.Equal(ElementRegistry.PackageOf("Test.Action_X"), "Test")
    Assert.Equal(ElementRegistry.ClassOf("Test.Action_X"), "Action_X")
}

UnknownIdGivesEmpty() {
    Assert.Equal(ElementRegistry.Get("Default.Action_Nope"), "")
    Assert.Equal(ElementRegistry.Get("Action_Sleep"), "", "the class name alone is not an ID")
    Assert.Equal(ElementRegistry.ModeOf("Default.Action_Nope"), "")
}

DuplicateIsRejected() {
    Assert.Throws(() => ElementRegistry.Register(Default.Action_Sleep), AhfError)
    Assert.Equal(ElementRegistry.Get("Default.Action_Sleep"), Default.Action_Sleep, "the first registration stays")
}

InvalidModeIsRejected() {
    Assert.Throws(() => ElementRegistry.Register(RegTest.Test_BadMode), AhfError)
    Assert.Equal(ElementRegistry.Get("RegTest.Test_BadMode"), "")
}

NonElementIsRejected() {
    Assert.Throws(() => ElementRegistry.Register(Map), AhfError)
    Assert.Throws(() => ElementRegistry.Register("Default.Action_Sleep"), AhfError)
}

UnpackagedIsRejected() {
    Assert.Throws(() => ElementRegistry.Register(Action_Unpackaged), AhfError)
    Assert.Equal(ElementRegistry.Get("Action_Unpackaged"), "")
}

SameClassNameInTwoPackages() {
    ElementRegistry.Register(RegTest.Action_Sleep)
    try {
        Assert.Equal(ElementRegistry.Get("RegTest.Action_Sleep"), RegTest.Action_Sleep)
        Assert.Equal(ElementRegistry.Get("Default.Action_Sleep"), Default.Action_Sleep)
        Assert.Equal(ElementRegistry.ModeOf("RegTest.Action_Sleep"), "worker")
        Assert.Equal(ElementRegistry.ModeOf("Default.Action_Sleep"), "inline")
    } finally {
        ElementRegistry.classes.Delete("RegTest.Action_Sleep")
        ElementRegistry.packages.Delete("RegTest")
    }
}

ModeOfReportsMode() {
    Assert.Equal(ElementRegistry.ModeOf("Default.trigger_manual"), "trigger")
    Assert.Equal(ElementRegistry.ModeOf("Default.Action_Sleep"), "inline")
    Assert.Equal(ElementRegistry.ModeOf("Test.Action_TestBlockWorker"), "worker")
    Assert.Equal(ElementRegistry.ModeOf("Test.Action_TestHangWorker"), "worker")
}

AllListsTheBlocks() {
    product := 0
    for cls in ElementRegistry.All() {
        id := ElementRegistry.IdOf(cls)
        Assert.True(InStr(id, "Default.") = 1 || InStr(id, "Test.") = 1, "unexpected class " id)
        if (InStr(id, "Default.") = 1)
            product += 1
    }
    Assert.Equal(product, 3, "Default has Action_Do_nothing, Action_Sleep and Trigger_Manual")
}

IdOfIgnoresNameMethod() {
    Assert.Equal(ElementRegistry.IdOf(Default.Action_Sleep), "Default.Action_Sleep")
    Assert.Equal(ElementRegistry.IdOf(Default.Trigger_Manual), "Default.Trigger_Manual")
    Assert.Equal(ElementRegistry.IdOf(Test.Action_TestThrow), "Test.Action_TestThrow")
    Assert.Equal(Default.Action_Sleep.Name(), "Sleep")
}

PackagesAndVersions() {
    Assert.True(ElementRegistry.HasPackage("Default"))
    Assert.True(ElementRegistry.HasPackage("default"), "case-insensitive")
    Assert.Equal(ElementRegistry.PackageVersion("Default"), "1.2.1", "the version of the v1 manifest")
    Assert.True(ElementRegistry.HasPackage("Test"))
    Assert.True(!ElementRegistry.HasPackage("NotInstalled"))
    ElementRegistry.RegisterPackage("Default", "1.2.1")              ; the same again: nothing happens
    Assert.Throws(() => ElementRegistry.RegisterPackage("Default", "9.9.9"), AhfError)
    Assert.Equal(ElementRegistry.PackageVersion("Default"), "1.2.1")
}

MissingTextNamesThePackage() {
    Assert.Equal(ElementRegistry.MissingText("NotInstalled.Action_X")
        , "element class 'NotInstalled.Action_X' is not available: package 'NotInstalled' is not installed")
    Assert.Equal(ElementRegistry.MissingText("Default.Action_X"), "unknown element class 'Default.Action_X'")
}

ElementsUseNoV1Helpers() {
    files := ["src\elements\Default\Actions\Action_Sleep.ahk", "src\elements\Default\Actions\Action_Do_nothing.ahk"
        , "src\elements\Default\Triggers\Trigger_Manual.ahk", "tests\elements\Test\Actions\Action_TestThrow.ahk"
        , "tests\elements\Test\Actions\Action_TestBlockWorker.ahk", "tests\elements\Test\Actions\Action_TestHangWorker.ahk"]
    for path in files {
        text := ReadSource(path)
        Assert.Equal(RegExMatch(text, "\bx_[A-Za-z]"), 0, path ": uses an x_ helper")
        Assert.Equal(RegExMatch(text, "im)^\s*global\s"), 0, path ": declares a global")
    }
}

TestRun.Finish()
