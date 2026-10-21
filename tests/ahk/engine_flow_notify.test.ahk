#Requires AutoHotkey v2.0
; Unit tests for the per-flow switch of the notices of unhandled exceptions (WI-0109, PROTOCOL 4.2 flow settings):
; src/engine/core/FlowNotify.ahk. The engine's use (the notice is sent or not, the copy of the variables is kept) is
; tests/integration/test_flow_settings.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\Json.ahk
#Include ..\..\src\engine\core\FlowNotify.ahk

NotTrue(v, msg := "") {
    Assert.True(!v, msg)
}

DefWithSettings(settings) {
    return {Raw: Map("flowSettings", settings)}
}

MissingKeyFollowsTheGlobalSetting() {
    Assert.True(FlowNotify.On(DefWithSettings(Map()), true), "missing key, global on")
    NotTrue(FlowNotify.On(DefWithSettings(Map()), false), "missing key, global off")
    Assert.True(FlowNotify.On({Raw: Map()}, true), "no flowSettings at all, global on")
}

DefaultWordFollowsTheGlobalSetting() {
    settings := Map("notifyUnhandledErrors", "default")
    Assert.True(FlowNotify.On(DefWithSettings(settings), true))
    NotTrue(FlowNotify.On(DefWithSettings(settings), false))
}

FlowValueOverridesTheGlobalSetting() {
    on := Map("notifyUnhandledErrors", Json.True)
    off := Map("notifyUnhandledErrors", Json.False)
    Assert.True(FlowNotify.On(DefWithSettings(on), false), "a flow that is on, global off")
    NotTrue(FlowNotify.On(DefWithSettings(off), true), "a flow that is off, global on: no notice")
}

FileFormsOfTheFlagAreRead() {
    Assert.True(FlowNotify.On(DefWithSettings(Map("notifyUnhandledErrors", 1)), false), "1 from the file")
    NotTrue(FlowNotify.On(DefWithSettings(Map("notifyUnhandledErrors", 0)), true), "0 from the file")
    Assert.True(FlowNotify.On(DefWithSettings(Map("notifyUnhandledErrors", "true")), false), "text true")
    NotTrue(FlowNotify.On(DefWithSettings(Map("notifyUnhandledErrors", "false")), true), "text false")
}

OtherValuesCountAsTheDefault() {
    Assert.True(FlowNotify.On(DefWithSettings(Map("notifyUnhandledErrors", "maybe")), true))
    NotTrue(FlowNotify.On(DefWithSettings(Map("notifyUnhandledErrors", "")), false))
}

TestRun.Case("A missing key takes the global setting", MissingKeyFollowsTheGlobalSetting)
TestRun.Case("The word default takes the global setting", DefaultWordFollowsTheGlobalSetting)
TestRun.Case("A flow value of true or false decides over the global setting", FlowValueOverridesTheGlobalSetting)
TestRun.Case("The flag is read as 1, 0, true or false as it comes from a file", FileFormsOfTheFlagAreRead)
TestRun.Case("Any other value counts as the default", OtherValuesCountAsTheDefault)

TestRun.Finish()
