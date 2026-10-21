#Requires AutoHotkey v2.0
; Unit tests of the flow settings window (WI-0109, src/editor/form/FlowSettingsWindow.ahk): the window is built for a dialog of
; the controller (EditorFlowSettings) WITHOUT showing it (Build with show false). The controls must show the values of the
; flow and of the form after a change; a refused check shows its text. The gui of the window is tests/fault (owner).
; Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\EditorFlowSettings.ahk
#Include ..\..\src\editor\form\FlowSettingsWindow.ahk

class FlowSettingsDraft {
    __New(root) {
        this.root := root
    }

    Commit(ops, undoable := true, done := "") {
        return Map("ok", true)
    }
}

class FlowSettingsModel {
    __New(root) {
        this.draft := FlowSettingsDraft(root)
    }

    Notice(textKey, args*) {
    }
}

; A dialog over a flow with the given flowSettings and the global settings (no window is shown).
OpenDialog(settings, globals) {
    model := FlowSettingsModel(Map("name", "Window flow", "flowSettings", settings))
    fs := EditorFlowSettings(model, "", "flow")
    fs.Open(globals)
    return fs
}

WindowShowsTheValuesOfTheFlow() {
    fs := OpenDialog(Map("ExecutionPolicy", "skip", "DefaultWorkingDir", Json.False, "WorkingDir", "C:\Own"
        , "strictTypes", Json.True, "maxParallelInstances", 3, "notifyUnhandledErrors", Json.True)
        , Map("executionPolicy", "parallel", "notifyUnhandledErrors", 1))
    w := FlowSettingsWindow(0)
    w.Build(fs, "", false)
    Assert.Equal(w.policyBox.Value, 3, "skip is the third entry: default, parallel, skip")
    Assert.Equal(w.globalBox.Value, 0, "the flow has its own folder")
    Assert.Equal(w.ownEd.Value, "C:\Own")
    Assert.Equal(w.strictCb.Value, 1)
    Assert.Equal(w.limitEds["maxParallelInstances"].Value, "3")
    Assert.Equal(w.limitEds["maxWaitingInstances"].Value, "default")
    Assert.Equal(w.notifyBox.Value, 2, "on is the second entry: the global setting, on, off")
    w.Hide()
}

WindowFollowsTheFormAfterAChange() {
    fs := OpenDialog(Map(), Map("executionPolicy", "parallel"))
    w := FlowSettingsWindow(0)
    w.Build(fs, "", false)
    Assert.Equal(w.policyBox.Value, 1, "a new flow follows the global setting")
    fs.Set("policy", "stop")
    fs.Set("strict", 1)
    w.Sync()
    Assert.Equal(w.policyBox.Value, 5, "stop is the fifth entry")
    Assert.Equal(w.strictCb.Value, 1)
    Assert.Equal(w.globalBox.Value, 1, "no own folder: the global one")
    w.Hide()
}

WindowShowsARefusedCheck() {
    fs := OpenDialog(Map(), Map())
    w := FlowSettingsWindow(0)
    w.Build(fs, "", false)
    Assert.Equal(w.msgText.Text, "", "no text while everything is fine")
    fs.Set("limit:maxWaitingInstances", "many")
    w.Sync()
    Assert.True(w.msgText.Text != "", "the bad limit is shown")
    fs.Ok()
    Assert.True(fs.Busy, "OK refused: the dialog stays open")
    w.Hide()
}

WindowShowsTheWarningOfAMigratedFlow() {
    fs := OpenDialog(Map(), Map())
    w := FlowSettingsWindow(0)
    w.Build(fs, "", false)
    fs.Set("strict", 1)
    w.Sync()
    Assert.True(w.msgText.Text != "", "strict on a migrated flow shows its warning")
    w.Hide()
}

TestRun.Init()

TestRun.Case("Flow settings window: the controls show the values of the flow", WindowShowsTheValuesOfTheFlow)
TestRun.Case("Flow settings window: the controls follow the form after a change", WindowFollowsTheFormAfterAChange)
TestRun.Case("Flow settings window: a refused check is shown and OK keeps the dialog open", WindowShowsARefusedCheck)
TestRun.Case("Flow settings window: the warning of a migrated flow is shown", WindowShowsTheWarningOfAMigratedFlow)

TestRun.Finish()
