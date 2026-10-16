#Requires AutoHotkey v2.0
; Unit tests of the arming of the triggers in the engine (WI-0062, src/engine/TriggerArms.ahk, PROTOCOL 4.4): the passes
; and their staggering, the generation filter, the start context of the first pass (ahfStartup, windowsStartup), the
; failures of an arm (refused, protocol error, no answer, unknown class, parameter error), FlowRemoved, and
; TriggerVariables at a start (with and without the data of an event). The same through the real chain: the e2e tests
; in tests/integration/test_trigger_arming.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include helpers\ExecutorKit.ahk
#Include ..\..\src\engine\TriggerArms.ahk

; Test elements of the package ArmKit: triggers (one with a parameter that needs evaluation), an action that reads the
; thread variables A_TestCount and A_TestId, and a trigger without TriggerVariables.
class ArmKit {
    class Test_Trig extends AhfElement {
        static Mode := "trigger"
        static Parameters(ctx) => [{id: "Mark", content: "String"}]
        static Enable(ctx, params) {
        }
        static Disable(ctx) {
        }
        static TriggerVariables(params, data) => Map("A_TestId", params.HasProp("Mark") ? params.Mark : "none"
            , "A_TestCount", (IsObject(data) && data.Has("count")) ? data["count"] : "none")
    }

    class Test_Number extends AhfElement {
        static Mode := "trigger"
        static Parameters(ctx) => [{id: "N", content: "integer"}]
        static Enable(ctx, params) {
        }
        static Disable(ctx) {
        }
    }

    class Test_NoVars extends AhfElement {
        static Mode := "trigger"
        static Enable(ctx, params) {
        }
        static Disable(ctx) {
        }
    }

    class Test_Read extends AhfElement {
        static Mode := "inline"
        static Run(ctx, params) {
            ArmRead.Value := ctx.GetVar("A_TestCount", "unset") "/" ctx.GetVar("A_TestId", "unset")
            ctx.Finish("normal")
        }
    }
}

class ArmRead {
    static Value := ""
}

ElementRegistry.Register(ArmKit.Test_Trig)
ElementRegistry.Register(ArmKit.Test_Number)
ElementRegistry.Register(ArmKit.Test_NoVars)
ElementRegistry.Register(ArmKit.Test_Read)

; The request side of the engine peer: records every request and answers it on demand (the callback is the one of the arm).
class FakePeer {
    __New() {
        this.sent := []
        this.failNext := ""           ; text: the next Request throws (the peer is not connected)
    }

    Request(to, msgType, payload, callback, timeoutMs := 5000) {
        if (this.failNext != "") {
            text := this.failNext
            this.failNext := ""
            throw AhfError(text, ErrCode.PEER_GONE)
        }
        this.sent.Push(Map("to", to, "type", msgType, "payload", payload, "callback", callback))
    }

    Count(msgType) {
        n := 0
        for msg in this.sent {
            if (msg["type"] = msgType)
                n += 1
        }
        return n
    }

    ; The nth request of the type (1 is the first), or "" if there is none.
    Find(msgType, nth := 1) {
        n := 0
        for msg in this.sent {
            if (msg["type"] = msgType) {
                n += 1
                if (n = nth)
                    return msg
            }
        }
        return ""
    }

    ; Answers a request with a payload Map (a res as the peer gives it).
    Answer(msg, payload) {
        msg["callback"]({payload: payload})
    }
}

; The engine stand-in: EngineOwner (flows, vars, executor) with a fake peer and the arms of the engine.
class ArmOwner extends EngineOwner {
    __New(args := "") {
        super.__New()
        this.args := (args is Map) ? args : Map()
        this.peer := FakePeer()
        this.stateEvents := []
        this.arms := TriggerArms(this)
    }

    EmitTriggerState(flowId, triggerId) {
        info := this.arms.Info(flowId, triggerId)
        this.stateEvents.Push(Map("flow", flowId, "trigger", triggerId, "armed", info["armed"], "message", info["message"]))
    }
}

ArmTrig(id, cls, pars := "{}") => '"' id '":{"ID":"' id '","type":"trigger","package":"ArmKit","class":"' cls '","pars":' pars '}'
ArmAct(id, cls) => '"' id '":{"ID":"' id '","type":"action","package":"ArmKit","class":"' cls '","pars":{}}'
ArmCon(id, from, to) => '"' id '":{"ID":"' id '","from":"' from '","to":"' to '","type":"Connection","ConnectionType":"normal"}'

; A flow "f" with the given elements and connections; the triggers are enabled (they follow the flow) when enable is true.
ArmOwnerWith(elements, connections := [], args := "", enable := true) {
    owner := ArmOwner(args)
    els := ""
    for e in elements
        els .= (els = "" ? "" : ",") e
    cons := ""
    for c in connections
        cons .= (cons = "" ? "" : ",") c
    text := '{"name":"f","flowSettings":{"ExecutionPolicy":"parallel"},"allElements":{' els '},"allConnections":{' cons '}}'
    owner.flows.Load("f", text)
    if (enable)
        owner.flows.Get("f").SetFollowingEnabled(true)
    return owner
}

Off(v, msg := "") => Assert.Equal(v ? 1 : 0, 0, msg)

; The host is ready and the engine is ready: the pass sends cmd.trigger.reset; this answers it with ok.
PassAfterReset(owner) {
    owner.arms.HostReady()
    owner.arms.EngineReady()
    owner.peer.Answer(owner.peer.Find("cmd.trigger.reset"), Map("ok", true))
}

Ctx(msg) => msg["payload"]["context"]

; --- passes ----------------------------------------------------------------------------------------------------------

NothingIsSentBeforeTheEngineIsReady() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig"), ArmTrig("t2", "Test_Trig")])
    owner.arms.HostReady()
    Assert.Equal(owner.peer.sent.Length, 0, "the host is ready, the engine is not: the first pass waits for the engine")
    owner.arms.EngineReady()
    Assert.Equal(owner.peer.Count("cmd.trigger.reset"), 1, "the engine is ready: reset first")
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 0, "no arm before the reset is answered")
}

FirstPassArmsEveryEnabledTriggerWithTheStartContext() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig"), ArmTrig("t2", "Test_Trig"), ArmTrig("t3", "Test_Trig")])
    PassAfterReset(owner)
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 2, "two open requests at most, the first two")
    Assert.Equal(Ctx(owner.peer.Find("cmd.trigger.arm", 1)), "ahfStartup", "first pass: the start context")
    Assert.Equal(owner.peer.Find("cmd.trigger.arm", 1)["payload"]["class"], "ArmKit.Test_Trig", "qualified class ID")
    Assert.Equal(owner.peer.Find("cmd.trigger.arm", 1)["payload"]["triggerKey"], "f/t1")
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm", 1), Map("ok", true))
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 3, "a slot is free: the third one follows")
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm", 2), Map("ok", true))
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm", 3), Map("ok", true))
    Assert.True(owner.arms.Info("f", "t1")["armed"] && owner.arms.Info("f", "t2")["armed"]
        && owner.arms.Info("f", "t3")["armed"], "all three armed")
}

WindowsStartupAddsItsTokenInTheFirstPass() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")], [], Map("windows-startup", ""))
    PassAfterReset(owner)
    Assert.Equal(Ctx(owner.peer.Find("cmd.trigger.arm")), "ahfStartup windowsStartup", "both tokens with Windows")
}

ARestartedEngineHasNoStartContext() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")], [], Map("restarted", "1", "windows-startup", ""))
    PassAfterReset(owner)
    Assert.Equal(Ctx(owner.peer.Find("cmd.trigger.arm")), "", "an engine that was restarted starts no start context")
}

ASecondPassAfterARestartOfTheHostHasNoStartContext() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")])
    PassAfterReset(owner)
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm"), Map("ok", true))
    Assert.Equal(Ctx(owner.peer.Find("cmd.trigger.arm")), "ahfStartup", "the first pass had it")
    owner.arms.HostGone()
    Off(owner.arms.Info("f", "t1")["armed"], "the host ended: nothing is armed")
    owner.arms.HostReady()
    owner.peer.Answer(owner.peer.Find("cmd.trigger.reset", 2), Map("ok", true))
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 2, "the pass after the restart re-arms the trigger")
    Assert.Equal(Ctx(owner.peer.Find("cmd.trigger.arm", 2)), "", "no start context after a restart of the host")
}

ANotAnsweredResetSendsNothing() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")])
    owner.arms.HostReady()
    owner.arms.EngineReady()
    owner.peer.Answer(owner.peer.Find("cmd.trigger.reset"), Map("ok", false, "error", Map("code", "timeout", "message", "x")))
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 0, "a refused reset: no arm is sent")
    Off(owner.arms.Info("f", "t1")["armed"])
}

; --- answers and failures ----------------------------------------------------------------------------------------------

GenerationFilterAcceptsOnlyTheCurrentArmedGeneration() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")])
    PassAfterReset(owner)
    msg := owner.peer.Find("cmd.trigger.arm")
    gen := msg["payload"]["gen"]
    Assert.True(owner.arms.Accepts("f/t1", gen), "the arm is on its way: the host may fire inside Enable")
    owner.peer.Answer(msg, Map("ok", true))
    Assert.True(owner.arms.Accepts("f/t1", gen), "armed with the generation of the arm")
    Off(owner.arms.Accepts("f/t1", gen + 1), "another generation is dropped")
    Off(owner.arms.Accepts("f/t2", gen), "another trigger is dropped")
    Assert.True(owner.arms.Current("f/t1", gen))
    owner.arms.Reported("f/t1", gen, "callback failed")
    Assert.Equal(owner.arms.Info("f", "t1")["message"], "callback failed", "an error of the current arming is kept")
    Assert.True(owner.arms.Accepts("f/t1", gen), "the trigger stays armed after an error of a callback")
}

ARefusedArmIsNotArmedWithItsTextAndIsDisarmed() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")])
    PassAfterReset(owner)
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm"), Map("ok", false, "message", "refused by the test"))
    info := owner.arms.Info("f", "t1")
    Off(info["armed"])
    Assert.Equal(info["message"], "refused by the test")
    Assert.Equal(owner.peer.Count("cmd.trigger.disarm"), 1, "the engine does not rely on the host to drop the arming")
    Off(owner.arms.Accepts("f/t1", owner.peer.Find("cmd.trigger.arm")["payload"]["gen"]), "a refused arm accepts no events")
}

AProtocolErrorIsNotArmedAndTheTextSaysWhy() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")])
    PassAfterReset(owner)
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm"), Map("ok", false, "error", Map("code", "not_found"
        , "message", "unknown element class 'x'")))
    info := owner.arms.Info("f", "t1")
    Off(info["armed"])
    Assert.True(InStr(info["message"], "not_found") > 0, info["message"])
    Assert.Equal(owner.peer.Count("cmd.trigger.disarm"), 1)
}

ANoAnswerIsRetriedOnlyAtTheNextPass() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")])
    PassAfterReset(owner)
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm"), Map("ok", false, "error", Map("code", "timeout", "message", "no answer")))
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 1, "no retry in a loop")
    Off(owner.arms.Info("f", "t1")["armed"])
    owner.arms.HostGone()
    owner.arms.HostReady()
    owner.peer.Answer(owner.peer.Find("cmd.trigger.reset", 2), Map("ok", true))
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 2, "the next pass (the next ready of the host) retries it")
}

UnknownClassAndNotATriggerAreNotSentToTheHost() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Missing"), ArmAct("a1", "Test_Read"), ArmTrig("t2", "Test_Trig")])
    PassAfterReset(owner)
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 1, "only the valid trigger is sent")
    Assert.Equal(owner.peer.Find("cmd.trigger.arm")["payload"]["triggerKey"], "f/t2")
    Assert.True(owner.arms.Info("f", "t1")["message"] != "", "the unknown class carries its message")
    Off(owner.arms.Info("f", "t1")["armed"])
}

AParameterThatCannotBeEvaluatedIsNotArmed() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Number", '{"N":"1 +"}'), ArmTrig("t2", "Test_Number", '{"N":"2"}')])
    PassAfterReset(owner)
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 1, "the broken one is not sent")
    Assert.Equal(owner.peer.Find("cmd.trigger.arm")["payload"]["params"]["N"], 2, "the good one is evaluated: integer 2")
    info := owner.arms.Info("f", "t1")
    Off(info["armed"])
    Assert.True(info["message"] != "", "the evaluation error is the message of the trigger")
}

SwitchingOffDisarmsAndDropsTheTrigger() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")])
    PassAfterReset(owner)
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm"), Map("ok", true))
    gen := owner.peer.Find("cmd.trigger.arm")["payload"]["gen"]
    rec := owner.flows.Get("f")
    rec.SetTriggerEnabled("t1", false)
    owner.arms.Changed(rec, "t1")
    Assert.Equal(owner.peer.Count("cmd.trigger.disarm"), 1, "disarmed at once")
    Off(owner.arms.Accepts("f/t1", gen), "its events are dropped from now on")
    Off(owner.arms.Info("f", "t1")["armed"])
}

SwitchingOnWhileTheHostIsDownSaysSo() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig")], [], "", false)
    PassAfterReset(owner)
    owner.arms.HostGone()
    rec := owner.flows.Get("f")
    rec.SetTriggerEnabled("t1", true)
    owner.arms.Changed(rec, "t1")
    Assert.Equal(owner.arms.Info("f", "t1")["message"], TriggerArms.HOST_DOWN)
    Assert.Equal(owner.peer.Count("cmd.trigger.arm"), 0)
}

FlowRemovedDisarmsItsTriggers() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig"), ArmTrig("t2", "Test_Trig")])
    PassAfterReset(owner)
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm", 1), Map("ok", true))
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm", 2), Map("ok", true))
    owner.arms.FlowRemoved("f")
    Assert.Equal(owner.peer.Count("cmd.trigger.disarm"), 2, "every trigger of the flow is disarmed")
    Off(owner.arms.Info("f", "t1")["armed"])
}

SnapshotListsEnabledArmedAndFailedTriggers() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig"), ArmTrig("t2", "Test_Missing")])
    PassAfterReset(owner)
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm"), Map("ok", true))
    snap := owner.arms.Snapshot(owner.flows.Get("f"))
    Assert.Equal(snap.Length, 2)
    Assert.Equal(snap[1]["elementId"], "t1")
    Assert.True(snap[1]["enabled"] == Json.True)
    Assert.True(snap[1]["armed"] == Json.True)
    Off(snap[2]["armed"] == Json.True)
    Assert.True(snap[2]["message"] != "", "the failed one has its message")
}

; --- TriggerVariables at a start (M-0069 back) -------------------------------------------------------------------------

; The instance of a start runs until its action has read the thread variables (ArmRead.Value).
ArmRunsFlow(owner) {
    owner.executor.Tick()
}

TriggerVariablesOfAnEventAreSetWithItsData() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig"), ArmAct("a1", "Test_Read")], [ArmCon("c1", "t1", "a1")])
    PassAfterReset(owner)
    owner.peer.Answer(owner.peer.Find("cmd.trigger.arm"), Map("ok", true))
    rec := owner.flows.Get("f")
    ArmRead.Value := ""
    owner.executor.StartFlow(rec, "t1", Map("params", {Mark: "event"}, "data", Map("count", 3)))
    ArmRunsFlow(owner)
    Assert.Equal(ArmRead.Value, "3/event", "A_TestCount from the data of the event, A_TestId from the parameters")
}

TriggerVariablesWithoutDataUseTheParametersOfTheStart() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_Trig", '{"Mark":"start"}'), ArmAct("a1", "Test_Read")], [ArmCon("c1", "t1", "a1")])
    rec := owner.flows.Get("f")
    ArmRead.Value := ""
    owner.executor.StartFlow(rec, "t1")
    ArmRunsFlow(owner)
    Assert.Equal(ArmRead.Value, "none/start", "a start without an event: data empty, the parameters evaluated now")
}

ATriggerClassWithoutTriggerVariablesStartsTheInstance() {
    owner := ArmOwnerWith([ArmTrig("t1", "Test_NoVars"), ArmAct("a1", "Test_Read")], [ArmCon("c1", "t1", "a1")])
    ArmRead.Value := ""
    owner.executor.StartFlow(owner.flows.Get("f"), "t1", Map("params", {}, "data", Map()))
    ArmRunsFlow(owner)
    Assert.Equal(ArmRead.Value, "unset/unset", "no TriggerVariables: no variables of the trigger, the flow runs on")
}

TestRun.Init()

TestRun.Case("Trigger arms: nothing is sent before the engine is ready", NothingIsSentBeforeTheEngineIsReady)
TestRun.Case("Trigger arms: the first pass arms every enabled trigger, two at a time, with ahfStartup", FirstPassArmsEveryEnabledTriggerWithTheStartContext)
TestRun.Case("Trigger arms: --windows-startup adds windowsStartup to the first pass", WindowsStartupAddsItsTokenInTheFirstPass)
TestRun.Case("Trigger arms: an engine after a restart has no start context", ARestartedEngineHasNoStartContext)
TestRun.Case("Trigger arms: a pass after a restart of the host has no start context", ASecondPassAfterARestartOfTheHostHasNoStartContext)
TestRun.Case("Trigger arms: a refused reset sends no arm", ANotAnsweredResetSendsNothing)
TestRun.Case("Trigger arms: the generation filter accepts only the current armed generation", GenerationFilterAcceptsOnlyTheCurrentArmedGeneration)
TestRun.Case("Trigger arms: a refused arm is not armed, with its text, and is disarmed", ARefusedArmIsNotArmedWithItsTextAndIsDisarmed)
TestRun.Case("Trigger arms: a protocol error is not armed, with its code", AProtocolErrorIsNotArmedAndTheTextSaysWhy)
TestRun.Case("Trigger arms: an arm without answer is retried at the next pass only", ANoAnswerIsRetriedOnlyAtTheNextPass)
TestRun.Case("Trigger arms: an unknown class and a non-trigger are not sent to the host", UnknownClassAndNotATriggerAreNotSentToTheHost)
TestRun.Case("Trigger arms: a parameter that cannot be evaluated is not armed", AParameterThatCannotBeEvaluatedIsNotArmed)
TestRun.Case("Trigger arms: switching a trigger off disarms it and drops its events", SwitchingOffDisarmsAndDropsTheTrigger)
TestRun.Case("Trigger arms: switching on while the host is down says so", SwitchingOnWhileTheHostIsDownSaysSo)
TestRun.Case("Trigger arms: a flow that leaves the table is disarmed", FlowRemovedDisarmsItsTriggers)
TestRun.Case("Trigger arms: the snapshot lists enabled, armed and failed triggers", SnapshotListsEnabledArmedAndFailedTriggers)
TestRun.Case("Trigger arms: TriggerVariables of an event get its data", TriggerVariablesOfAnEventAreSetWithItsData)
TestRun.Case("Trigger arms: a start without an event evaluates the parameters for TriggerVariables", TriggerVariablesWithoutDataUseTheParametersOfTheStart)
TestRun.Case("Trigger arms: a trigger class without TriggerVariables starts the instance", ATriggerClassWithoutTriggerVariablesStartsTheInstance)

TestRun.Finish()
