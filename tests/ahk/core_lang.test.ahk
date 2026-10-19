#Requires AutoHotkey v2.0
; Unit tests for src/core/Lang.ahk and LangTable.ahk (WI-0042, E0028, WI-0047): the v1 language files in assets/language
; and in the element packages (src/elements/<package>/language), read as v1 lang() reads them.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\Lang.ahk

Log.Configure(Log.Memory)

; dir: the language folders ("" = the files of the program); a test folder has no element packages unless packages
; names a folder (packages "" with dir "" = the packages of the program).
Reset(code := "en", dir := "", packages := "") {
    LangTable.Code := code
    LangTable.Dir := dir
    LangTable.PackagesDir := (packages != "") ? packages : (dir != "") ? dir "\no_packages" : ""
    LangTable.Load()
    Log.memoryLines := []
}

HasLog(level, part) {
    for line in Log.memoryLines {
        if (line["level"] = level && InStr(line["text"], part))
            return true
    }
    return false
}

; A folder with language files written by the test (A_Temp, removed at the end).
TempDir() {
    dir := A_Temp "\ahf_lang_test_" DllCall("GetCurrentProcessId")
    if (DirExist(dir))
        DirDelete(dir, true)
    DirCreate(dir "\basic")
    DirCreate(dir "\more")
    return dir
}

CheckEnglishText() {
    Reset()
    Assert.Equal(Lang("Cancel"), "Cancel")
    Assert.Equal(Lang("Parameter '%1%' is empty", "Duration"), "Parameter 'Duration' is empty")
    Assert.Equal(Log.memoryLines.Length, 0)
}

CheckUnderscoreIsASpace() {
    Reset()
    Assert.Equal(Lang("Show_log"), "Show log")
    Assert.Equal(Lang("line %1%, col %2%", 3, 14), "line 3, col 14")
}

; The trailing spaces of a value are not part of the text (the German v1 files have them, F-9003*).
CheckTrailingSpacesAreTrimmed() {
    dir := TempDir()
    DirCreate(dir "\basic")
    FileAppend("[common]`r`nSpaced=Flow-Einstellungen  `r`nTabbed=Text`t `r`n", dir "\basic\en.ini", "UTF-8-RAW")
    try {
        Reset("en", dir)
        Assert.Equal(Lang("Spaced"), "Flow-Einstellungen")
        Assert.Equal(Lang("Tabbed"), "Text")
    } finally {
        DirDelete(dir, true)
    }
}

CheckEveryPlaceholderIsReplaced() {
    dir := TempDir()
    FileAppend("[common]`r`nTwice=%1% and %1%, then %2%`r`n", dir "\basic\en.ini", "UTF-8-RAW")
    try {
        Reset("en", dir)
        Assert.Equal(Lang("Twice", "a", "b"), "a and a, then b")
        Assert.Equal(Lang("Twice", "a"), "a and a, then %2%")
    } finally {
        DirDelete(dir, true)
        Reset()
    }
}

CheckMissingKeyGivesTheKeyAndAnF3Entry() {
    Reset()
    Assert.Equal(Lang("No_such_text %1%", "x"), "No such text x")
    Assert.True(HasLog("f3", "No such text %1%"), "f3 entry for the missing key")
}

CheckEmptyKey() {
    Reset()
    Assert.Equal(Lang(""), "")
}

CheckGermanFileIsUtf16AndFallsBackToEnglish() {
    Reset("de")
    try {
        Assert.Equal(Lang("Cancel"), "Abbrechen")
        Assert.Equal(Lang("No_such_text"), "No such text")
    } finally {
        Reset()
    }
}

CheckLanguageInfoIsNotAText() {
    Reset()
    Assert.Equal(Lang("enname"), "enname")
}

CheckOtherFoldersAndFallback() {
    dir := TempDir()
    FileAppend("[language_info]`r`nenname=English`r`n[common]`r`nOnly English=only en`r`nBoth=both en`r`n", dir "\basic\en.ini", "UTF-8-RAW")
    FileAppend("[x]`r`nElement text=from the second folder`r`nBoth=replaced by the later folder`r`n", dir "\more\en.ini", "UTF-8-RAW")
    FileAppend("[common]`r`nBoth=beide`r`n", dir "\basic\de.ini", "UTF-16")
    try {
        Reset("en", dir)
        Assert.Equal(Lang("Element_text"), "from the second folder")
        Assert.Equal(Lang("Both"), "replaced by the later folder")
        Reset("de", dir)
        Assert.Equal(Lang("Both"), "beide")
        Assert.Equal(Lang("Only English"), "only en")
        Assert.Equal(Lang("Element text"), "from the second folder")
    } finally {
        DirDelete(dir, true)
        Reset()
    }
}

CheckTextsOfThePackageDefault() {
    ; keys that only the language files of the package Default have (v1/Source_Elements/Default/language, UTF-16)
    Reset()
    Assert.Equal(Lang("ms #Milliseconds"), "ms")
    Assert.Equal(Lang("Flow_control"), "Flow control")
    Assert.Equal(Lang("Sleep"), "Sleep")
    Assert.Equal(Log.memoryLines.Length, 0, "no key was missing")
    Reset("de")
    try {
        Assert.Equal(Lang("ms #Milliseconds"), "Ms")
        Assert.Equal(Lang("Sleep"), "Schlafen")
        Assert.Equal(Lang("Cancel"), "Abbrechen", "the texts of basic are still there")
    } finally {
        Reset()
    }
}

CheckPackageFoldersComeAfterTheProgramTexts() {
    dir := TempDir()
    DirCreate(dir "\packages\Pkg\language")
    DirCreate(dir "\packages\NoTexts")
    FileAppend("[common]`r`nBoth=from basic`r`nOnly basic=basic`r`n", dir "\basic\en.ini", "UTF-8-RAW")
    FileAppend("[Pkg]`r`nBoth=from the package`r`nPackage text=pkg`r`n", dir "\packages\Pkg\language\en.ini", "UTF-16")
    try {
        Reset("en", dir, dir "\packages")
        Assert.Equal(Lang("Package_text"), "pkg")
        Assert.Equal(Lang("Only basic"), "basic")
        Assert.Equal(Lang("Both"), "from the package", "a package comes after the program texts")
    } finally {
        DirDelete(dir, true)
        Reset()
    }
}

CheckMissingFolderGivesKeys() {
    Reset("en", A_Temp "\ahf_lang_no_such_folder")
    try {
        Assert.Equal(Lang("Cancel"), "Cancel")
        Assert.True(HasLog("f3", "Cancel"))
    } finally {
        Reset()
    }
}

TestRun.Init()

TestRun.Case("an English text is found, %1% is replaced", CheckEnglishText)
TestRun.Case("_ in a key is a space, as in v1", CheckUnderscoreIsASpace)
TestRun.Case("every occurrence of a placeholder is replaced; a missing argument leaves it", CheckEveryPlaceholderIsReplaced)
TestRun.Case("a missing key gives the key itself and an f3 log entry", CheckMissingKeyGivesTheKeyAndAnF3Entry)
TestRun.Case("an empty key gives the empty text", CheckEmptyKey)
TestRun.Case("trailing spaces of a value are not part of the text", CheckTrailingSpacesAreTrimmed)
TestRun.Case("the German file (UTF-16) is read; a missing German text falls back to English", CheckGermanFileIsUtf16AndFallsBackToEnglish)
TestRun.Case("the section language_info holds no texts", CheckLanguageInfoIsNotAText)
TestRun.Case("texts of further folders are read; a later folder replaces a text; fallback per key", CheckOtherFoldersAndFallback)
TestRun.Case("without language files every key gives itself", CheckMissingFolderGivesKeys)
TestRun.Case("the texts of the package Default are found (WI-0047)", CheckTextsOfThePackageDefault)
TestRun.Case("the language folders of the packages are read after the program texts", CheckPackageFoldersComeAfterTheProgramTexts)

CheckArgumentTextIsNotReplacedAgain() {
    Assert.Equal(LangTable.Fill("A %1% B %2%", ["%2%", "x"]), "A %2% B x", "an argument with a placeholder stays as it is")
    Assert.Equal(LangTable.Fill("%2% and %1%", ["a", "b"]), "b and a", "the order of the placeholders does not matter")
    Assert.Equal(LangTable.Fill("%1% %3%", ["a"]), "a %3%", "a missing argument leaves its placeholder")
    Assert.Equal(LangTable.Fill("%1%%1%", ["ab"]), "abab", "every occurrence is replaced")
}

TestRun.Case("an argument text with a placeholder is not replaced again; substitution is one pass", CheckArgumentTextIsNotReplacedAgain)

TestRun.Finish()
