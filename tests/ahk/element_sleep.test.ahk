#Requires AutoHotkey v2.0
; Tests for the element Default.Action_Sleep (WI-0047, doc/ELEMENT-API-V2.md section 4): the parameters, the name and
; the language keys of v1, and runs in the Executor with the stand-in owner (helpers/ExecutorKit.ahk), so the parameters
; are evaluated as in the engine (ctx.EvalParams). The flows are in the v1 format: the loader converts the expression
; texts first, as for an old flow. The timing cases pump messages (Sleep() runs timers) and use wide tolerances: the
; timer is never early by design, but a loaded machine can delay it.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include helpers\ExecutorKit.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk

; A v1 flow: the trigger, then the sleep element "s" with the parameters pars (JSON text) and the package as v1 writes it.
SleepFlow(pars, package := "Default") {
    elem := '"s":{"ID":"s","type":"Action","package":"' package '","packageVersion":"1.2.0","class":"Action_Sleep","pars":' pars '}'
    return FlowText([elem], [Conn("c1", "t0", "s")])
}

; Starts the flow and waits until the sleep element has ended. Returns Map: result (the last state of "s"), ms, owner.
RunSleep(pars, package := "Default", timeoutMs := 3000) {
    owner := NewOwner(SleepFlow(pars, package))
    start := Time.NowMs()
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    deadline := start + timeoutMs
    while (!RegExMatch(owner.ElementStates("s"), "(finished|exception)$") && Time.NowMs() < deadline) {
        Sleep(5)
        owner.Drive()
    }
    states := StrSplit(owner.ElementStates("s"), " ")
    return Map("result", states.Length ? states[-1] : "", "ms", Time.NowMs() - start, "owner", owner)
}

LastMessage(owner, elementId) {
    msg := ""
    for ev in owner.events {
        if (ev["type"] = "evt.element.state" && ev["payload"]["elementId"] = elementId && ev["payload"].Has("message"))
            msg := ev["payload"]["message"]
    }
    return msg
}

SleepEndsAfterDuration() {
    r := RunSleep('{"Duration":"200","Unit":"Milliseconds"}')
    Assert.Equal(r["result"], "finished")
    Assert.True(r["ms"] >= 150, "not earlier than 150 ms, was " Round(r["ms"]) " ms")
    ; Measured 200 to 205 ms. The upper bound is wider than +-50 ms so that a loaded machine does not fail the test.
    Assert.True(r["ms"] <= 600, "not later than 600 ms, was " Round(r["ms"]) " ms")
}

SleepDurationIsAnExpression() {
    ; v1 text "0.1" in seconds (converted on load); in v2 also a calculation
    r := RunSleep('{"Duration":"0.1","Unit":"Seconds"}')
    Assert.Equal(r["result"], "finished")
    Assert.True(r["ms"] >= 80 && r["ms"] <= 600, "0.1 s, was " Round(r["ms"]) " ms")
    r := RunSleep('{"Duration":"50 * 2","Unit":"Milliseconds"}')
    Assert.Equal(r["result"], "finished")
}

SleepOfAV1FlowWithPackageDefaultInLowerCase() {
    ; E0045: 8 elements of the test flows write "default"; the lookup ignores case
    r := RunSleep('{"Duration":"20","Unit":"milliseconds"}', "default")
    Assert.Equal(r["result"], "finished")
    ; and without the key the package is Default
    owner := NewOwner(FlowText([El("s", "Action_Sleep", '{"Duration":"20","Unit":"Milliseconds"}')], [Conn("c1", "t0", "s")]))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    deadline := Time.NowMs() + 3000
    while (!InStr(owner.ElementStates("s"), "finished") && Time.NowMs() < deadline) {
        Sleep(5)
        owner.Drive()
    }
    Assert.Equal(owner.ElementStates("s"), "running finished")
}

SleepStopGivesNoResult() {
    owner := NewOwner(SleepFlow('{"Duration":"300","Unit":"Milliseconds"}'))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(owner.ElementStates("s"), "running")
    owner.executor.StopFlow("f")
    Sleep(400)
    owner.Drive()
    ; the stop ends the element (result stopped, state finished); the timer of the sleep does not finish it again
    Assert.Equal(owner.ElementStates("s"), "running finished")
    Assert.True(!HasLog("a0", "second Finish"), "no late Finish of the timer")
}

SleepMissingUnitIsSeconds() {
    ; v1 stores the default 2 (the index of "Seconds") when the parameter is missing
    Assert.Equal(Default.Action_Sleep.ToMs(2, 2), 2000)
    Assert.Equal(Default.Action_Sleep.ToMs(5, "Milliseconds"), 5)
    Assert.Equal(Default.Action_Sleep.ToMs(2, "seconds"), 2000, "the unit in any case")
    Assert.Equal(Default.Action_Sleep.ToMs(1, "Minutes"), 60000)
    Assert.Equal(Default.Action_Sleep.ToMs(1, 1), 1)
    Assert.Equal(Default.Action_Sleep.ToMs(1, 3), 60000)
    Assert.Equal(Default.Action_Sleep.ToMs(0.5, "Seconds"), 500.0)
    r := RunSleep('{"Duration":"0"}')
    Assert.Equal(r["result"], "finished", "no Unit: seconds, 0 s")
}

SleepBadParamsThrow() {
    Assert.Throws(() => Default.Action_Sleep.ToMs("abc", "Seconds"), ElementError, "non-numeric Duration")
    Assert.Throws(() => Default.Action_Sleep.ToMs(-1, "Seconds"), ElementError, "negative Duration")
    Assert.Throws(() => Default.Action_Sleep.ToMs(1, "Hours"), ElementError, "unknown Unit")
    Assert.Throws(() => Default.Action_Sleep.ToMs(1, 4), ElementError, "unknown index")
}

SleepBadParamsEndAsException() {
    r := RunSleep('{"Duration":"","Unit":"Seconds"}')
    Assert.Equal(r["result"], "exception")
    Assert.True(InStr(LastMessage(r["owner"], "s"), "is empty"), LastMessage(r["owner"], "s"))
    r := RunSleep('{"Duration":"\"abc\"","Unit":"Seconds"}')
    Assert.Equal(r["result"], "exception")
    Assert.True(InStr(LastMessage(r["owner"], "s"), "Duration must be a number"), LastMessage(r["owner"], "s"))
}

SleepParametersAndNameAreThoseOfV1() {
    p := Default.Action_Sleep.Parameters("")
    Assert.Equal(p.Length, 3)
    Assert.Equal(p[1].type, "Label")
    Assert.Equal(p[1].label, "Duration")
    Assert.Equal(p[2].id, "Duration")
    Assert.Equal(p[2].content, "Expression")
    Assert.Equal(p[2].default, 2)
    Assert.True(p[2].WarnIfEmpty)
    Assert.Equal(p[3].id, "Unit")
    Assert.Equal(p[3].default, 2)
    Assert.Equal(p[3].result, "enum")
    Assert.Equal(p[3].enum[2], "Seconds")
    Assert.Equal(p[3].choices[1], "Milliseconds")
    Assert.Equal(Default.Action_Sleep.Name(), "Sleep")
    Assert.Equal(Default.Action_Sleep.Category(), "Flow control")
    Assert.Equal(Default.Action_Sleep.GenerateName("", {Duration: 10, Unit: "Milliseconds"}), "Sleep: 10 ms")
    Assert.Equal(Default.Action_Sleep.GenerateName("", {Duration: 2, Unit: "Seconds"}), "Sleep: 2 s")
    Assert.Equal(Default.Action_Sleep.GenerateName("", {Duration: 3, Unit: "Minutes"}), "Sleep: 3 m")
    Assert.Equal(Default.Action_Sleep.Icon, "Sleep.ico")
}

ManualParametersAndNameAreThoseOfV1() {
    p := Default.Trigger_Manual.Parameters("")
    Assert.Equal(p.Length, 2)
    Assert.Equal(p[2].id, "ID")
    Assert.Equal(p[2].content, "rawstring")
    Assert.Equal(Default.Trigger_Manual.Name(), "Manual")
    Assert.Equal(Default.Trigger_Manual.Category(), "User interaction")
    Assert.Equal(Default.Trigger_Manual.GenerateName("", {ID: "start"}), 'Manual`n"start"')
    vars := Default.Trigger_Manual.TriggerVariables({ID: "start"}, "")
    Assert.Equal(vars["A_ManualTriggerID"], "start")
}

TestRun.Init()

TestRun.Case("Sleep: 200 ms ends after about 200 ms", SleepEndsAfterDuration)
TestRun.Case("Sleep: Duration is an expression (converted from a v1 flow)", SleepDurationIsAnExpression)
TestRun.Case("Sleep: a v1 flow with package 'default' or no package loads and runs (E0045)", SleepOfAV1FlowWithPackageDefaultInLowerCase)
TestRun.Case("Sleep: a stop before the end gives no second result", SleepStopGivesNoResult)
TestRun.Case("Sleep: Unit converts to milliseconds, the default index 2 is seconds", SleepMissingUnitIsSeconds)
TestRun.Case("Sleep: bad Duration or Unit throws ElementError", SleepBadParamsThrow)
TestRun.Case("Sleep: bad parameters end the run as exception", SleepBadParamsEndAsException)
TestRun.Case("Sleep: parameters, name and language keys of v1", SleepParametersAndNameAreThoseOfV1)
TestRun.Case("Manual: parameters, name and trigger variable of v1", ManualParametersAndNameAreThoseOfV1)

TestRun.Finish()
