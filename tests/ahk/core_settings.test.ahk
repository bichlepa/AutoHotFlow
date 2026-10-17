#Requires AutoHotkey v2.0
; Unit tests for src/core/SettingsModel.ahk (WI-0077): the keys, the checks, the file text, the language, the settings of v1, and
; the per-group log thresholds of src/core/Log.ahk.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\SettingsModel.ahk
#Include ..\..\src\core\Log.ahk

; The AhfError that fn throws.
Thrown(fn) {
    e := Assert.Throws(fn, AhfError)
    return e
}

; Check(key, value) as a function with arguments: a closure over the variable of a for loop does not work in a test.
CheckOf(key, value) => SettingsModel.Check(key, value)

CheckDefaults() {
    d := SettingsModel.Defaults()
    Assert.Equal(d["language"], "")
    Assert.Equal(d["executionPolicy"], "parallel")
    Assert.Equal(d["workingDir"], A_MyDocuments "\AutoHotFlow")
    Assert.Equal(d["workers"], 8)
    Assert.Equal(d["logLevelApp"], 2)
    Assert.Equal(d["logLevelFlow"], 2)
    Assert.Equal(d["logLevelThread"], 2)
    Assert.Equal(d["maxExecutionsPerMinute"], 50000)
    Assert.Equal(d["maxWaitingInstances"], 100)
    Assert.Equal(d["maxParallelInstances"], 100)
    Assert.Equal(d["userLevel"], "Beginner")
    Assert.Equal(d["notifyUnhandledErrors"], 1)
    Assert.Equal(d["startWithWindows"], 0)
    Assert.Equal(d["runAsAdmin"], 0)
    Assert.Equal(d["windowPositions"].Count, 0)
    Assert.Equal(d.Count, SettingsModel.Keys().Length)
}

; The defaults of the limits are the numbers of the runaway guard (E0071); the built-in constants stay the fallback of the engine.
CheckKeysAreAllChecked() {
    for key in SettingsModel.Keys()
        Assert.True(SettingsModel.Has(key))
    Assert.True(!SettingsModel.Has("nonsense"))
    e := Thrown(() => SettingsModel.Check("nonsense", 1))
    Assert.Equal(e.code, "bad_payload")
    Assert.True(InStr(e.Message, "nonsense"))
}

CheckWorkersRange() {
    Assert.Equal(SettingsModel.Check("workers", 1), 1)
    Assert.Equal(SettingsModel.Check("workers", 16), 16)
    Assert.Equal(SettingsModel.Check("workers", "12"), 12)
    for bad in [0, 17, -1, "many", "", "3.5"] {
        e := Thrown(CheckOf.Bind("workers", bad))
        Assert.Equal(e.code, "bad_payload")
        Assert.True(InStr(e.Message, "workers"), "the message names the key")
    }
}

CheckLogLevels() {
    for key in ["logLevelApp", "logLevelFlow", "logLevelThread"] {
        Assert.Equal(SettingsModel.Check(key, 0), 0)
        Assert.Equal(SettingsModel.Check(key, 3), 3)
        Assert.Throws(CheckOf.Bind(key, 4), AhfError)
        Assert.Throws(CheckOf.Bind(key, -1), AhfError)
    }
}

CheckLimits() {
    for key in ["maxExecutionsPerMinute", "maxWaitingInstances", "maxParallelInstances"] {
        Assert.Equal(SettingsModel.Check(key, 0), 0, "0 means no limit")
        Assert.Equal(SettingsModel.Check(key, 250), 250)
        Assert.Throws(CheckOf.Bind(key, -1), AhfError)
        Assert.Throws(CheckOf.Bind(key, "default"), AhfError)
    }
}

CheckPolicy() {
    Assert.Equal(SettingsModel.Check("executionPolicy", "Skip"), "skip", "the spelling of the list")
    Assert.Equal(SettingsModel.Check("executionPolicy", "wait"), "wait")
    Assert.Throws(() => SettingsModel.Check("executionPolicy", "default"), AhfError)
    Assert.Throws(() => SettingsModel.Check("executionPolicy", ""), AhfError)
}

CheckUserLevel() {
    Assert.Equal(SettingsModel.Check("userLevel", "advanced"), "Advanced")
    Assert.Equal(SettingsModel.Check("userLevel", "Programmer"), "Programmer")
    Assert.Throws(() => SettingsModel.Check("userLevel", "Expert"), AhfError)
}

CheckBooleans() {
    Assert.Equal(SettingsModel.Check("runAsAdmin", Json.True), 1)
    Assert.Equal(SettingsModel.Check("runAsAdmin", Json.False), 0)
    Assert.Equal(SettingsModel.Check("runAsAdmin", 1), 1)
    Assert.Equal(SettingsModel.Check("runAsAdmin", "false"), 0)
    Assert.Throws(() => SettingsModel.Check("runAsAdmin", "maybe"), AhfError)
    Assert.Throws(() => SettingsModel.Check("notifyUnhandledErrors", 2), AhfError)
}

CheckWorkingDir() {
    Assert.Equal(SettingsModel.Check("workingDir", "D:\Flows"), "D:\Flows")
    Assert.Equal(SettingsModel.Check("workingDir", "D:\Flows\"), "D:\Flows", "no trailing backslash")
    Assert.Equal(SettingsModel.Check("workingDir", "D:\"), "D:\", "the root of a drive keeps it")
    Assert.Equal(SettingsModel.Check("workingDir", "\\server\share\x"), "\\server\share\x")
    for bad in ["", "relative\dir", "D:Flows", "D:\a|b", "D:\a?b", "D:\a*b", "\single"]
        Assert.Throws(CheckOf.Bind("workingDir", bad), AhfError, "refused: " bad)
}

CheckLanguage() {
    Assert.Equal(SettingsModel.Check("language", ""), "")
    Assert.Equal(SettingsModel.Check("language", "DE"), "de")
    Assert.Equal(SettingsModel.Check("language", " ru "), "ru")
    Assert.Throws(() => SettingsModel.Check("language", "german"), AhfError)
    Assert.Throws(() => SettingsModel.Check("language", "d"), AhfError)
}

CheckLanguageCode() {
    Assert.Equal(SettingsModel.LanguageCode("de", "0409"), "de", "the setting wins")
    Assert.Equal(SettingsModel.LanguageCode("", "0407"), "de", "German (Germany)")
    Assert.Equal(SettingsModel.LanguageCode("", "0C07"), "de", "German (Austria): the primary language counts")
    Assert.Equal(SettingsModel.LanguageCode("", "0409"), "en")
    Assert.Equal(SettingsModel.LanguageCode("", "0419"), "ru")
    Assert.Equal(SettingsModel.LanguageCode("", "0412"), "ko")
    Assert.Equal(SettingsModel.LanguageCode("", "040C"), "en", "a language without texts gets English")
    Assert.Equal(SettingsModel.LanguageCode("", "garbage"), "en")
}

CheckWindowPositions() {
    ok := Map("manager", Map("x", -10, "y", 20, "w", 800, "h", 600))
    Assert.Equal(SettingsModel.Check("windowPositions", ok)["manager"]["w"], 800)
    Assert.Throws(() => SettingsModel.Check("windowPositions", "x"), AhfError)
    Assert.Throws(() => SettingsModel.Check("windowPositions", Map("manager", Map("x", 1, "y", 2, "w", 3))), AhfError, "h is missing")
    Assert.Throws(() => SettingsModel.Check("windowPositions", Map("manager", Map("x", 1, "y", 2, "w", -3, "h", 4))), AhfError)
    Assert.Throws(() => SettingsModel.Check("windowPositions", Map("a\b", Map("x", 1, "y", 2, "w", 3, "h", 4))), AhfError)
}

CheckPartial() {
    checked := SettingsModel.CheckPartial(Map("workers", "4", "userLevel", "programmer"))
    Assert.Equal(checked["workers"], 4)
    Assert.Equal(checked["userLevel"], "Programmer")
    ; one bad key refuses the whole set and names the key
    e := Thrown(() => SettingsModel.CheckPartial(Map("workers", 4, "logLevelApp", 9)))
    Assert.Equal(e.code, "bad_payload")
    Assert.True(InStr(e.Message, "logLevelApp"))
    Assert.Throws(() => SettingsModel.CheckPartial("text"), AhfError)
}

CheckMergeKeepsTheRest() {
    current := SettingsModel.Defaults()
    merged := SettingsModel.Merge(current, Map("workers", 3))
    Assert.Equal(merged["workers"], 3)
    Assert.Equal(merged["userLevel"], "Beginner")
    Assert.Equal(current["workers"], 8, "the current set is not changed")
}

CheckNormalizeUsesDefaultsAndReports() {
    raw := Map("workers", 5, "logLevelApp", 7, "userLevel", "Advanced", "bogus", 1, "formatVersion", 1)
    values := SettingsModel.Normalize(raw, &problems)
    Assert.Equal(values["workers"], 5)
    Assert.Equal(values["logLevelApp"], 2, "an invalid value counts as the default")
    Assert.Equal(values["userLevel"], "Advanced")
    Assert.Equal(values["runAsAdmin"], 0, "a missing value counts as the default")
    kinds := Map()
    for p in problems
        kinds[p["kind"]] := true
    Assert.True(kinds.Has("invalid"))
    Assert.True(kinds.Has("missing"))
    Assert.True(kinds.Has("unknown"))
    hasApp := false
    for p in problems {
        if (p["key"] = "logLevelApp" && p["kind"] = "invalid")
            hasApp := true
    }
    Assert.True(hasApp, "the invalid key is named")
}

CheckNormalizeOfANonObject() {
    values := SettingsModel.Normalize("x", &problems)
    Assert.Equal(values["workers"], 8)
    Assert.Equal(problems.Length, 1)
}

CheckTextRoundTrip() {
    s := SettingsModel.Defaults()
    s["workers"] := 6
    s["runAsAdmin"] := 1
    s["language"] := "de"
    s["windowPositions"] := Map("manager", Map("x", 1, "y", 2, "w", 3, "h", 4))
    text := SettingsModel.ToText(s)
    Assert.True(InStr(text, '"formatVersion": 1'))
    Assert.True(InStr(text, '"runAsAdmin": true'), "truth values are written as JSON booleans")
    Assert.True(!InStr(text, '"runAsAdmin": 1'))
    back := SettingsModel.Normalize(SettingsModel.FromText(text), &problems)
    Assert.Equal(problems.Length, 0, "a file we wrote has no problems")
    Assert.Equal(back["workers"], 6)
    Assert.Equal(back["runAsAdmin"], 1)
    Assert.Equal(back["language"], "de")
    Assert.Equal(back["windowPositions"]["manager"]["h"], 4)
}

CheckFromTextRefusesBrokenFiles() {
    Assert.Throws(() => SettingsModel.FromText("{ broken"))
    Assert.Throws(() => SettingsModel.FromText("[1, 2]"), AhfError)
    Assert.Throws(() => SettingsModel.FromText('{"formatVersion": 99}'), AhfError)
    Assert.Equal(SettingsModel.FromText('{"workers": 2}')["workers"], 2, "a file without formatVersion is read")
}

CheckWireHasRealBooleans() {
    wire := SettingsModel.ToWire(SettingsModel.Defaults())
    Assert.True(wire["notifyUnhandledErrors"] == Json.True)
    Assert.True(wire["runAsAdmin"] == Json.False)
    Assert.Equal(wire["workers"], 8)
}

CheckFromV1() {
    v1 := Map("UILanguage", "ru", "runAsAdmin", 1, "FlowExecutionPolicy", "skip", "FlowWorkingDir", "E:\Work"
        , "HideDemoFlows", 1, "ShowElementsLevel", "Programmer", "LogLevelFlow", 1, "LogLevelApp", 3, "LogLevelThread", 0
        , "LogToFile", 1)
    r := SettingsModel.FromV1(v1)
    s := r["settings"]
    Assert.Equal(s["language"], "ru")
    Assert.Equal(s["executionPolicy"], "skip")
    Assert.Equal(s["workingDir"], "E:\Work")
    Assert.Equal(s["userLevel"], "Programmer")
    Assert.Equal(s["logLevelApp"], 3)
    Assert.Equal(s["logLevelFlow"], 1)
    Assert.Equal(s["logLevelThread"], 0)
    Assert.True(!s.Has("runAsAdmin"), "run as administrator is not taken over (E0068)")
    Assert.True(!s.Has("startWithWindows"))
    Assert.Equal(r["taken"].Length, 7)
    reasons := Map()
    for item in r["skipped"]
        reasons[item["v1"]] := item["reason"]
    Assert.Equal(reasons["runAsAdmin"], "not_taken")
    Assert.Equal(reasons["LogToFile"], "dropped", "E0069")
    Assert.Equal(reasons["HideDemoFlows"], "later")
}

CheckFromV1DoesNotTakeTheDefaultLanguage() {
    r := SettingsModel.FromV1(Map("UILanguage", "en", "LogLevelApp", 1))
    Assert.True(!r["settings"].Has("language"), "en is what v1 writes by default: the language of Windows stays")
    Assert.Equal(r["skipped"][1]["reason"], "default_language")
    Assert.Equal(r["settings"]["logLevelApp"], 1)
    Assert.Equal(SettingsModel.FromV1(Map("UILanguage", "EN"))["settings"].Count, 0)
}

CheckFromV1DropsInvalidValues() {
    r := SettingsModel.FromV1(Map("FlowExecutionPolicy", "sometimes", "FlowWorkingDir", "relative", "LogLevelApp", 2))
    Assert.Equal(r["settings"].Count, 1)
    Assert.Equal(r["settings"]["logLevelApp"], 2)
    Assert.Equal(r["skipped"].Length, 2)
    Assert.Equal(r["skipped"][1]["reason"], "invalid")
    Assert.Equal(SettingsModel.FromV1("nothing")["settings"].Count, 0)
}

ResetLog() {
    Log.Configure("")
    Log.memoryLines := []
    Log.ring := []
    Log.SetLevel(3)
}

CheckLogThresholdsPerGroup() {
    ResetLog()
    Log.Configure(Log.Memory)
    Log.SetLevels(0, 3, 1)
    Log.Write("a1", "x", "app 1")        ; app threshold 0: not written
    Log.Write("a0", "x", "app 0")
    Log.Write("f3", "x", "flow 3")       ; flow threshold 3
    Log.Write("t2", "x", "thread 2")     ; thread threshold 1: not written
    Log.Write("t1", "x", "thread 1")
    Log.Configure("")
    texts := ""
    for line in Log.memoryLines
        texts .= line["text"] ";"
    Assert.Equal(texts, "app 0;flow 3;thread 1;")
    Assert.Equal(Log.ring.Length, 5, "the ring keeps every level")
    Log.SetLevel(1)
    Assert.Equal(Log.LevelFor("f3"), 1, "SetLevel counts for all groups again")
}

TestRun.Init()

TestRun.Case("the defaults are the values of the decisions", CheckDefaults)
TestRun.Case("every key is known and an unknown key is bad_payload", CheckKeysAreAllChecked)
TestRun.Case("workers: 1 to 16 and the error names the key", CheckWorkersRange)
TestRun.Case("log levels: 0 to 3", CheckLogLevels)
TestRun.Case("limits: whole numbers from 0", CheckLimits)
TestRun.Case("execution policy: the four values, never default", CheckPolicy)
TestRun.Case("user level: the three levels", CheckUserLevel)
TestRun.Case("truth values are checked", CheckBooleans)
TestRun.Case("working directory: absolute path without forbidden characters", CheckWorkingDir)
TestRun.Case("language: empty or a code", CheckLanguage)
TestRun.Case("the language code follows the setting or Windows", CheckLanguageCode)
TestRun.Case("window positions are checked", CheckWindowPositions)
TestRun.Case("a partial set is checked as a whole", CheckPartial)
TestRun.Case("Merge applies the partial set and keeps the rest", CheckMergeKeepsTheRest)
TestRun.Case("Normalize uses the defaults and reports the problems", CheckNormalizeUsesDefaultsAndReports)
TestRun.Case("Normalize of something that is not an object", CheckNormalizeOfANonObject)
TestRun.Case("the file text round trip", CheckTextRoundTrip)
TestRun.Case("a broken file or an unknown format version is refused", CheckFromTextRefusesBrokenFiles)
TestRun.Case("the wire form has real JSON booleans", CheckWireHasRealBooleans)
TestRun.Case("the settings of v1 are taken over as E0068 says", CheckFromV1)
TestRun.Case("the v1 default language en is not taken over", CheckFromV1DoesNotTakeTheDefaultLanguage)
TestRun.Case("invalid settings of v1 are not taken over", CheckFromV1DropsInvalidValues)
TestRun.Case("the log thresholds are per source group", CheckLogThresholdsPerGroup)

TestRun.Finish()
