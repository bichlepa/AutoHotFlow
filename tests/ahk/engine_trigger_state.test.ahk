#Requires AutoHotkey v2.0
; Unit tests of the target state of the triggers (WI-0060, E0056): FlowRecord (the switches, the derived state of the
; flow, the independent triggers), FlowDefinition.FollowsFlow (the key followsFlow) and the file text of a flow (the
; key enabled of a trigger is not written, E0058). Every transition is checked here; the same behaviour through the
; protocol: tests/integration/test_trigger_state.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\engine\core\FlowDefinition.ahk
#Include ..\..\src\engine\FlowRecord.ahk

; One trigger that follows the flow (t1, key missing), one independent (t2, followsFlow false), one that follows the
; flow written as a v1 number (t3, followsFlow 1), one trigger with the enabled key of a v1 file (t4), and an action.
Flow(extra := "") {
    text := '{"name":"x","flowSettings":{"ExecutionPolicy":"parallel"},"allElements":{'
        . '"t1":{"ID":"t1","type":"trigger","class":"Trigger_Manual","pars":{}},'
        . '"t2":{"ID":"t2","type":"trigger","class":"Trigger_Manual","followsFlow":false,"pars":{}},'
        . '"t3":{"ID":"t3","type":"trigger","class":"Trigger_Manual","followsFlow":1,"pars":{}},'
        . '"t4":{"ID":"t4","type":"trigger","class":"Trigger_Manual","enabled":1,"pars":{}},'
        . '"a1":{"ID":"a1","type":"action","class":"Action_Do_nothing","pars":{}}' extra
        . '},"allConnections":{}}'
    return FlowDefinition.FromText("f", text, 1)
}

Ids(arr) {
    s := ""
    for id in arr
        s .= id ","
    return s
}

; --- the switches ----------------------------------------------------------------------------------------------------

NewFlowHasNothingEnabled() {
    rec := FlowRecord("f", Flow())
    Assert.Equal(rec.IsFlowEnabled(), 0, "flow disabled")
    Assert.Equal(rec.IndependentActiveCount(), 0)
    Assert.Equal(Ids(rec.EnabledTriggers()), "")
    Assert.Equal(rec.TriggerEnabled("t1"), false, "a trigger starts disabled, also one with an enabled key (E0058)")
    Assert.Equal(rec.TriggerEnabled("t4"), false)
}

EnableFlowSwitchesTheFollowingTriggersOnly() {
    rec := FlowRecord("f", Flow())
    changed := rec.SetFollowingEnabled(true)
    Assert.Equal(Ids(changed), "t1,t3,t4,", "independent t2 and the action are not switched")
    Assert.True(rec.IsFlowEnabled(), "a following trigger is enabled: the flow is enabled")
    Assert.Equal(rec.IndependentActiveCount(), 0)
    Assert.Equal(Ids(rec.SetFollowingEnabled(true)), "", "a second enable changes nothing")
}

IndependentTriggerDoesNotMakeTheFlowActive() {
    rec := FlowRecord("f", Flow())
    Assert.True(rec.SetTriggerEnabled("t2", true), "t2 changed")
    Assert.Equal(rec.IsFlowEnabled(), 0, "only an independent trigger is enabled: the flow stays inactive")
    Assert.Equal(rec.IndependentActiveCount(), 1)
}

DisableFlowKeepsIndependentTriggers() {
    rec := FlowRecord("f", Flow())
    rec.SetFollowingEnabled(true)
    rec.SetTriggerEnabled("t2", true)
    Assert.Equal(Ids(rec.SetFollowingEnabled(false)), "t1,t3,t4,", "the following triggers only")
    Assert.Equal(rec.IsFlowEnabled(), 0)
    Assert.Equal(rec.IndependentActiveCount(), 1, "t2 stays enabled")
    Assert.Equal(Ids(rec.SetFollowingEnabled(false, true)), "t2,", "all: the independent trigger too")
    Assert.Equal(rec.IndependentActiveCount(), 0)
}

SingleTriggerSwitchChangesOnlyThatTrigger() {
    rec := FlowRecord("f", Flow())
    Assert.True(rec.SetTriggerEnabled("t1", true), "changed")
    Assert.Equal(Ids(rec.EnabledTriggers()), "t1,")
    Assert.Equal(rec.TriggerEnabled("t3"), false, "t3 untouched")
    Assert.Equal(rec.SetTriggerEnabled("t1", true), false, "no change when already enabled")
    Assert.True(rec.SetTriggerEnabled("t1", false), "changed back")
    Assert.Equal(rec.IsFlowEnabled(), 0)
    Assert.Equal(rec.SetTriggerEnabled("t1", false), false, "no change when already disabled")
}

NotATriggerIsNeverEnabled() {
    rec := FlowRecord("f", Flow())
    Assert.Equal(rec.SetTriggerEnabled("a1", true), false, "an action cannot be switched on")
    Assert.Equal(rec.TriggerEnabled("a1"), false, "an action is not a trigger")
    Assert.Equal(rec.TriggerEnabled("nope"), false, "an unknown ID is not a trigger")
    Assert.Equal(rec.LoadEnabledTriggers(["a1", "nope", "t1"]), 1, "only the trigger is taken from a file")
    Assert.Equal(Ids(rec.EnabledTriggers()), "t1,")
}

FlowWithoutFollowingTriggerSaysSo() {
    def := FlowDefinition.FromText("f", '{"name":"x","allElements":{'
        . '"t2":{"ID":"t2","type":"trigger","class":"Trigger_Manual","followsFlow":"false","pars":{}}},'
        . '"allConnections":{}}', 1)
    rec := FlowRecord("f", def)
    Assert.Equal(rec.HasFollowingTrigger(), false, "every trigger is independent")
    Assert.Equal(rec.SetFollowingEnabled(true).Length, 0, "nothing to switch")
    Assert.Equal(rec.SetFollowingEnabled(false).Length, 0, "nothing to switch")
    Assert.Equal(rec.SetFollowingEnabled(true, true).Length, 1, "all: the independent trigger is switched")
    Assert.Equal(rec.IsFlowEnabled(), 0)
    Assert.Equal(rec.IndependentActiveCount(), 1)
}

; The state is loaded from FlowState.json: the entries of the triggers of the flow, merged with what is set.
LoadedStateFromTheFileIsTakenAndMerged() {
    rec := FlowRecord("f", Flow())
    rec.SetTriggerEnabled("t3", true)
    Assert.Equal(rec.LoadEnabledTriggers(["t1", "t2"]), 2, "t3 was already set, so two are new")
    Assert.Equal(Ids(rec.EnabledTriggers()), "t1,t2,t3,")
    Assert.Equal(rec.IndependentActiveCount(), 1)
    Assert.True(rec.IsFlowEnabled())
}

; --- followsFlow -----------------------------------------------------------------------------------------------------

FollowsFlowReadsTheKey() {
    def := Flow(',"t5":{"ID":"t5","type":"trigger","class":"Trigger_Manual","followsFlow":0,"pars":{}}'
        . ',"t6":{"ID":"t6","type":"trigger","class":"Trigger_Manual","followsFlow":"0","pars":{}}'
        . ',"t7":{"ID":"t7","type":"trigger","class":"Trigger_Manual","followsFlow":"false","pars":{}}'
        . ',"t8":{"ID":"t8","type":"trigger","class":"Trigger_Manual","followsFlow":null,"pars":{}}'
        . ',"t9":{"ID":"t9","type":"trigger","class":"Trigger_Manual","followsFlow":true,"pars":{}}')
    Assert.Equal(def.FollowsFlow("t1"), true, "missing: follows")
    Assert.Equal(def.FollowsFlow("t2"), false, "false")
    Assert.Equal(def.FollowsFlow("t3"), true, "1")
    Assert.Equal(def.FollowsFlow("t4"), true, "the enabled key does not matter")
    Assert.Equal(def.FollowsFlow("t5"), false, "0")
    Assert.Equal(def.FollowsFlow("t6"), false, "text 0")
    Assert.Equal(def.FollowsFlow("t7"), false, "text false")
    Assert.Equal(def.FollowsFlow("t8"), true, "null: follows")
    Assert.Equal(def.FollowsFlow("t9"), true, "true")
    Assert.Equal(def.FollowsFlow("a1"), false, "an action does not follow the flow")
    Assert.Equal(def.FollowsFlow("nope"), false, "an unknown element does not follow the flow")
}

; --- the file text ---------------------------------------------------------------------------------------------------

; The file does not carry "enabled" at a trigger (E0058), keeps followsFlow as it is and the other keys.
FileTextDropsTheEnabledKeyOfTriggers() {
    def := Flow()
    text := def.ToFileText()
    back := Json.Parse(text)
    Assert.Equal(back["formatVersion"], 2)
    Assert.Equal(back["allElements"]["t4"].Has("enabled"), false, "the v1 enabled key is dropped")
    Assert.Equal(back["allElements"]["t2"]["followsFlow"], 0, "followsFlow is written back unchanged")
    Assert.Equal(back["allElements"]["a1"]["type"], "action")
    Assert.Equal(def.Raw["allElements"]["t4"].Has("enabled"), true, "Raw is not changed")
}

TestRun.Init()

TestRun.Case("Trigger state: a new flow has nothing enabled, a v1 enabled key does not count", NewFlowHasNothingEnabled)
TestRun.Case("Trigger state: enabling the flow switches the following triggers only", EnableFlowSwitchesTheFollowingTriggersOnly)
TestRun.Case("Trigger state: an enabled independent trigger does not make the flow active", IndependentTriggerDoesNotMakeTheFlowActive)
TestRun.Case("Trigger state: disabling the flow keeps the independent triggers, all takes them too", DisableFlowKeepsIndependentTriggers)
TestRun.Case("Trigger state: a single trigger switch changes only that trigger", SingleTriggerSwitchChangesOnlyThatTrigger)
TestRun.Case("Trigger state: an action or an unknown ID is never a trigger", NotATriggerIsNeverEnabled)
TestRun.Case("Trigger state: a flow without a following trigger has nothing to switch", FlowWithoutFollowingTriggerSaysSo)
TestRun.Case("Trigger state: the state from FlowState.json is merged into the flow", LoadedStateFromTheFileIsTakenAndMerged)
TestRun.Case("Trigger state: followsFlow is read as true or false, missing means true", FollowsFlowReadsTheKey)
TestRun.Case("Trigger state: the file text has no enabled key at a trigger and keeps followsFlow", FileTextDropsTheEnabledKeyOfTriggers)

TestRun.Finish()
