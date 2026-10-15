#Requires AutoHotkey v2.0
; Unit tests of the flow functions of the context (WI-0052, doc/ELEMENT-API-V2.md section 3): GetElementIdsOfClass,
; GetElementPars and StopInstance, against the Executor with a stand-in owner.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include helpers\ExecutorKit.ahk

class CtxSeen {
    static ids := ""
    static pars := ""
    static stopped := ""
    static error := ""
}

; Asks the context for the elements of the class "ExecKit.Test_Count" and for the parameters of the element "b", then
; stops its own instance after it has finished.
class ExecKit2 {
    class Test_Flow extends AhfElement {
        static Mode := "inline"
        static Run(ctx, params) {
            try {
                CtxSeen.ids := ctx.GetElementIdsOfClass("ExecKit.Test_Count")
                CtxSeen.pars := ctx.GetElementPars("b")
                try ctx.GetElementPars("nothere")
                catch as e
                    CtxSeen.error := e.Message
            } catch as e {
                ctx.Finish("exception", e.Message)
                return
            }
            ctx.Finish("normal")
            CtxSeen.stopped := ctx.StopInstance()
        }
    }
}
ElementRegistry.Register(ExecKit2.Test_Flow)

BuildFlow() {
    CtxSeen.ids := CtxSeen.pars := CtxSeen.stopped := CtxSeen.error := ""
    return NewOwner(FlowText([El("a", "ExecKit.Test_Count"), El("b", "ExecKit.Test_Count"
            , '{"List":["x","y"],"Obj":{"K":1},"Nothing":null,"Text":"t","Num":5}')
        , El("c", "ExecKit.test_count"), El("f", "ExecKit2.Test_Flow"), El("d", "ExecKit.Test_Count")]
        , [Conn("c1", "t0", "a"), Conn("c2", "a", "b"), Conn("c3", "b", "c"), Conn("c4", "c", "f"), Conn("c5", "f", "d")]))
}

IdsOfAClassComeInTheOrderOfTheFlowAndIgnoreCase() {
    owner := BuildFlow()
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(CtxSeen.ids.Length, 4, "a, b, c and d are Test_Count, the writing in the flow file does not matter")
    Assert.Equal(CtxSeen.ids[1] "," CtxSeen.ids[2] "," CtxSeen.ids[3] "," CtxSeen.ids[4], "a,b,c,d")
}

ParametersKeepTheirTypes() {
    owner := BuildFlow()
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    pars := CtxSeen.pars
    Assert.True(pars.List is Array, "a list stays an Array")
    Assert.Equal(pars.List.Length, 2)
    Assert.Equal(pars.list[2], "y", "case-insensitive property")
    Assert.True(pars.Obj is Map, "an object is a Map")
    Assert.Equal(pars.Obj["k"], 1)
    Assert.Equal(pars.Nothing, "", "null is the empty text")
    Assert.Equal(pars.Num, 5)
}

AnElementThatDoesNotExistIsAnElementError() {
    owner := BuildFlow()
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(CtxSeen.error, "the flow has no element 'nothere'")
}

TheParametersAreACopy() {
    owner := BuildFlow()
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    CtxSeen.pars.List.Push("z")
    CtxSeen.pars.Obj["k"] := 99
    again := owner.flows.Get("f").Def.ElementPars("b")
    Assert.Equal(again.List.Length, 2, "the flow definition did not change")
    Assert.Equal(again.Obj["K"], 1)
}

StopInstanceAfterFinishEndsTheInstanceWithTheReason() {
    owner := BuildFlow()
    instId := owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(CtxSeen.stopped, true, "the instance was running")
    Assert.Equal(owner.executor.IsExecuting("f"), false)
    ended := ""
    for ev in owner.events {
        if (ev["type"] = "evt.instance.ended")
            ended := ev["payload"]
    }
    Assert.True(IsObject(ended), "evt.instance.ended")
    Assert.Equal(ended["instanceId"], instId)
    Assert.Equal(ended["reason"], "element.stop")
    Assert.Equal(Probe.Count("d"), 0, "the element behind the stopping element did not run")
}

FlowFunctionsNeedAnInlineHost() {
    ctx := ExecContext("f", "e", "i", "t")
    e := Assert.Throws(() => ctx.GetElementIdsOfClass("X"), ElementError)
    Assert.Equal(e.Message, "the flow functions are only available in an inline element")
    Assert.Throws(() => ctx.GetElementPars("e"), ElementError)
    Assert.Throws(() => ctx.StopInstance(), ElementError)
}

TestRun.Init()

TestRun.Case("GetElementIdsOfClass: IDs in the order of the flow, class in any case", IdsOfAClassComeInTheOrderOfTheFlowAndIgnoreCase)
TestRun.Case("GetElementPars: lists, objects and numbers keep their type, null is empty", ParametersKeepTheirTypes)
TestRun.Case("GetElementPars: an unknown element is an ElementError", AnElementThatDoesNotExistIsAnElementError)
TestRun.Case("GetElementPars: the result is a copy", TheParametersAreACopy)
TestRun.Case("StopInstance after Finish: the instance ends with reason element.stop", StopInstanceAfterFinishEndsTheInstanceWithTheReason)
TestRun.Case("The flow functions throw without an engine host", FlowFunctionsNeedAnInlineHost)

TestRun.Finish()
