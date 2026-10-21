#Requires AutoHotkey v2.0
; Unit tests of the flow settings dialog (WI-0109, REQ-EDT-140, src/editor/EditorFlowSettings.ahk): what the form reads from
; flowSettings (the engine's defaults for a missing key), the changes that OK sends (one flow.settings operation with the changed
; keys only), the checks (an invalid limit or own folder refuses OK, the switch of a migrated flow to strict warns), and the
; controller with a stub draft: OK commits once, Cancel and a refused OK send nothing, a second dialog is refused while one is
; open. The window is tests/ahk/editor_flow_settings_window.test.ahk. The draft and the engine are not started here.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\EditorFlowSettings.ahk

; A draft with the one method the dialog uses: Commit records the operations and answers ok.
class FlowSettingsDraft {
    __New(root) {
        this.root := root
        this.commits := []
    }

    Commit(ops, undoable := true, done := "") {
        this.commits.Push(ops)
        return Map("ok", true)
    }
}

; The model of the dialog in these tests: the draft and the notices.
class FlowSettingsModel {
    __New(root) {
        this.draft := FlowSettingsDraft(root)
        this.notices := []
    }

    Notice(textKey, args*) {
        this.notices.Push(textKey)
    }
}

NotTrue(v, msg := "") {
    Assert.True(!v, msg)
}

FlowRoot(settings) {
    return Map("name", "Test flow", "flowSettings", settings)
}

; The dialog over a flow with the given flowSettings (no window).
DialogOver(settings) {
    model := FlowSettingsModel(FlowRoot(settings))
    return {model: model, fs: EditorFlowSettings(model, "", "flow")}
}

ReadMissingKeysGiveTheEngineDefaults() {
    st := EditorFlowSettings.Read(Map())
    Assert.Equal(st["policy"], "default")
    Assert.Equal(st["useGlobalDir"], 1, "no own folder: the global one")
    Assert.Equal(st["strict"], 0, "missing strictTypes is the compatible mode of a migrated flow")
    Assert.Equal(st["limits"]["maxParallelInstances"], "default")
    Assert.Equal(st["notify"], "default")
}

ReadTheFlowValues() {
    settings := Map("ExecutionPolicy", "skip", "DefaultWorkingDir", Json.False, "WorkingDir", "C:\Work"
        , "strictTypes", Json.True, "maxParallelInstances", 0, "maxWaitingInstances", 5
        , "maxExecutionsPerMinute", "default", "notifyUnhandledErrors", Json.False)
    st := EditorFlowSettings.Read(settings)
    Assert.Equal(st["policy"], "skip")
    Assert.Equal(st["useGlobalDir"], 0)
    Assert.Equal(st["workingDir"], "C:\Work")
    Assert.Equal(st["strict"], 1)
    Assert.Equal(st["limits"]["maxParallelInstances"], "0", "0 is no limit")
    Assert.Equal(st["limits"]["maxWaitingInstances"], "5")
    Assert.Equal(st["limits"]["maxExecutionsPerMinute"], "default")
    Assert.Equal(st["notify"], "off")
}

OwnFolderIsUsedWhenTheFlagIsOffAndTheFolderIsSet() {
    Assert.Equal(EditorFlowSettings.Read(Map("WorkingDir", "D:\Own"))["useGlobalDir"], 0, "no flag, a folder: the own one")
    Assert.Equal(EditorFlowSettings.Read(Map("DefaultWorkingDir", Json.True, "WorkingDir", "D:\Own"))["useGlobalDir"], 1
        , "the flag is true: the global one, as the engine")
    Assert.Equal(EditorFlowSettings.Read(Map("DefaultWorkingDir", Json.False))["useGlobalDir"], 1, "an empty folder: the global one")
}

UnknownPolicyAndOddLimitsReadAsTheDefault() {
    st := EditorFlowSettings.Read(Map("ExecutionPolicy", "fast", "maxWaitingInstances", "-3", "maxParallelInstances", "x"))
    Assert.Equal(st["policy"], "default")
    Assert.Equal(st["limits"]["maxWaitingInstances"], "default", "a negative number is not a limit")
    Assert.Equal(st["limits"]["maxParallelInstances"], "default")
}

ChangesHoldOnlyTheChangedKeys() {
    initial := EditorFlowSettings.Read(Map())
    form := EditorFlowSettings.Copy(initial)
    form["policy"] := "wait"
    form["limits"]["maxParallelInstances"] := "0"
    form["strict"] := 1
    fields := EditorFlowSettings.Changes(initial, form)
    Assert.Equal(fields.Count, 3, "policy, limit and strictTypes")
    Assert.Equal(fields["ExecutionPolicy"], "wait")
    Assert.Equal(fields["maxParallelInstances"], 0, "a whole number")
    Assert.True(fields["strictTypes"] == Json.True, "a real JSON true")
}

ChangesWriteTheWordDefaultAndTheSwitches() {
    initial := EditorFlowSettings.Read(Map("maxExecutionsPerMinute", 100, "notifyUnhandledErrors", Json.True))
    form := EditorFlowSettings.Copy(initial)
    form["limits"]["maxExecutionsPerMinute"] := "default"
    form["notify"] := "off"
    form["useGlobalDir"] := 0
    form["workingDir"] := "E:\Flows"
    fields := EditorFlowSettings.Changes(initial, form)
    Assert.Equal(fields["maxExecutionsPerMinute"], "default")
    Assert.True(fields["notifyUnhandledErrors"] == Json.False, "off is JSON false")
    Assert.True(fields["DefaultWorkingDir"] == Json.False, "the own folder is JSON false in DefaultWorkingDir")
    Assert.Equal(fields["WorkingDir"], "E:\Flows")
    Assert.Equal(fields.Count, 4)
}

NothingChangedGivesNoKeys() {
    initial := EditorFlowSettings.Read(Map("ExecutionPolicy", "parallel", "maxParallelInstances", 100))
    Assert.Equal(EditorFlowSettings.Changes(initial, EditorFlowSettings.Copy(initial)).Count, 0)
}

ChecksRefuseABadLimitAndAnEmptyOwnFolder() {
    initial := EditorFlowSettings.Read(Map())
    form := EditorFlowSettings.Copy(initial)
    form["limits"]["maxWaitingInstances"] := "many"
    checks := EditorFlowSettings.Check(form, initial, false)
    Assert.Equal(checks["errors"].Length, 1, "the bad limit")
    form := EditorFlowSettings.Copy(initial)
    form["useGlobalDir"] := 0
    form["workingDir"] := ""
    checks := EditorFlowSettings.Check(form, initial, false)
    Assert.Equal(checks["errors"].Length, 1, "an empty own folder")
    form["workingDir"] := "relative\folder"
    Assert.Equal(EditorFlowSettings.Check(form, initial, false)["errors"].Length, 1, "a folder that is not absolute")
    form["workingDir"] := "C:\Ok"
    Assert.Equal(EditorFlowSettings.Check(form, initial, false)["errors"].Length, 0, "an absolute folder is fine")
}

StrictOnAMigratedFlowWarns() {
    initial := EditorFlowSettings.Read(Map())
    form := EditorFlowSettings.Copy(initial)
    form["strict"] := 1
    Assert.Equal(EditorFlowSettings.Check(form, initial, true)["warnings"].Length, 1, "migrated: a warning")
    Assert.Equal(EditorFlowSettings.Check(form, initial, false)["warnings"].Length, 0, "a flow with the key: no warning")
    Assert.Equal(EditorFlowSettings.Check(form, initial, true)["errors"].Length, 0, "a warning does not refuse OK")
}

MigratedIsAMissingStrictKey() {
    Assert.True(EditorFlowSettings.Migrated(Map()), "no key: migrated")
    Assert.True(EditorFlowSettings.Migrated(""), "no flowSettings: migrated")
    NotTrue(EditorFlowSettings.Migrated(Map("strictTypes", Json.False)), "a decided flow is not migrated")
}

OkCommitsOneOperationWithTheChanges() {
    d := DialogOver(Map("ExecutionPolicy", "parallel"))
    Assert.True(d.fs.Open(Map()), "the dialog opens")
    d.fs.Set("policy", "stop")
    d.fs.Set("strict", 1)
    res := d.fs.Ok()
    Assert.True(res["ok"] && res["changed"], "OK changes")
    Assert.Equal(d.model.draft.commits.Length, 1, "one patch")
    op := d.model.draft.commits[1][1]
    Assert.Equal(op["op"], "flow.settings")
    Assert.Equal(op["settings"]["ExecutionPolicy"], "stop")
    Assert.True(op["settings"]["strictTypes"] == Json.True)
    NotTrue(d.fs.Busy, "the dialog closes")
}

CancelSendsNothing() {
    d := DialogOver(Map())
    d.fs.Open(Map())
    d.fs.Set("policy", "skip")
    d.fs.Cancel()
    Assert.Equal(d.model.draft.commits.Length, 0)
    NotTrue(d.fs.Busy)
}

OkWithoutAChangeSendsNothing() {
    d := DialogOver(Map())
    d.fs.Open(Map())
    res := d.fs.Ok()
    Assert.True(res["ok"] && !res["changed"], "nothing changed")
    Assert.Equal(d.model.draft.commits.Length, 0)
}

RefusedOkKeepsTheDialogOpen() {
    d := DialogOver(Map())
    d.fs.Open(Map())
    d.fs.Set("limit:maxParallelInstances", "many")
    res := d.fs.Ok()
    NotTrue(res["ok"], "the bad limit is refused")
    Assert.Equal(res["code"], ErrCode.BAD_PAYLOAD)
    Assert.Equal(d.model.draft.commits.Length, 0, "nothing is sent")
    Assert.True(d.fs.Busy, "the dialog stays open to correct the value")
}

SecondDialogIsRefusedWhileOneIsOpen() {
    d := DialogOver(Map())
    d.fs.Open(Map())
    NotTrue(d.fs.Open(Map()), "a second dialog does not open")
    Assert.True(d.model.notices.Length = 1 && d.model.notices[1] = "Settings_busy", "the status bar says so")
}

SetRefusesAnUnknownField() {
    d := DialogOver(Map())
    d.fs.Open(Map())
    NotTrue(d.fs.Set("colour", "red"), "not a field of the form")
    NotTrue(d.fs.Set("limit:unknown", "3"), "not a limit")
    Assert.True(d.fs.Set("limit:maxExecutionsPerMinute", " 12 "), "a limit of a known key")
    Assert.Equal(d.fs.State()["limits"]["maxExecutionsPerMinute"], "12", "the text is trimmed and kept as a number")
}

StateShowsTheChangesAndTheChecks() {
    d := DialogOver(Map("ExecutionPolicy", "wait"))
    d.fs.Open(Map())
    st := d.fs.State()
    Assert.True(st["open"] == Json.True)
    Assert.Equal(st["name"], "Test flow")
    Assert.True(st["changed"] == Json.False, "nothing changed yet")
    d.fs.Set("notify", "on")
    st := d.fs.State()
    Assert.True(st["changed"] == Json.True, "a change shows")
    Assert.Equal(st["errors"].Length, 0)
}

TestRun.Init()

TestRun.Case("Flow settings: a missing key has the engine's default", ReadMissingKeysGiveTheEngineDefaults)
TestRun.Case("Flow settings: the flow's values are read as the engine reads them", ReadTheFlowValues)
TestRun.Case("Flow settings: the own folder is used when the flag is off and a folder is set", OwnFolderIsUsedWhenTheFlagIsOffAndTheFolderIsSet)
TestRun.Case("Flow settings: an unknown policy or an odd limit reads as the default", UnknownPolicyAndOddLimitsReadAsTheDefault)
TestRun.Case("Flow settings: OK sends only the keys that changed", ChangesHoldOnlyTheChangedKeys)
TestRun.Case("Flow settings: default is written as the word, the switches as JSON booleans", ChangesWriteTheWordDefaultAndTheSwitches)
TestRun.Case("Flow settings: nothing changed gives no keys", NothingChangedGivesNoKeys)
TestRun.Case("Flow settings: a bad limit or an own folder that is not valid refuses OK", ChecksRefuseABadLimitAndAnEmptyOwnFolder)
TestRun.Case("Flow settings: strict on a migrated flow warns, and the warning does not refuse", StrictOnAMigratedFlowWarns)
TestRun.Case("Flow settings: a flow without strictTypes is migrated", MigratedIsAMissingStrictKey)
TestRun.Case("Flow settings: OK sends one flow.settings operation with the changed keys", OkCommitsOneOperationWithTheChanges)
TestRun.Case("Flow settings: Cancel sends nothing", CancelSendsNothing)
TestRun.Case("Flow settings: OK without a change sends nothing", OkWithoutAChangeSendsNothing)
TestRun.Case("Flow settings: a refused OK keeps the dialog open and sends nothing", RefusedOkKeepsTheDialogOpen)
TestRun.Case("Flow settings: a second dialog is refused while one is open", SecondDialogIsRefusedWhileOneIsOpen)
TestRun.Case("Flow settings: Set refuses an unknown field and trims a limit", SetRefusesAnUnknownField)
TestRun.Case("Flow settings: the state shows the change and the checks", StateShowsTheChangesAndTheChecks)

TestRun.Finish()
