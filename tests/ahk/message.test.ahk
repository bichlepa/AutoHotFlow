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

; --- ParseHead / WithFrom (WI-24): head fields without parsing the payload ---------------------------------

CaseParseHeadReadsAllFields() {
    text := Message("engine", "editor:F1", "editor:F1#17", "cmd.flow.start", Map("flowId", "F1"), "", 5000).Serialize()
    h := Message.ParseHead(text)
    Assert.True(IsObject(h))
    Assert.Equal(h["to"], "engine")
    Assert.Equal(h["from"], "editor:F1")
    Assert.Equal(h["id"], "editor:F1#17")
    Assert.Equal(h["type"], "cmd.flow.start")
    Assert.Equal(h["corr"], "")
    Assert.Equal(h["timeoutMs"], 5000)
}

CaseParseHeadReadsCorrAndNoTimeout() {
    h := Message.ParseHead(Message("a", "b", "b#2", "res.x", Map("ok", 1), "a#9").Serialize())
    Assert.Equal(h["corr"], "a#9")
    Assert.Equal(h["timeoutMs"], 0)
}

CaseParseHeadUnescapesStrings() {
    h := Message.ParseHead(Message('t"o', 'fr\om', "x#1", "evt.x").Serialize())
    Assert.Equal(h["to"], 't"o')
    Assert.Equal(h["from"], 'fr\om')
}

CaseParseHeadAcceptsBracesAndQuotesInsideThePayload() {
    payload := Map("text", '{"a": "}", "b": [1, {"c": "\"}"}]}', "n", Map("deep", Map("deeper", Map())))
    h := Message.ParseHead(Message("a", "b", "b#1", "evt.x", payload).Serialize())
    Assert.True(IsObject(h))
}

CaseParseHeadDoesNotCheckThePayloadContent() {
    ; the receiver rejects it (Peer._RejectFrame); the hub only needs the head and the end of the payload
    h := Message.ParseHead('{"to":"a","from":"b","id":"b#1","type":"cmd.x","corr":null,"payload":{broken:1}}')
    Assert.True(IsObject(h))
    Assert.Equal(h["to"], "a")
}

CaseParseHeadGivesUpOnNonCanonicalText() {
    ; each of these takes the normal way (Parse), which judges them
    Assert.Equal(Message.ParseHead('{"from":"b","to":"a","id":"b#1","type":"cmd.x","corr":null,"payload":{}}'), "")
    Assert.Equal(Message.ParseHead('{"to": "a","from":"b","id":"b#1","type":"cmd.x","corr":null,"payload":{}}'), "")
    Assert.Equal(Message.ParseHead('{"to":"a","from":"b","id":"b#1","type":"cmd.x","payload":{}}'), "")
    Assert.Equal(Message.ParseHead('{"to":"a","from":"b","id":"b#1","type":"cmd.x","corr":null,"payload":5}'), "")
    Assert.Equal(Message.ParseHead('{"to":"a","from":"b","id":"b#1","type":"cmd.x","corr":null,"payload":[]}'), "")
    Assert.Equal(Message.ParseHead('{"to":"a","from":"b","id":"b#1","type":"cmd.x","corr":7,"payload":{}}'), "")
    Assert.Equal(Message.ParseHead('{"to":"","from":"b","id":"b#1","type":"cmd.x","corr":null,"payload":{}}'), "")
    Assert.Equal(Message.ParseHead('{"to":"a","from":"b","id":"b#1","type":"cmd.x","corr":null,"payload":{}} '), "")
    Assert.Equal(Message.ParseHead(""), "")
}

CaseParseHeadRefusesAnythingAfterThePayload() {
    ; a second "from" behind the payload would win in a parser that keeps the last duplicate key
    forged := '{"to":"a","from":"b","id":"b#1","type":"evt.x","corr":null,"payload":{},"from":"forged"}'
    Assert.Equal(Message.ParseHead(forged), "")
    forged2 := '{"to":"a","from":"b","id":"b#1","type":"evt.x","corr":null,"payload":{"k":1},"x":{}}'
    Assert.Equal(Message.ParseHead(forged2), "")
    forged3 := '{"to":"a","from":"b","id":"b#1","type":"evt.x","corr":null,"payload":{}},"from":"forged"}'
    Assert.Equal(Message.ParseHead(forged3), "")
}

CaseWithFromKeepsPayloadAndOtherHeadFields() {
    payload := Map("text", "a\b", "list", [1, 2], "z", "0.700000")
    text := Message("topic:engine", "forged", "x#4", "evt.x", payload, "", 0).Serialize()
    out := Message.WithFrom(text, Message.ParseHead(text), "real:1")
    Assert.Equal(out, Message("topic:engine", "real:1", "x#4", "evt.x", payload).Serialize())
    m := Message.Parse(out)
    Assert.Equal(m.from, "real:1")
    Assert.Equal(m.payload["text"], "a\b")
}

CaseWithFromOnALargeFrame() {
    big := ""
    loop 2000
        big .= '{"k": "v\\", "n": [1, 2, 3]} '
    text := Message("engine", "storage", "storage#1", "res.storage.flow.read", Map("ok", 1, "text", big), "engine#1").Serialize()
    h := Message.ParseHead(text)
    Assert.True(IsObject(h))
    out := Message.WithFrom(text, h, "storage")
    Assert.Equal(out, text)
}

TestRun.Init()
TestRun.Case("ParseHead reads all head fields of a serialized envelope", CaseParseHeadReadsAllFields)
TestRun.Case("ParseHead reads corr and a missing timeoutMs", CaseParseHeadReadsCorrAndNoTimeout)
TestRun.Case("ParseHead unescapes quotes and backslashes", CaseParseHeadUnescapesStrings)
TestRun.Case("ParseHead handles braces and quotes inside the payload", CaseParseHeadAcceptsBracesAndQuotesInsideThePayload)
TestRun.Case("ParseHead does not check the payload content", CaseParseHeadDoesNotCheckThePayloadContent)
TestRun.Case("ParseHead gives up on text that is not in canonical form", CaseParseHeadGivesUpOnNonCanonicalText)
TestRun.Case("ParseHead refuses a text with anything behind the payload", CaseParseHeadRefusesAnythingAfterThePayload)
TestRun.Case("WithFrom replaces only the sender", CaseWithFromKeepsPayloadAndOtherHeadFields)
TestRun.Case("WithFrom keeps a large payload byte for byte", CaseWithFromOnALargeFrame)
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
