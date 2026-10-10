#Requires AutoHotkey v2.0
; Unit tests for src/core/ipc/Message.ahk (WI-05): envelope serialization, parsing, ReadTo.
; Cases are named functions with statement bodies (a lambda cannot contain throw, doc/HOW-TO.md).
#Include lib\Assert.ahk
#Include ..\..\src\core\ipc\Message.ahk

ParseText(text) {
    return Message.Parse(text)
}

ReadToText(text) {
    return Message.ReadTo(text)
}

CaseSerializeHeadOrder() {
    text := Message("engine", "editor:F1", "editor:F1#17", "cmd.flow.start", Map("flowId", "F1"), "", 5000).Serialize()
    Assert.Equal(text, '{"to":"engine","from":"editor:F1","id":"editor:F1#17","type":"cmd.flow.start","corr":null,'
        . '"timeoutMs":5000,"payload":{"flowId":"F1"}}')
}

CaseAnswerCarriesCorr() {
    text := Message("a", "b", "b#1", "res.x", Map(), "b#1").Serialize()
    Assert.Equal(text, '{"to":"a","from":"b","id":"b#1","type":"res.x","corr":"b#1","payload":{}}')
}

CasePayloadTypesAndKeyOrder() {
    text := Message("a", "b", "b#2", "evt.x", Map("zoomFactor", "0.700000", "n", 3, "a", 1.5)).Serialize()
    Assert.Equal(text, '{"to":"a","from":"b","id":"b#2","type":"evt.x","corr":null,'
        . '"payload":{"a":1.5,"n":3,"zoomFactor":"0.700000"}}')
}

CaseRoundTrip() {
    text := Message("engine", "ui", "ui#4", "cmd.flow.get", Map("flowId", "Flow 1"), "", 30000).Serialize()
    m := Message.Parse(text)
    Assert.Equal(m.to, "engine")
    Assert.Equal(m.from, "ui")
    Assert.Equal(m.id, "ui#4")
    Assert.Equal(m.type, "cmd.flow.get")
    Assert.Equal(m.corr, "")
    Assert.Equal(m.timeoutMs, 30000)
    Assert.Equal(m.payload["flowId"], "Flow 1")
}

CaseParseAcceptsNullCorrAndNoTimeout() {
    m := Message.Parse('{"to":"a","from":"b","id":"b#1","type":"res.x","corr":null,"payload":{"ok":1}}')
    Assert.Equal(m.corr, "")
    Assert.Equal(m.timeoutMs, 0)
    Assert.Equal(m.payload["ok"], 1)
}

CaseParseKeepsNumericLookingString() {
    m := Message.Parse('{"to":"a","from":"b","id":"b#1","type":"evt.x","payload":{"zoom":"0.700000"}}')
    Assert.Equal(m.payload["zoom"], "0.700000")
}

CaseParseRejectsMissingTo() {
    e := Assert.Throws(() => ParseText('{"from":"b","id":"b#1","type":"cmd.x","payload":{}}'), ProtocolError)
    Assert.Equal(e.code, "bad_payload")
}

CaseParseRejectsEmptyId() {
    Assert.Throws(() => ParseText('{"to":"a","from":"b","id":"","type":"cmd.x","payload":{}}'), ProtocolError)
}

CaseParseRejectsPayloadNotObject() {
    Assert.Throws(() => ParseText('{"to":"a","from":"b","id":"b#1","type":"cmd.x","payload":5}'), ProtocolError)
}

CaseParseRejectsMissingPayload() {
    Assert.Throws(() => ParseText('{"to":"a","from":"b","id":"b#1","type":"cmd.x"}'), ProtocolError)
}

CaseParseRejectsTimeoutAsString() {
    Assert.Throws(() => ParseText('{"to":"a","from":"b","id":"b#1","type":"cmd.x","timeoutMs":"5","payload":{}}'),
        ProtocolError)
}

CaseParseRejectsCorrNumber() {
    Assert.Throws(() => ParseText('{"to":"a","from":"b","id":"b#1","type":"res.x","corr":7,"payload":{}}'),
        ProtocolError)
}

CaseParseRejectsInvalidJsonWithBadPayload() {
    e := Assert.Throws(() => ParseText('{"to":'), ProtocolError)
    Assert.Equal(e.code, "bad_payload")
}

CaseParseRejectsArray() {
    Assert.Throws(() => ParseText('[1,2]'), ProtocolError)
}

CaseReadToMatchesSerialized() {
    text := Message("topic:engine", "x", "x#1", "evt.engine.ready", Map("epoch", 1)).Serialize()
    Assert.Equal(ReadToText(text), "topic:engine")
}

CaseReadToIgnoresBrokenPayload() {
    Assert.Equal(ReadToText('{"to":"storage","from":"engine","id":"e#1","type":"cmd.x","payload":{broken'), "storage")
}

CaseReadToUnescapes() {
    text := Message('a"b\c', "x", "x#1", "evt.x").Serialize()
    Assert.Equal(ReadToText(text), 'a"b\c')
}

CaseReadToRejectsOtherFirstField() {
    Assert.Throws(() => ReadToText('{"from":"x","to":"y","payload":{}}'), ProtocolError)
}

CaseReadToRejectsEmptyTo() {
    Assert.Throws(() => ReadToText('{"to":"","from":"x"}'), ProtocolError)
}

TestRun.Init()
TestRun.Case("serialize writes the head fields in fixed order", CaseSerializeHeadOrder)
TestRun.Case("answer carries corr and leaves out timeoutMs when 0", CaseAnswerCarriesCorr)
TestRun.Case("payload keeps value types and sorts its keys", CasePayloadTypesAndKeyOrder)
TestRun.Case("serialized text parses back with the same fields", CaseRoundTrip)
TestRun.Case("parse accepts corr null and a missing timeoutMs", CaseParseAcceptsNullCorrAndNoTimeout)
TestRun.Case("parse keeps a numeric-looking string as a string", CaseParseKeepsNumericLookingString)
TestRun.Case("parse rejects a missing to field with bad_payload", CaseParseRejectsMissingTo)
TestRun.Case("parse rejects an empty id", CaseParseRejectsEmptyId)
TestRun.Case("parse rejects a payload that is not an object", CaseParseRejectsPayloadNotObject)
TestRun.Case("parse rejects a missing payload", CaseParseRejectsMissingPayload)
TestRun.Case("parse rejects a timeoutMs given as string", CaseParseRejectsTimeoutAsString)
TestRun.Case("parse rejects corr that is a number", CaseParseRejectsCorrNumber)
TestRun.Case("parse rejects invalid JSON with bad_payload", CaseParseRejectsInvalidJsonWithBadPayload)
TestRun.Case("parse rejects a JSON array as envelope", CaseParseRejectsArray)
TestRun.Case("ReadTo returns the to field of a serialized envelope", CaseReadToMatchesSerialized)
TestRun.Case("ReadTo does not need a valid payload", CaseReadToIgnoresBrokenPayload)
TestRun.Case("ReadTo unescapes quotes and backslashes", CaseReadToUnescapes)
TestRun.Case("ReadTo rejects a text whose first field is not to", CaseReadToRejectsOtherFirstField)
TestRun.Case("ReadTo rejects an empty to", CaseReadToRejectsEmptyTo)
TestRun.Finish()
