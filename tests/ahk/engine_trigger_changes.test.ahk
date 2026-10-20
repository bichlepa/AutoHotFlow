#Requires AutoHotkey v2.0
; Unit tests of the trigger changes of a patch (WI-0094, PROTOCOL 4.2): TriggerChanges.Diff tells which trigger of two
; definitions of one flow was added, removed or changed. The effects (arming, enabled state, events) are checked through
; the protocol: tests/integration/test_flow_patch_triggers.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\engine\core\FlowDefinition.ahk
#Include ..\..\src\engine\TriggerChanges.ahk

; Flow(): a periodic timer t1 (follows the flow) and a manual trigger t2 that does not follow it (followsFlow false),
; plus an action a1. The arguments change t1: its interval, its class, its position, its package ("" means no package
; key), an extra key of t1 and extra elements (JSON text, each with its leading comma).
Flow(interval := "200", cls := "Trigger_Periodic_Timer", x := "0", package := "Default", t1Extra := "", extra := "") {
    pkg := (package = "") ? "" : ',"package":"' package '"'
    text := '{"name":"x","allElements":{'
        . '"t1":{"ID":"t1","type":"trigger","class":"' cls '"' pkg ',"x":"' x '","name":"first"'
        . ',"pars":{"Interval":"' interval '","Unit":"MilliSeconds"}' t1Extra '},'
        . '"t2":{"ID":"t2","type":"trigger","class":"Trigger_Manual","followsFlow":false,"pars":{}},'
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

; --- what does not count -----------------------------------------------------------------------------------------------

MovingAndRenamingAreNoChange() {
    d := TriggerChanges.Diff(Flow(), Flow("200", "Trigger_Periodic_Timer", "77"))
    Assert.Equal(Ids(d["added"]) Ids(d["removed"]) Ids(d["changed"]), "", "a position alone is no change")
    d := TriggerChanges.Diff(Flow(), Flow("200", "Trigger_Periodic_Timer", "0", "Default", ',"StandardName":"9"'))
    Assert.Equal(Ids(d["changed"]), "", "StandardName alone is no change")
}

AnActionIsNoTriggerChange() {
    extra := ',"a2":{"ID":"a2","type":"action","class":"Action_Do_nothing","pars":{}}'
    d := TriggerChanges.Diff(Flow(), Flow("200", "Trigger_Periodic_Timer", "0", "Default", "", extra))
    Assert.Equal(Ids(d["added"]) Ids(d["removed"]) Ids(d["changed"]), "", "an added action is no trigger change")
}

AMissingPackageIsDefault() {
    d := TriggerChanges.Diff(Flow("200", "Trigger_Periodic_Timer", "0", ""), Flow("200", "Trigger_Periodic_Timer", "0", "Default"))
    Assert.Equal(Ids(d["changed"]), "", "a missing package is Default (E0045)")
}

; --- changes ---------------------------------------------------------------------------------------------------------

ChangedIntervalIsAChange() {
    d := TriggerChanges.Diff(Flow(), Flow("1000"))
    Assert.Equal(Ids(d["changed"]), "t1,", "the parameter Interval changed")
    Assert.Equal(Ids(d["added"]) Ids(d["removed"]), "", "no trigger was added or removed")
}

ParameterTextIsComparedWithItsCase() {
    d := TriggerChanges.Diff(Flow("abc"), Flow("ABC"))
    Assert.Equal(Ids(d["changed"]), "t1,", "'abc' and 'ABC' are different parameters")
}

ChangedClassIsAChange() {
    d := TriggerChanges.Diff(Flow(), Flow("200", "Trigger_Start_up"))
    Assert.Equal(Ids(d["changed"]), "t1,", "another class is another element")
}

ChangedPackageIsAChange() {
    d := TriggerChanges.Diff(Flow(), Flow("200", "Trigger_Periodic_Timer", "0", "Test"))
    Assert.Equal(Ids(d["changed"]), "t1,", "another package is another element (E0045)")
}

ChangedFollowsFlowIsAChange() {
    d := TriggerChanges.Diff(Flow(), Flow("200", "Trigger_Periodic_Timer", "0", "Default", ',"followsFlow":false'))
    Assert.Equal(Ids(d["changed"]), "t1,", "followsFlow changed from the default to false")
}

AddedAndRemovedTriggers() {
    before := Flow()
    after := FlowDefinition.FromText("f", '{"name":"x","allElements":{'
        . '"t1":{"ID":"t1","type":"trigger","class":"Trigger_Periodic_Timer","pars":{"Interval":"200","Unit":"MilliSeconds"}},'
        . '"t3":{"ID":"t3","type":"trigger","class":"Trigger_Manual","pars":{}},'
        . '"a1":{"ID":"a1","type":"action","class":"Action_Do_nothing","pars":{}}},"allConnections":{}}', 1)
    d := TriggerChanges.Diff(before, after)
    Assert.Equal(Ids(d["added"]), "t3,", "t3 is new")
    Assert.Equal(Ids(d["removed"]), "t2,", "t2 is gone")
    Assert.Equal(Ids(d["changed"]), "", "t1 has the same parameters, class, package and followsFlow")
}

ElementThatStopsBeingATriggerIsRemoved() {
    after := FlowDefinition.FromText("f", '{"name":"x","allElements":{'
        . '"t1":{"ID":"t1","type":"trigger","class":"Trigger_Periodic_Timer","pars":{"Interval":"200","Unit":"MilliSeconds"}},'
        . '"t2":{"ID":"t2","type":"action","class":"Action_Do_nothing","pars":{}},'
        . '"a1":{"ID":"a1","type":"action","class":"Action_Do_nothing","pars":{}}},"allConnections":{}}', 1)
    d := TriggerChanges.Diff(Flow(), after)
    Assert.Equal(Ids(d["removed"]), "t2,", "t2 is an action now")
}

; --- run ---------------------------------------------------------------------------------------------------------------

TestRun.Init()

TestRun.Case("Trigger changes: a position or a StandardName is no change", MovingAndRenamingAreNoChange)
TestRun.Case("Trigger changes: an action is no trigger change", AnActionIsNoTriggerChange)
TestRun.Case("Trigger changes: a missing package is Default", AMissingPackageIsDefault)
TestRun.Case("Trigger changes: a changed parameter is a change", ChangedIntervalIsAChange)
TestRun.Case("Trigger changes: parameter texts are compared with their case", ParameterTextIsComparedWithItsCase)
TestRun.Case("Trigger changes: a changed class is a change", ChangedClassIsAChange)
TestRun.Case("Trigger changes: a changed package is a change", ChangedPackageIsAChange)
TestRun.Case("Trigger changes: a changed followsFlow is a change", ChangedFollowsFlowIsAChange)
TestRun.Case("Trigger changes: added and removed triggers", AddedAndRemovedTriggers)
TestRun.Case("Trigger changes: an element that is no longer a trigger counts as removed", ElementThatStopsBeingATriggerIsRemoved)

TestRun.Finish()
