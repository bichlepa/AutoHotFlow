#Requires AutoHotkey v2.0
; Unit tests for src/ui_common/UiFileDialogs.ahk (E0076): the calls reach the provider with the arguments of FileSelect and
; DirSelect, the answers come back unchanged, and an owner that is no Gui of this script does no harm. No dialog is shown.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\ui_common\UiFileDialogs.ahk

class StubFileProvider {
    calls := []
    answer := ""

    FileSelect(options, root, title, filter) {
        this.calls.Push(["FileSelect", options, root, title, filter])
        return this.answer
    }

    DirSelect(root, options, prompt) {
        this.calls.Push(["DirSelect", root, options, prompt])
        return this.answer
    }
}

TestRun.Init()

TestRun.Case("File: the arguments reach the provider and the answer comes back", () => (
    p := StubFileProvider(),
    p.answer := "C:\flows\a.ahf",
    UiFileDialogs.UseProvider(p),
    Assert.Equal(UiFileDialogs.File(0, "3", "C:\flows", "Import", "Flows (*.ahf)"), "C:\flows\a.ahf"),
    UiFileDialogs.UseProvider(""),
    Assert.Equal(p.calls.Length, 1),
    Assert.Equal(p.calls[1][1], "FileSelect"),
    Assert.Equal(p.calls[1][2], "3"),
    Assert.Equal(p.calls[1][3], "C:\flows"),
    Assert.Equal(p.calls[1][4], "Import"),
    Assert.Equal(p.calls[1][5], "Flows (*.ahf)")))

TestRun.Case("Dir: the arguments reach the provider with the defaults of DirSelect", () => (
    p := StubFileProvider(),
    p.answer := "C:\data",
    UiFileDialogs.UseProvider(p),
    Assert.Equal(UiFileDialogs.Dir(), "C:\data"),
    UiFileDialogs.UseProvider(""),
    Assert.Equal(p.calls[1][1], "DirSelect"),
    Assert.Equal(p.calls[1][2], ""),
    Assert.Equal(p.calls[1][3], 1),
    Assert.Equal(p.calls[1][4], "")))

TestRun.Case("File: a cancelled dialog returns an empty string, multi-select an Array", () => (
    p := StubFileProvider(),
    UiFileDialogs.UseProvider(p),
    Assert.Equal(UiFileDialogs.File(), ""),
    p.answer := ["C:\a.ahf", "C:\b.ahf"],
    Assert.Equal(UiFileDialogs.File(0, "M").Length, 2),
    UiFileDialogs.UseProvider("")))

TestRun.Case("Owner: a handle that is no Gui of this script is ignored", () => (
    p := StubFileProvider(),
    p.answer := "x",
    UiFileDialogs.UseProvider(p),
    Assert.Equal(UiFileDialogs.File(123456789), "x"),
    Assert.Equal(UiFileDialogs.Dir(123456789), "x"),
    UiFileDialogs.UseProvider(""),
    Assert.Equal(p.calls.Length, 2)))

TestRun.Case("UseProvider with an empty string restores the real dialogs", () => (
    UiFileDialogs.UseProvider(StubFileProvider()),
    Assert.True(IsObject(UiFileDialogs.provider)),
    UiFileDialogs.UseProvider(""),
    Assert.True(!IsObject(UiFileDialogs.provider)),
    Assert.True(UiFileDialogs._Provider() is UiFileDialogs.Real)))

TestRun.Finish()
