#Requires AutoHotkey v2.0
; Unit tests for src/core/ipc/Dispatcher.ahk (WI-05): prefix routing, unknown types, error answers.
#Include lib\Assert.ahk
#Include ..\..\src\core\ipc\Dispatcher.ahk

; Handler helpers as named functions (a lambda cannot throw, and handlers must not be static methods).
ThrowAhf(msg) {
    throw AhfError("probe failed", ErrCode.BUSY)
}

ThrowPlain(msg) {
    throw ValueError("plain failure")
}

ReturnNothing(msg) {
}

ReturnPlainMap(msg) {
    return Map("value", 42)
}

ReturnBadType(msg) {
    return "text"
}

Incoming(msgType) {
    return Message("engine", "ui", "ui#1", msgType, Map("flowId", "F1"), "", 5000)
}

CaseExactTypeHandled() {
    d := Dispatcher()
    d.On("cmd.flow.start", (msg) => Map("instanceId", "i" msg.payload["flowId"]))
    res := d.Invoke(Incoming("cmd.flow.start"))
    Assert.Equal(res["ok"], true)
    Assert.Equal(res["instanceId"], "iF1")
}

CaseLongestPrefixWins() {
    d := Dispatcher()
    d.On("cmd.", (msg) => Map("which", "general"))
    d.On("cmd.flow.", (msg) => Map("which", "flow"))
    Assert.Equal(d.Invoke(Incoming("cmd.flow.start"))["which"], "flow")
    Assert.Equal(d.Invoke(Incoming("cmd.engine.snapshot"))["which"], "general")
}

CaseRegistrationOrderDoesNotMatter() {
    d := Dispatcher()
    d.On("cmd.flow.", (msg) => Map("which", "flow"))
    d.On("cmd.", (msg) => Map("which", "general"))
    Assert.Equal(d.Invoke(Incoming("cmd.flow.save"))["which"], "flow")
}

CasePrefixMustMatchStart() {
    d := Dispatcher()
    d.On("flow.", (msg) => Map("which", "flow"))
    res := d.Invoke(Incoming("cmd.flow.start"))
    Assert.Equal(res["ok"], false)
    Assert.Equal(res["error"]["code"], "unknown_type")
}

CaseUnknownTypeAnswered() {
    d := Dispatcher()
    res := d.Invoke(Incoming("cmd.nothing.here"))
    Assert.Equal(res["ok"], false)
    Assert.Equal(res["error"]["code"], "unknown_type")
    Assert.True(InStr(res["error"]["message"], "cmd.nothing.here"))
}

CaseMissingOkIsAdded() {
    d := Dispatcher()
    d.On("cmd.x", ReturnPlainMap)
    res := d.Invoke(Incoming("cmd.x"))
    Assert.Equal(res["ok"], true)
    Assert.Equal(res["value"], 42)
}

CaseExplicitOkIsKept() {
    d := Dispatcher()
    d.On("cmd.x", (msg) => Map("ok", false, "error", Map("code", "not_found", "message", "gone")))
    res := d.Invoke(Incoming("cmd.x"))
    Assert.Equal(res["ok"], false)
    Assert.Equal(res["error"]["code"], "not_found")
}

CaseHandlerReturningNothingIsOk() {
    d := Dispatcher()
    d.On("evt.", ReturnNothing)
    res := d.Invoke(Incoming("evt.x"))
    Assert.Equal(res["ok"], true)
}

CaseHandlerReturningWrongTypeIsInternalError() {
    d := Dispatcher()
    d.On("cmd.x", ReturnBadType)
    res := d.Invoke(Incoming("cmd.x"))
    Assert.Equal(res["ok"], false)
    Assert.Equal(res["error"]["code"], "internal")
}

CaseAhfErrorKeepsItsCode() {
    d := Dispatcher()
    d.On("cmd.x", ThrowAhf)
    res := d.Invoke(Incoming("cmd.x"))
    Assert.Equal(res["ok"], false)
    Assert.Equal(res["error"]["code"], "busy")
    Assert.True(InStr(res["error"]["message"], "probe failed"))
}

CasePlainErrorBecomesInternal() {
    d := Dispatcher()
    d.On("cmd.x", ThrowPlain)
    res := d.Invoke(Incoming("cmd.x"))
    Assert.Equal(res["ok"], false)
    Assert.Equal(res["error"]["code"], "internal")
    Assert.True(InStr(res["error"]["message"], "plain failure"))
}

CaseHandlerReceivesMessage() {
    seen := Map("type", "")
    d := Dispatcher()
    d.On("cmd.", (msg) => seen.Set("type", msg.type))
    d.Invoke(Incoming("cmd.flow.get"))
    Assert.Equal(seen["type"], "cmd.flow.get")
}

CaseFindReturnsHandlerOrEmpty() {
    d := Dispatcher()
    d.On("evt.", ReturnNothing)
    Assert.True(IsObject(d.Find("evt.engine.ready")))
    Assert.Equal(d.Find("cmd.engine.ready"), "")
}

CaseOnRejectsEmptyPrefix() {
    d := Dispatcher()
    Assert.Throws(() => d.On("", ReturnNothing), AhfError)
}

CaseOnRejectsNonFunction() {
    d := Dispatcher()
    Assert.Throws(() => d.On("cmd.", "notAFunction"), AhfError)
}

TestRun.Init()
TestRun.Case("exact type is handled and gets ok", CaseExactTypeHandled)
TestRun.Case("longest prefix wins", CaseLongestPrefixWins)
TestRun.Case("registration order does not change the choice", CaseRegistrationOrderDoesNotMatter)
TestRun.Case("a prefix must match the start of the type", CasePrefixMustMatchStart)
TestRun.Case("unknown type is answered with unknown_type", CaseUnknownTypeAnswered)
TestRun.Case("a handler result without ok gets ok true", CaseMissingOkIsAdded)
TestRun.Case("an explicit ok:false from a handler is kept", CaseExplicitOkIsKept)
TestRun.Case("a handler returning nothing gives ok true", CaseHandlerReturningNothingIsOk)
TestRun.Case("a handler returning a non-Map is an internal error", CaseHandlerReturningWrongTypeIsInternalError)
TestRun.Case("an AhfError thrown by a handler keeps its code", CaseAhfErrorKeepsItsCode)
TestRun.Case("a plain error thrown by a handler becomes internal", CasePlainErrorBecomesInternal)
TestRun.Case("the handler receives the message", CaseHandlerReceivesMessage)
TestRun.Case("Find gives the handler or empty", CaseFindReturnsHandlerOrEmpty)
TestRun.Case("On rejects an empty prefix", CaseOnRejectsEmptyPrefix)
TestRun.Case("On rejects a non-function handler", CaseOnRejectsNonFunction)
TestRun.Finish()
