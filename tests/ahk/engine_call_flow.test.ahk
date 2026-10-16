#Requires AutoHotkey v2.0
; Unit tests of the flow calls (WI-0055, doc/ELEMENT-API-V2.md section 3, ARCHITECTURE 4.4): Executor.CallFlow, the end
; of a called instance as data, the cancel of a waiting call, the depth limit and the refused wait of the policy wait;
; and the three elements Action_Execute_Flow, Action_Stop_Flow and Condition_Flow_Running in the Executor with the
; stand-in owner (helpers/ExecutorKit.ahk). The same cases with real processes: tests/integration/test_core_d_flows.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include helpers\ExecutorKit.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk

; --- flows ---------------------------------------------------------------------------------------------------------
; A flow in the new format (no conversion) in strict mode, with the manual trigger t0 that is the default trigger.
CallText(elements, connections, policy := "default") {
    els := '"t0":{"ID":"t0","type":"trigger","class":"Trigger_Manual","DefaultTrigger":"1","pars":{"ID":"t0"}}'
    for e in elements
        els .= "," e
    cons := ""
    for c in connections
        cons .= (cons = "" ? "" : ",") c
    return '{"formatVersion":2,"name":"x","flowSettings":{"ExecutionPolicy":"' policy '","strictTypes":true},'
        . '"allElements":{' els '},"allConnections":{' cons '}}'
}

; The parameters of Action_Execute_Flow as JSON: target "" = this flow; trigger "" = the default trigger.
ExecPars(target := "", trigger := "", wait := 0, send := 1, ret := 0, skip := 0) {
    return '{"ThisFlow":' (target = "" ? 1 : 0) ',"flowID":"' target '","WhichTrigger":"' (trigger = "" ? "Default"
        : "Specified") '","triggerID":"' trigger '","SendLocalVars":' send ',"WaitToFinish":' wait ',"ReturnVariables":'
        . ret ',"SkipDisabled":' skip '}'
}

Exec(id, pars) => El(id, "Action_Execute_Flow", pars)
Cnt(id) => El(id, "ExecKit.Test_Count")
Hold(id) => El(id, "ExecKit.Test_Hold")
SetVar(id, name, expr) => El(id, "Action_New_variable", '{"Varname":"' name '","VarValue":"' expr '","expression":"Expression"}')
CondEl(id, expr) => El(id, "Condition_Expression", '{"Expression":"' expr '"}')

; An owner with the flows of the Map flows (flow ID -> text), every flow enabled (a trigger is enabled when its flow is).
Owners(flows) {
    Probe.Reset()
    Log.memoryLines := []
    owner := EngineOwner()
    for flowId, text in flows {
        owner.flows.Load(flowId, text)
        owner.flows.Get(flowId).Enabled := true
    }
    return owner
}

; Ticks until no flow of the owner executes (or n ticks).
DriveAll(owner, n := 400) {
    loop n {
        owner.Drive()
        busy := false
        for rec in owner.flows.All() {
            if (owner.executor.IsExecuting(rec.FlowId))
                busy := true
        }
        if (!busy)
            return
    }
}

; The evt.instance.ended payloads of a flow, in order.
EndsOf(owner, flowId) {
    out := []
    for ev in owner.events {
        if (ev["type"] = "evt.instance.ended" && ev["payload"]["flowId"] = flowId)
            out.Push(ev["payload"])
    }
    return out
}

; The last evt.element.state of an element of a flow: "state" or "state: message".
LastState(owner, flowId, elementId) {
    last := ""
    for ev in owner.events {
        p := ev["payload"]
        if (ev["type"] = "evt.element.state" && p["flowId"] = flowId && p["elementId"] = elementId)
            last := p["state"] (p.Has("message") ? ": " p["message"] : "")
    }
    return last
}

Reasons(ends) {
    out := ""
    for p in ends
        out .= (out = "" ? "" : ",") p["reason"]
    return out
}

; f: t0 -> E (Execute_Flow with pars) -> z ; g: t0 -> H (held until released)
CallerAndHeldCallee(pars, gPolicy := "default") {
    return Owners(Map("f", CallText([Exec("E", pars), Cnt("z")], [Conn("c1", "t0", "E"), Conn("c2", "E", "z")])
        , "g", CallText([Hold("H")], [Conn("c1", "t0", "H")], gPolicy)))
}

; --- waiting and not waiting ----------------------------------------------------------------------------------------
WaitingCallFinishesWhenTheCalledInstanceEnds() {
    owner := CallerAndHeldCallee(ExecPars("g", "t0", 1))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(LastState(owner, "f", "E"), "running", "the element waits")
    Assert.True(Probe.held.Has("H"), "the called flow runs")
    Assert.Equal(Probe.Count("z"), 0, "nothing behind the waiting element ran")
    Probe.Release("H")
    DriveAll(owner)
    Assert.Equal(LastState(owner, "f", "E"), "finished")
    Assert.Equal(Probe.Count("z"), 1)
    Assert.Equal(Reasons(EndsOf(owner, "g")) "/" Reasons(EndsOf(owner, "f")), "finished/finished")
}

NotWaitingCallFinishesAtOnce() {
    owner := CallerAndHeldCallee(ExecPars("g", "t0", 0))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(Probe.Count("z"), 1, "the element finished at once")
    Assert.Equal(Reasons(EndsOf(owner, "f")), "finished")
    Assert.True(owner.executor.IsExecuting("g"), "the called flow runs on")
    Probe.Release("H")
    DriveAll(owner)
    Assert.Equal(Reasons(EndsOf(owner, "g")), "finished")
}

; A third flow runs while an element waits for a called flow: nothing in the engine waits.
AThirdFlowRunsWhileTheCallerWaits() {
    owner := CallerAndHeldCallee(ExecPars("g", "t0", 1))
    owner.flows.Load("h", CallText([Cnt("a"), Cnt("b")], [Conn("c1", "t0", "a"), Conn("c2", "a", "b")]))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    owner.executor.StartFlow(owner.flows.Get("h"))
    owner.Drive()
    Assert.Equal(Reasons(EndsOf(owner, "h")), "finished", "h ran to its end")
    Assert.Equal(Probe.Count("b"), 1)
    Assert.Equal(LastState(owner, "f", "E"), "running", "f still waits")
    Probe.Release("H")
    DriveAll(owner)
    Assert.Equal(Reasons(EndsOf(owner, "f")), "finished")
}

; --- variables -------------------------------------------------------------------------------------------------------
; f sets x := 1, calls g (which sets y := x + 1 and x := 10), and gets the variables back when ret is 1.
VarsFlows(send, ret) {
    return Owners(Map("f", CallText([SetVar("s", "x", "1"), Exec("E", ExecPars("g", "t0", 1, send, ret)), Cnt("z")]
        , [Conn("c1", "t0", "s"), Conn("c2", "s", "E"), Conn("c3", "E", "z")])
        , "g", CallText([SetVar("a", "y", "x + 1"), SetVar("b", "x", "10")], [Conn("c1", "t0", "a"), Conn("c2", "a", "b")])))
}

VarsAreSentAndReturned() {
    seen := Map()
    owner := VarsFlows(1, 1)
    Probe.onRun := (ctx) => (ctx.elementId = "z") ? (seen["x"] := ctx.GetVar("x"), seen["y"] := ctx.GetVar("y", "-")) : ""
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    Assert.Equal(Reasons(EndsOf(owner, "g")) "/" Reasons(EndsOf(owner, "f")), "finished/finished")
    Assert.Equal(seen["y"], 2, "g saw x = 1 and its y came back")
    Assert.Equal(seen["x"], 10, "the returned x overwrote the own one")
}

VarsAreNotReturnedWithoutTheOption() {
    seen := Map()
    owner := VarsFlows(1, 0)
    Probe.onRun := (ctx) => (ctx.elementId = "z") ? (seen["x"] := ctx.GetVar("x"), seen["y"] := ctx.GetVar("y", "-")) : ""
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    Assert.Equal(seen["y"], "-")
    Assert.Equal(seen["x"], 1)
}

VarsAreNotSentWithoutTheOption() {
    owner := VarsFlows(0, 1)
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    ; g computes x + 1 with a missing x: a type error in strict mode, so g ends with an exception and so does E
    Assert.Equal(Reasons(EndsOf(owner, "g")), "exception")
    Assert.True(InStr(LastState(owner, "f", "E"), "exception: The called flow 'g' ended with an exception: element 'a': ")
        , LastState(owner, "f", "E"))
}

CallFlowSetsTheInstanceVariablesAndGivesTheOutcomeAsData() {
    owner := Owners(Map("g", CallText([SetVar("a", "y", "x * 2")], [Conn("c1", "t0", "a")])))
    got := []
    res := owner.executor.CallFlow("g", "t0", Map("vars", Map("x", 21, "bad.name", 1), "onEnd", (o) => got.Push(o)
        , "withVars", true))
    Assert.Equal(res["waiting"], 0)
    DriveAll(owner)
    Assert.Equal(got.Length, 1, "onEnd once")
    o := got[1]
    Assert.Equal(o["result"] "/" o["reason"] "/" o["message"], "normal/finished/")
    Assert.Equal(o["instanceId"], res["instanceId"])
    Assert.Equal(o["vars"]["y"], 42)
    Assert.Equal(o["vars"].Has("bad.name"), false, "a name with a forbidden character is skipped")
    Assert.True(HasLog("f0", "Setting variable 'bad.name' failed"))
}

; --- triggers --------------------------------------------------------------------------------------------------------
TriggerFlows(gText, pars) {
    return Owners(Map("f", CallText([Exec("E", pars)], [Conn("c1", "t0", "E")]), "g", gText))
}

ExecOnce(owner) {
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    return LastState(owner, "f", "E")
}

TheDefaultTriggerAndASpecifiedTrigger() {
    two := '{"formatVersion":2,"name":"g","flowSettings":{"strictTypes":true},"allElements":{'
        . '"t1":{"ID":"t1","type":"trigger","class":"Trigger_Manual","DefaultTrigger":"0","pars":{}},'
        . '"t2":{"ID":"t2","type":"trigger","class":"trigger_manual","DefaultTrigger":1,"pars":{}},' Cnt("a") ',' Cnt("b")
        . '},"allConnections":{' Conn("c1", "t1", "a") ',' Conn("c2", "t2", "b") '}}'
    owner := TriggerFlows(two, ExecPars("g", "", 1))
    Assert.Equal(ExecOnce(owner), "finished")
    Assert.Equal(Probe.Count("a") "/" Probe.Count("b"), "0/1", "the default trigger is t2")
    owner := TriggerFlows(two, ExecPars("g", "t1", 1))
    Assert.Equal(ExecOnce(owner), "finished")
    Assert.Equal(Probe.Count("a") "/" Probe.Count("b"), "1/0", "the specified trigger t1")
}

TriggerErrors() {
    noDefault := '{"formatVersion":2,"name":"g","flowSettings":{"strictTypes":true},"allElements":{'
        . '"t1":{"ID":"t1","type":"trigger","class":"Trigger_Manual","pars":{}},' Cnt("a") '},"allConnections":{}}'
    Assert.Equal(ExecOnce(TriggerFlows(noDefault, ExecPars("g", "", 1)))
        , "exception: Flow 'g' does not have any manual trigger.")
    Assert.Equal(ExecOnce(TriggerFlows(noDefault, ExecPars("g", "nothere", 1)))
        , "exception: Flow 'g' does not have the trigger with ID 'nothere'.")
    Assert.Equal(ExecOnce(TriggerFlows(noDefault, ExecPars("g", "a", 1)))
        , "exception: Flow 'g' does not have the trigger with ID 'a'.", "an action is no trigger")
    pars := '{"ThisFlow":0,"flowID":"g","WhichTrigger":"Specified","triggerID":""}'
    Assert.Equal(ExecOnce(TriggerFlows(noDefault, pars)), "exception: Trigger ID is empty")
    pars := '{"ThisFlow":0,"flowID":"g","WhichTrigger":"other"}'
    Assert.Equal(ExecOnce(TriggerFlows(noDefault, pars)), "exception: Unexpected error! Parameter 'WhichTrigger' is invalid.")
}

TheIndexOfTheChoiceIsAccepted() {
    Assert.Equal(Action_Execute_Flow_WhichOf(1), "default")
    Assert.Equal(Action_Execute_Flow_WhichOf("2"), "specified")
    Assert.Equal(Action_Execute_Flow_WhichOf("specified"), "specified")
    Assert.Equal(Action_Execute_Flow_WhichOf("DEFAULT"), "default")
    Assert.Equal(Action_Execute_Flow_WhichOf("3"), "")
}
Action_Execute_Flow_WhichOf(v) => Default.Action_Execute_Flow.WhichOf(v)

; --- disabled, missing -----------------------------------------------------------------------------------------------
DisabledFlowWithAndWithoutSkip() {
    owner := CallerAndHeldCallee(ExecPars("g", "t0", 1))
    owner.flows.Get("g").Enabled := false
    Assert.Equal(ExecOnce(owner), "exception: Trigger 't0' in 'g' is disabled")
    Assert.Equal(EndsOf(owner, "g").Length, 0, "g did not start")
    owner := CallerAndHeldCallee(ExecPars("g", "t0", 1, 1, 0, 1))
    owner.flows.Get("g").Enabled := false
    Assert.Equal(ExecOnce(owner), "finished", "skipped without error")
    Assert.Equal(Probe.Count("z"), 1)
    Assert.Equal(EndsOf(owner, "g").Length, 0, "g did not start")
}

MissingFlow() {
    owner := CallerAndHeldCallee(ExecPars("nothere", "t0", 1))
    Assert.Equal(ExecOnce(owner), "exception: Flow 'nothere' does not exist")
    Assert.Throws(() => owner.executor.CallFlow("nothere"), AhfError)
}

; --- ends of the called instance ----------------------------------------------------------------------------------------
CalledFlowEndsWithAnException() {
    owner := Owners(Map("f", CallText([Exec("E", ExecPars("g", "t0", 1)), Cnt("z")], [Conn("c1", "t0", "E"), Conn("c2", "E", "z")])
        , "g", CallText([El("m", "Nope.Action_Gone"), Cnt("a")], [Conn("c1", "t0", "m"), Conn("c2", "t0", "a")])))
    Assert.Equal(ExecOnce(owner), "exception: The called flow 'g' ended with an exception: element 'm': element class "
        . "'Nope.Action_Gone' is not available: package 'Nope' is not installed")
    Assert.Equal(Probe.Count("a"), 1, "the other branch of g ran")
    Assert.Equal(Probe.Count("z"), 0)
}

CalledFlowIsStoppedWhileTheCallerWaits() {
    owner := CallerAndHeldCallee(ExecPars("g", "t0", 1))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    owner.executor.StopFlow("g")
    DriveAll(owner)
    Assert.Equal(LastState(owner, "f", "E"), "exception: The called flow 'g' was stopped (flow.stop).")
    Assert.Equal(Reasons(EndsOf(owner, "f")), "exception")
}

CallerIsStoppedWhileItWaits() {
    owner := CallerAndHeldCallee(ExecPars("g", "t0", 1))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    owner.executor.StopFlow("f")
    owner.Drive()
    Assert.Equal(Reasons(EndsOf(owner, "f")), "flow.stop")
    Assert.True(owner.executor.IsExecuting("g"), "the called flow runs on")
    Probe.Release("H")
    DriveAll(owner)
    Assert.Equal(Reasons(EndsOf(owner, "g")), "finished")
    Assert.Equal(HasLog("f2", "late finish"), false, "no finish reached the stopped caller")
}

CancelCallDropsTheOutcome() {
    owner := Owners(Map("g", CallText([Hold("H")], [Conn("c1", "t0", "H")])))
    got := []
    res := owner.executor.CallFlow("g", "", Map("onEnd", (o) => got.Push(o)))
    owner.Drive()
    owner.executor.CancelCall(res["call"])
    owner.executor.CancelCall(res["call"])        ; twice is harmless
    Probe.Release("H")
    DriveAll(owner)
    Assert.Equal(got.Length, 0)
    Assert.Equal(Reasons(EndsOf(owner, "g")), "finished")
}

; --- a flow that calls itself ---------------------------------------------------------------------------------------------
; f: t0 -> C (depth >= 3?) yes -> done; no -> N (depth := depth + 1) -> E (calls f, sends the variables) -> after
SelfFlow(policy, wait) {
    return Owners(Map("f", CallText([CondEl("C", "depth >= 3"), Cnt("done"), SetVar("N", "depth", "depth + 1")
        , Exec("E", ExecPars("", "t0", wait)), Cnt("after")]
        , [Conn("c1", "t0", "C"), Conn("c2", "C", "done", "yes"), Conn("c3", "C", "N", "no"), Conn("c4", "N", "E")
        , Conn("c5", "E", "after")], policy)))
}

SelfStart(owner) {
    owner.executor.CallFlow("f", "", Map("vars", Map("depth", 0)))
    DriveAll(owner)
    return Reasons(EndsOf(owner, "f"))
}

SelfCallWithoutWaiting() {
    owner := SelfFlow("default", 0)
    Assert.Equal(SelfStart(owner), "finished,finished,finished,finished")
    Assert.Equal(Probe.Count("done") "/" Probe.Count("after"), "1/3")
}

SelfCallWaiting() {
    owner := SelfFlow("parallel", 1)
    Assert.Equal(SelfStart(owner), "finished,finished,finished,finished", "the innermost ends first")
    Assert.Equal(Probe.Count("done") "/" Probe.Count("after"), "1/3")
    Assert.Equal(owner.InstanceLog([]), "started:0,started:0,started:0,started:0,ended:0,ended:0,ended:0,ended:0"
        , "all four ran at the same time")
}

SelfCallWithPolicyWaitWithoutWaiting() {
    owner := SelfFlow("wait", 0)
    Assert.Equal(SelfStart(owner), "finished,finished,finished,finished")
    Assert.Equal(owner.InstanceLog([]), "started:0,queued:0,ended:0,started:0,queued:0,ended:0,started:0,queued:0,ended:0"
        . ",started:0,ended:0", "one after the other (E0002)")
}

SelfCallWithPolicyWaitAndWaitingIsRefused() {
    owner := SelfFlow("wait", 1)
    Assert.Equal(SelfStart(owner), "exception")
    Assert.True(InStr(LastState(owner, "f", "E"), "its execution policy is wait and one of its instances waits for the "
        . "calling element"), LastState(owner, "f", "E"))
}

SelfCallWithPolicySkip() {
    for wait in [0, 1] {
        owner := SelfFlow("skip", wait)
        Assert.Equal(SelfStart(owner), "exception")
        Assert.True(InStr(LastState(owner, "f", "E"), "is running and its execution policy is skip"), LastState(owner, "f", "E"))
    }
}

SelfCallWithPolicyStop() {
    for wait in [0, 1] {
        owner := SelfFlow("stop", wait)
        Assert.Equal(SelfStart(owner), "policy stop,policy stop,policy stop,finished", "wait " wait)
        Assert.Equal(Probe.Count("done") "/" Probe.Count("after"), "1/0", "the stopped callers did not go on")
        Assert.Equal(HasLog("a0", ""), false, "no internal error")
    }
}

; f calls itself and waits, without an end: the 101st call is refused and the exception goes back up the chain.
RecursionDepthIsLimited() {
    owner := Owners(Map("f", CallText([Exec("E", ExecPars("", "t0", 1))], [Conn("c1", "t0", "E")])))
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner, 2000)
    ends := EndsOf(owner, "f")
    Assert.Equal(ends.Length, Executor.MAX_CALL_DEPTH + 1)
    for p in ends
        Assert.Equal(p["reason"], "exception")
    Assert.True(HasLog("f0", Executor.MAX_CALL_DEPTH " calls that wait for each other are the limit"))
}

; f (policy wait) calls g and waits; g calls f and waits: the new instance of f would wait for the first one, which waits
; for g, which waits for it.
WaitThroughAnotherFlowIsRefused() {
    owner := Owners(Map("f", CallText([Exec("E", ExecPars("g", "t0", 1)), Cnt("z")], [Conn("c1", "t0", "E"), Conn("c2", "E", "z")]
        , "wait"), "g", CallText([Exec("G", ExecPars("f", "t0", 1))], [Conn("c1", "t0", "G")])))
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    Assert.True(InStr(LastState(owner, "g", "G"), "its execution policy is wait"), LastState(owner, "g", "G"))
    Assert.True(InStr(LastState(owner, "f", "E"), "The called flow 'g' ended with an exception"), LastState(owner, "f", "E"))
    Assert.Equal(Reasons(EndsOf(owner, "f")), "exception")
}

; The same flows without waiting in g: no deadlock, the second instance of f is queued and runs after the first.
NoWaitThroughAnotherFlowIsQueued() {
    owner := Owners(Map("f", CallText([Exec("E", ExecPars("g", "t0", 1)), Cnt("z")], [Conn("c1", "t0", "E"), Conn("c2", "E", "z")]
        , "wait"), "g", CallText([Exec("G", ExecPars("f", "t0", 0)), Cnt("q")], [Conn("c1", "t0", "G"), Conn("c2", "G", "q")])))
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner, 50)
    Assert.True(Probe.Count("z") >= 2, "both instances of f went on behind E")
}

; --- Condition_Flow_Running and Action_Stop_Flow ----------------------------------------------------------------------------
ConditionFlowRunning() {
    owner := Owners(Map("f", CallText([El("C", "Condition_Flow_Running", '{"flowID":"g"}'), Cnt("y"), Cnt("n")]
        , [Conn("c1", "t0", "C"), Conn("c2", "C", "y", "yes"), Conn("c3", "C", "n", "no")])
        , "g", CallText([Hold("H")], [Conn("c1", "t0", "H")], "wait")))
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    Assert.Equal(Probe.Count("y") "/" Probe.Count("n"), "0/1", "g does not run")
    first := owner.executor.StartFlow(owner.flows.Get("g"))
    owner.executor.StartFlow(owner.flows.Get("g"))      ; queued (policy wait)
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(Probe.Count("y"), 1, "g runs")
    owner.executor.StopInstance(first)
    Assert.Equal(owner.executor.IsExecuting("g"), true, "only the queued instance is left: g is still executing")
}

ConditionFlowRunningOfAMissingFlowAndOfItself() {
    owner := Owners(Map("f", CallText([El("C", "Condition_Flow_Running", '{"flowID":"nothere"}')], [Conn("c1", "t0", "C")])))
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    Assert.Equal(LastState(owner, "f", "C"), "exception: Flow 'nothere' does not exist")
    owner := Owners(Map("f", CallText([El("C", "Condition_Flow_Running", '{"flowID":"f"}'), Cnt("y")]
        , [Conn("c1", "t0", "C"), Conn("c2", "C", "y", "yes")])))
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    Assert.Equal(Probe.Count("y"), 1, "the own flow is executing")
}

StopFlowStopsRunningAndWaitingInstances() {
    owner := Owners(Map("f", CallText([El("S", "Action_Stop_Flow", '{"flowID":"g"}'), Cnt("z")], [Conn("c1", "t0", "S"), Conn("c2", "S", "z")])
        , "g", CallText([Hold("H")], [Conn("c1", "t0", "H")], "wait")))
    owner.executor.StartFlow(owner.flows.Get("g"))
    owner.executor.StartFlow(owner.flows.Get("g"))
    owner.Drive()
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    Assert.Equal(Reasons(EndsOf(owner, "g")), "element.stopflow,element.stopflow")
    Assert.Equal(Reasons(EndsOf(owner, "f")), "finished")
    Assert.Equal(Probe.Count("z"), 1)
}

StopFlowOfTheOwnFlowAndOfAMissingFlow() {
    owner := Owners(Map("f", CallText([El("S", "Action_Stop_Flow", '{"flowID":"f"}'), Cnt("z")], [Conn("c1", "t0", "S"), Conn("c2", "S", "z")])))
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    Assert.Equal(Reasons(EndsOf(owner, "f")), "element.stopflow")
    Assert.Equal(LastState(owner, "f", "S"), "finished")
    Assert.Equal(Probe.Count("z"), 0, "nothing behind the element ran")
    owner := Owners(Map("f", CallText([El("S", "Action_Stop_Flow", '{"flowID":""}')], [Conn("c1", "t0", "S")])))
    owner.executor.StartFlow(owner.flows.Get("f"))
    DriveAll(owner)
    Assert.Equal(LastState(owner, "f", "S"), "exception: Flow '' does not exist")
}

FlowFunctionsNeedAnInlineHost() {
    ctx := ExecContext("f", "e", "i", "t")
    for fn in [() => ctx.FlowExists("f"), () => ctx.CallFlow("f"), () => ctx.StopFlow("f"), () => ctx.IsFlowExecuting("f")
        , () => ctx.DefaultTrigger("f"), () => ctx.IsTriggerEnabled("f", "t"), () => ctx.HasTrigger("f", "t")]
        Assert.Throws(fn, ElementError)
}

TestRun.Init()

TestRun.Case("A waiting call finishes when the called instance ends", WaitingCallFinishesWhenTheCalledInstanceEnds)
TestRun.Case("A call that does not wait finishes at once, the called flow runs on", NotWaitingCallFinishesAtOnce)
TestRun.Case("A third flow runs while the caller waits", AThirdFlowRunsWhileTheCallerWaits)
TestRun.Case("Variables are sent and returned", VarsAreSentAndReturned)
TestRun.Case("Variables are not returned without ReturnVariables", VarsAreNotReturnedWithoutTheOption)
TestRun.Case("Variables are not sent without SendLocalVars", VarsAreNotSentWithoutTheOption)
TestRun.Case("CallFlow: initial variables, the outcome as data", CallFlowSetsTheInstanceVariablesAndGivesTheOutcomeAsData)
TestRun.Case("The default trigger and a specified trigger", TheDefaultTriggerAndASpecifiedTrigger)
TestRun.Case("Errors of the trigger choice", TriggerErrors)
TestRun.Case("WhichTrigger: the index of the choice is accepted", TheIndexOfTheChoiceIsAccepted)
TestRun.Case("A disabled flow: exception, or normal with SkipDisabled", DisabledFlowWithAndWithoutSkip)
TestRun.Case("A flow that does not exist", MissingFlow)
TestRun.Case("The called flow ends with an exception (missing package, E0047)", CalledFlowEndsWithAnException)
TestRun.Case("The called flow is stopped while the caller waits", CalledFlowIsStoppedWhileTheCallerWaits)
TestRun.Case("The caller is stopped while it waits: the called flow runs on", CallerIsStoppedWhileItWaits)
TestRun.Case("CancelCall drops the outcome", CancelCallDropsTheOutcome)
TestRun.Case("A flow calls itself without waiting", SelfCallWithoutWaiting)
TestRun.Case("A flow calls itself and waits", SelfCallWaiting)
TestRun.Case("A flow with the policy wait calls itself without waiting: one after the other", SelfCallWithPolicyWaitWithoutWaiting)
TestRun.Case("A flow with the policy wait calls itself and waits: refused", SelfCallWithPolicyWaitAndWaitingIsRefused)
TestRun.Case("A flow with the policy skip calls itself: exception", SelfCallWithPolicySkip)
TestRun.Case("A flow with the policy stop calls itself: the caller is stopped", SelfCallWithPolicyStop)
TestRun.Case("The depth of waiting calls is limited", RecursionDepthIsLimited)
TestRun.Case("A wait that would never end through another flow is refused", WaitThroughAnotherFlowIsRefused)
TestRun.Case("Without the wait in the other flow the instance is queued", NoWaitThroughAnotherFlowIsQueued)
TestRun.Case("Condition_Flow_Running: running, not running, queued", ConditionFlowRunning)
TestRun.Case("Condition_Flow_Running: a missing flow, the own flow", ConditionFlowRunningOfAMissingFlowAndOfItself)
TestRun.Case("Action_Stop_Flow stops running and waiting instances", StopFlowStopsRunningAndWaitingInstances)
TestRun.Case("Action_Stop_Flow: the own flow, a missing flow", StopFlowOfTheOwnFlowAndOfAMissingFlow)
TestRun.Case("The flow functions throw without an engine host", FlowFunctionsNeedAnInlineHost)

TestRun.Finish()
