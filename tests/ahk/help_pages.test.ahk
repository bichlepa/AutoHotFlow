#Requires AutoHotkey v2.0
; Unit tests for the headless model of the help (WI-0111, PROTOCOL 4.12): the page IDs (src/core/HelpPageId.ahk), the element
; to page mapping, the file of a page in a language with the English fallback, the viewer of a setting, the file URL and the
; setting helpViewer (src/core/SettingsModel.ahk). No window and no COM.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\help\HelpPages.ahk

PageIdsAreChecked() {
    Assert.True(HelpPageId.IdOk(""), "the empty ID is the index")
    Assert.True(HelpPageId.IdOk("Welcome"))
    Assert.True(HelpPageId.IdOk("Actions/Sleep"))
    Assert.True(HelpPageId.IdOk("Loops/Work_through_a_list"))
    Assert.True(!HelpPageId.IdOk("Actions/Sleep/x"), "one slash at most")
    Assert.True(!HelpPageId.IdOk("../x"), "no path")
    Assert.True(!HelpPageId.IdOk("a b"), "no space")
    Assert.True(!HelpPageId.IdOk("/Sleep"), "no empty kind")
    Assert.True(!HelpPageId.IdOk(Map()), "not text")
    Assert.True(!HelpPageId.IdOk(StrRepeat("a", 81)), "at most 80 characters")
    Assert.True(HelpPageId.IdOk(StrRepeat("a", 80)))
}

StrRepeat(text, n) {
    out := ""
    loop n
        out .= text
    return out
}

ElementIdsFollowTheKind() {
    Assert.Equal(HelpPageId.ElementId("Action_Sleep"), "Actions/Sleep")
    Assert.Equal(HelpPageId.ElementId("Condition_NumberIs"), "Conditions/NumberIs")
    Assert.Equal(HelpPageId.ElementId("Loop_SimpleLoop"), "Loops/SimpleLoop")
    Assert.Equal(HelpPageId.ElementId("Trigger_Hotkey"), "Triggers/Hotkey")
    Assert.Equal(HelpPageId.ElementId("Action_Variable_content_is"), "Actions/Variable_content_is")
    Assert.Equal(HelpPageId.ElementId("Sleep"), "", "no kind prefix")
    Assert.Equal(HelpPageId.ElementId("Widget_Sleep"), "", "unknown kind")
}

ElementPageFileExists() {
    id := HelpPageId.ElementId("Action_Sleep")
    r := HelpPages.Resolve(id, "en")
    Assert.True(r["found"], "the page of Sleep exists")
    Assert.True(FileExist(r["path"]))
    Assert.True(InStr(r["path"], "\src\elements\Default\help\en\Actions\Sleep.html") > 0, r["path"])
}

PageInOtherLanguageFallsBackToEnglish() {
    r := HelpPages.Resolve("Actions/Sleep", "de")
    Assert.True(r["found"])
    Assert.Equal(r["language"], "en", "no German page yet: English")
    Assert.True(InStr(r["path"], "\help\en\") > 0)
}

IndexIsTheDefault() {
    r := HelpPages.Resolve("", "en")
    Assert.True(r["found"])
    Assert.True(InStr(r["path"], "\assets\help\en\Welcome.html") > 0, r["path"])
    Assert.Equal(HelpPages.Resolve("Welcome", "ru")["language"], "en")
}

MissingPageShowsTheIndex() {
    r := HelpPages.Resolve("Actions/No_such_element", "en")
    Assert.True(!r["found"], "the page does not exist")
    Assert.True(InStr(r["path"], "\assets\help\en\Welcome.html") > 0, "the index is the file shown")
}

ViewerOfTheSetting() {
    Assert.Equal(HelpPages.ViewerFor("auto")["viewer"], "classic", "no WebView2 in this version")
    Assert.Equal(HelpPages.ViewerFor("auto", true)["viewer"], "webview2")
    Assert.Equal(HelpPages.ViewerFor("classic", true)["viewer"], "classic")
    Assert.Equal(HelpPages.ViewerFor("browser", true)["viewer"], "browser")
    Assert.Equal(HelpPages.ViewerFor("webview2", true)["viewer"], "webview2")
    fb := HelpPages.ViewerFor("webview2")
    Assert.Equal(fb["viewer"], "classic", "webview2 falls back to the classic viewer")
    Assert.True(fb["fallback"], "and says so (the role logs it)")
    Assert.True(!HelpPages.ViewerFor("classic")["fallback"])
    Assert.Equal(HelpPages.ViewerFor("unknown")["viewer"], "classic", "an unknown value is auto")
}

FileUrlsEscapeSpaces() {
    Assert.Equal(HelpPages.Url("C:\some dir\help\Welcome.html"), "file:///C:/some%20dir/help/Welcome.html")
}

HelpViewerSettingIsChecked() {
    Assert.Equal(SettingsModel.Defaults()["helpViewer"], "auto")
    Assert.Equal(SettingsModel.Check("helpViewer", "Browser"), "browser", "enum values ignore case")
    Assert.Equal(SettingsModel.Check("helpViewer", "webview2"), "webview2")
    e := Assert.Throws(() => SettingsModel.Check("helpViewer", "edge"), AhfError)
    Assert.True(InStr(e.Message, "helpViewer") > 0, "the error names the key")
}

TestRun.Case("page IDs: the empty index, one kind folder, no path, at most 80 characters", PageIdsAreChecked)
TestRun.Case("the element class maps to its page ID by the kind", ElementIdsFollowTheKind)
TestRun.Case("an element page exists as generated HTML in the English folder", ElementPageFileExists)
TestRun.Case("a page in a language without the page falls back to English", PageInOtherLanguageFallsBackToEnglish)
TestRun.Case("the index is the English Welcome page", IndexIsTheDefault)
TestRun.Case("a missing page is shown as the index", MissingPageShowsTheIndex)
TestRun.Case("the viewer follows the setting, WebView2 falls back to classic", ViewerOfTheSetting)
TestRun.Case("file URLs escape spaces", FileUrlsEscapeSpaces)
TestRun.Case("the setting helpViewer is checked like the others", HelpViewerSettingIsChecked)

TestRun.Finish()
