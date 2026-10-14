#Requires AutoHotkey v2.0
; The variable requests cmd.engine.var.* of the engine (WI-50, doc/PROTOCOL.md 4.5): VarRequests with a real Executor
; and the stand-in pool of EngineOwner (no processes). A flow sets an instance and a thread variable and then waits in
; a worker element (Test_Wk, its job stays open), so the requests can name the job (execId) or the instance.
#Include helpers\ExecutorKit.ahk
#Include ..\..\src\engine\VarRequests.ahk
#Include ..\..\src\core\ipc\Message.ahk

class Test_SetX extends AhfElement {
    static Mode := "inline"
    static Run(ctx, params) {
        ctx.SetVar("x", "inst value")
        ctx.SetVar("A_T", "thread value", "thread")
        ctx.SetVar("list", ["a", "b"])
        ctx.Finish("normal")
    }
}
ElementRegistry.Register(Test_SetX)

; An owner whose flow waits in the worker element: job fx-1 is open.
Waiting() {
    owner := NewOwner(FlowText([El("s", "Test_SetX"), El("w", "Test_Wk")], [Conn("c1", "t0", "s"), Conn("c2", "s", "w")]))
    owner.instId := owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    owner.req := VarRequests(owner)
    return owner
}

Req(owner, type, payload, from := "worker:fake") => owner.req.Handle(Message("engine", from, "t#1", "cmd.engine.var." type, payload))

Job(payload) {
    payload["execId"] := "fx-1"
    return payload
}

; The error code of an AhfError that fn throws, or "" if it throws nothing.
CodeOf(fn) {
    try {
        fn()
    } catch AhfError as e {
        return e.code
    }
    return ""
}

CheckGetThroughTheJob() {
    owner := Waiting()
    r := Req(owner, "get", Job(Map("name", "x")))
    Assert.Equal(r["exists"], Json.True)
    Assert.Equal(r["value"], "inst value")
    Assert.Equal(r["type"], "normal")
    Assert.Equal(r["location"], "instance")
    r := Req(owner, "get", Job(Map("name", "A_T")))
    Assert.Equal(r["value"] " " r["location"], "thread value thread")
    r := Req(owner, "get", Job(Map("name", "list.2")))
    Assert.Equal(r["value"] " " r["location"], "b instance", "a member")
    r := Req(owner, "get", Job(Map("name", "list")))
    Assert.Equal(r["type"], "object")
    Assert.Equal(r["value"][2], "b")
    r := Req(owner, "get", Job(Map("name", "A_Space")))
    Assert.Equal(r["value"] "|" r["location"], " |builtin")
    r := Req(owner, "get", Job(Map("name", "nothing")))
    Assert.Equal(r["exists"], Json.False)
    Assert.Equal(r["location"] r["type"] r["value"], "")
}

CheckSetDeleteListImport() {
    owner := Waiting()
    Assert.Equal(Req(owner, "set", Job(Map("name", "global_g", "value", 5)))["accepted"], Json.True)
    Assert.Equal(owner.vars.Global["global_g"], 5, "the engine owns the value")
    Assert.Equal(Req(owner, "set", Job(Map("name", "A_x", "value", 1)))["accepted"], Json.False, "A_ needs a scope")
    Assert.Equal(Req(owner, "set", Job(Map("name", "A_x", "value", 1, "scope", "thread")))["accepted"], Json.True)
    Assert.Equal(Req(owner, "set", Job(Map("name", "h", "value", "hid", "hidden", 1)))["accepted"], Json.True)
    Assert.Equal(Req(owner, "get", Job(Map("name", "h")))["exists"], Json.False, "hidden is not visible")
    Assert.Equal(Req(owner, "get", Job(Map("name", "h", "hidden", 1)))["value"], "hid")
    names := Req(owner, "list", Job(Map("scope", "instance", "withValues", 1)))
    Assert.Equal(names["names"].Length, 2)
    Assert.Equal(names["values"]["x"], "inst value")
    Req(owner, "import", Job(Map("vars", Map("imp", 7))))
    Assert.Equal(Req(owner, "get", Job(Map("name", "imp")))["value"], 7)
    Assert.Equal(Req(owner, "delete", Job(Map("name", "imp")))["existed"], Json.True)
    Assert.Equal(Req(owner, "delete", Job(Map("name", "imp")))["existed"], Json.False)
    Assert.Equal(CodeOf(() => Req(owner, "import", Job(Map("vars", "no")))), ErrCode.BAD_PAYLOAD)
}

CheckReplaceAndEval() {
    owner := Waiting()
    Assert.Equal(Req(owner, "replace", Job(Map("text", "a %x% b")))["text"], "a inst value b")
    Assert.Equal(Req(owner, "eval", Job(Map("text", "list[1] . x")))["value"], "ainst value")
    Assert.Equal(Req(owner, "eval", Job(Map("text", "a := 2`nb := a * 3", "kind", "script")))["value"], 6)
    r := Req(owner, "eval", Job(Map("text", "1 +")))
    Assert.True(r.Has("elementError") && r["elementError"] != "", "an expression error is an element error")
    Assert.Equal(CodeOf(() => Req(owner, "eval", Job(Map("text", "1", "kind", "other")))), ErrCode.BAD_PAYLOAD)
    r := Req(owner, "set", Job(Map("name", "global_h", "value", 1, "hidden", 1)))
    Assert.True(InStr(r["elementError"], "cannot be hidden"), "the inline error text")
    r := Req(owner, "list", Job(Map("scope", "nowhere")))
    Assert.True(InStr(r["elementError"], "unknown variable scope"))
}

CheckAddressGoneAndDenied() {
    owner := Waiting()
    Assert.Equal(CodeOf(() => Req(owner, "get", Job(Map("name", "x")), "worker:other")), ErrCode.DENIED)
    Assert.Equal(CodeOf(() => Req(owner, "get", Map("name", "x"))), ErrCode.BAD_PAYLOAD, "no address")
    Assert.Equal(CodeOf(() => Req(owner, "get", Map("name", "x", "execId", "fx-1", "instanceId", owner.instId)))
        , ErrCode.BAD_PAYLOAD, "two addresses")
    Assert.Equal(CodeOf(() => Req(owner, "get", Map("name", "x", "execId", "fx-9"))), ErrCode.GONE, "unknown job")
    owner.executor.StopInstance(owner.instId, "test")
    Assert.Equal(CodeOf(() => Req(owner, "get", Job(Map("name", "x")))), ErrCode.GONE, "a stopped job is gone")
    Assert.Equal(CodeOf(() => Req(owner, "get", Map("name", "x", "instanceId", owner.instId))), ErrCode.GONE
        , "an ended instance is gone")
}

CheckFinishedJobIsGone() {
    owner := Waiting()
    owner.workers.Complete("fx-1", "normal")
    owner.Drive()
    Assert.Equal(CodeOf(() => Req(owner, "get", Job(Map("name", "x")))), ErrCode.GONE)
}

CheckInstanceAddress() {
    owner := Waiting()
    threadId := owner.workers.payloads["fx-1"]["ctx"].threadId
    r := Req(owner, "get", Map("name", "x", "instanceId", owner.instId), "flowrun")
    Assert.Equal(r["value"], "inst value", "a client reads an instance variable")
    Assert.Equal(Req(owner, "get", Map("name", "A_T", "instanceId", owner.instId), "flowrun")["exists"], Json.False
        , "no thread variables without a thread")
    Assert.Equal(CodeOf(() => Req(owner, "set", Map("name", "A_T", "value", 1, "scope", "thread"
        , "instanceId", owner.instId), "flowrun")), ErrCode.BAD_PAYLOAD, "setting an A_ variable needs a thread")
    r := Req(owner, "get", Map("name", "A_T", "instanceId", owner.instId, "threadId", threadId), "flowrun")
    Assert.Equal(r["value"], "thread value", "with the thread")
    Assert.Equal(Req(owner, "set", Map("name", "y", "value", "from client", "instanceId", owner.instId), "flowrun")["accepted"]
        , Json.True)
    Assert.Equal(owner.workers.payloads["fx-1"]["ctx"].GetVar("y"), "from client", "the element sees the change")
    Assert.Equal(CodeOf(() => Req(owner, "get", Map("name", "x", "instanceId", owner.instId, "threadId", "thr-none")
        , "flowrun")), ErrCode.GONE, "unknown thread")
}

TestRun.Case("get through the job: value, type and location", CheckGetThroughTheJob)
TestRun.Case("set, hidden, delete, list with values, import", CheckSetDeleteListImport)
TestRun.Case("replace and eval; errors of the operation are element errors", CheckReplaceAndEval)
TestRun.Case("address: denied for another worker, bad_payload, gone after a stop", CheckAddressGoneAndDenied)
TestRun.Case("a finished job is gone", CheckFinishedJobIsGone)
TestRun.Case("instance address of a client, with and without a thread", CheckInstanceAddress)
TestRun.Finish()
