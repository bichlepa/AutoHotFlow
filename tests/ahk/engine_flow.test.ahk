#Requires AutoHotkey v2.0
; Unit tests for src/engine/core/FlowDefinition.ahk (WI-08, ARCHITECTURE 7).
; The example flows are read at run time from tests/data/flows/v1_examples (read only).
#Include lib\Assert.ahk
#Include ..\..\src\engine\core\FlowDefinition.ahk

SavedFlowsDir() {
    return A_ScriptDir "\..\data\flows\v1_examples"
}

; Reads a file as text, without a leading UTF-8 byte order mark.
ReadText(path) {
    text := FileRead(path, "UTF-8")
    if (SubStr(text, 1, 1) = Chr(0xFEFF))
        text := SubStr(text, 2)
    return text
}

; Joins lines with newlines. Flow texts are written as single-quoted lines.
Lines(parts*) {
    out := ""
    for i, p in parts
        out .= ((i > 1) ? "`n" : "") p
    return out
}

; Small handmade flow: trigger e1 -> action e2 -> action e3, plus an extra key "futureKey".
HandmadeFlowText() {
    return Lines(
        '{"name":"hand","category":"Tests","ElementIDCounter":"4","futureKey":5,',
        '"flowSettings":{"ExecutionPolicy":"default","zoomFactor":"0.7"},',
        '"allElements":{',
        '"e1":{"ID":"e1","type":"trigger","class":"trigger_Manual","pars":{}},',
        '"e2":{"ID":"e2","type":"Action","class":"action_Sleep","pars":{"x":7},"extra":{"a":"b"}},',
        '"e3":{"ID":"e3","type":"action","class":"action_Do_nothing","pars":{}}},',
        '"allConnections":{',
        '"c1":{"ID":"c1","from":"e1","to":"e2","type":"Connection","ConnectionType":"normal"},',
        '"c2":{"ID":"c2","from":"e2","to":"e3","type":"Connection","ConnectionType":"Normal"}}}'
    )
}

; Flow with a dangling connection (to is empty) and one trigger "Trigger" in another spelling.
DanglingFlowText() {
    return Lines(
        '{"allElements":{',
        '"e1":{"ID":"e1","type":"Trigger","class":"trigger_Manual","pars":{}},',
        '"e2":{"ID":"e2","type":"Action","class":"action_Do_nothing","pars":{}}},',
        '"allConnections":{',
        '"c1":{"ID":"c1","from":"e1","to":"e2","type":"Connection","ConnectionType":"normal"},',
        '"c2":{"ID":"c2","from":"e2","to":"","type":"Connection","ConnectionType":"normal"},',
        '"c3":{"ID":"c3","from":"","to":"e2","type":"Connection","ConnectionType":"normal"}}}'
    )
}

LoadAllSavedFlows() {
    dir := SavedFlowsDir()
    failures := []
    count := 0
    loop files, dir "\*.json" {
        count += 1
        try {
            flow := FlowDefinition.FromText(A_LoopFileName, ReadText(A_LoopFilePath))
            if (flow.Triggers().Length < 1)
                failures.Push(A_LoopFileName ": no trigger element")
        } catch as e {
            failures.Push(A_LoopFileName ": " Type(e) ": " e.Message)
        }
    }
    Assert.True(count > 0, "no flow files found in " dir)
    if (failures.Length > 0)
        throw AssertFailed(failures.Length " of " count " flows failed: " failures[1])
}

KnownFlowDetails() {
    flow := FlowDefinition.FromText("464187831", ReadText(SavedFlowsDir() "\Flow 464187831.json"))
    Assert.Equal(flow.Name, "New flow 1")
    Assert.Equal(flow.Rev, 1)
    Assert.Equal(flow.Dangling.Length, 0)
    Assert.Equal(flow.Triggers()[1], "element0000000001")
    Assert.Equal(flow.ElementKind("element0000000001"), "trigger")
    Assert.Equal(flow.ElementKind("element0000000004"), "action")
    Assert.Equal(flow.ElementClass("element0000000004"), "action_Encode_string")
    Assert.Equal(flow.FromConnections("element0000000001")[1], "connection0000000003")
    Assert.Equal(flow.Connection("connection0000000003")["to"], "element0000000004")
    Assert.Equal(flow.Raw["flowSettings"]["ExecutionPolicy"], "default")
}

DanglingFlowFromRealFile() {
    flow := FlowDefinition.FromText("369404488", ReadText(SavedFlowsDir() "\Flow 369404488.json"))
    Assert.True(flow.Dangling.Length > 0, "expected dangling connections in this flow")
    for id in flow.Dangling {
        for el in flow.Raw["allElements"] {
            Assert.True(!ArrayHas(flow.FromConnections(el), id), "dangling connection " id " is listed as outgoing")
        }
    }
}

ArrayHas(arr, value) {
    for item in arr {
        if (item = value)
            return true
    }
    return false
}

HandmadeFlowLookups() {
    flow := FlowDefinition.FromText("hand", HandmadeFlowText(), 7)
    Assert.Equal(flow.Name, "hand")
    Assert.Equal(flow.Category, "Tests")
    Assert.Equal(flow.Rev, 7)
    Assert.Equal(flow.Triggers().Length, 1)
    Assert.Equal(flow.Triggers()[1], "e1")
    Assert.Equal(flow.ElementKind("e2"), "action")
    Assert.Equal(flow.ElementClass("e2"), "action_Sleep")
    Assert.Equal(flow.FromConnections("e1").Length, 1)
    Assert.Equal(flow.FromConnections("e1")[1], "c1")
    Assert.Equal(flow.FromConnections("e3").Length, 0)
    Assert.Equal(flow.Connection("c2")["ConnectionType"], "Normal")
    Assert.Equal(flow.Dangling.Length, 0)
}

UnknownKeysAreKept() {
    flow := FlowDefinition.FromText("hand", HandmadeFlowText())
    Assert.Equal(flow.Raw["futureKey"], 5)
    Assert.Equal(flow.Raw["allElements"]["e2"]["extra"]["a"], "b")
    Assert.Equal(flow.Raw["allElements"]["e2"]["pars"]["x"], 7)
    Assert.Equal(flow.Raw["flowSettings"]["zoomFactor"], "0.7")
}

KindAndTriggerAreCaseInsensitive() {
    flow := FlowDefinition.FromText("dangling", DanglingFlowText())
    Assert.Equal(flow.ElementKind("e1"), "trigger")
    Assert.Equal(flow.Triggers().Length, 1)
    Assert.Equal(flow.Triggers()[1], "e1")
}

DanglingConnectionsAreListedNotReturned() {
    flow := FlowDefinition.FromText("dangling", DanglingFlowText())
    Assert.Equal(flow.Dangling.Length, 2)
    Assert.True(ArrayHas(flow.Dangling, "c2"))
    Assert.True(ArrayHas(flow.Dangling, "c3"))
    Assert.Equal(flow.FromConnections("e1").Length, 1)
    Assert.Equal(flow.FromConnections("e2").Length, 0)
}

UnknownIdsGiveEmptyAnswers() {
    flow := FlowDefinition.FromText("hand", HandmadeFlowText())
    Assert.Equal(flow.HasElement("nope"), false)
    Assert.Equal(flow.ElementKind("nope"), "")
    Assert.Equal(flow.ElementClass("nope"), "")
    Assert.Equal(flow.Connection("nope"), "")
    Assert.Equal(flow.FromConnections("nope").Length, 0)
}

ReadErrorFromText(text) {
    return Assert.Throws(FromTextCall.Bind(text), AhfError)
}

FromTextCall(text) {
    FlowDefinition.FromText("bad", text)
}

BrokenJsonGivesBadJson() {
    err := ReadErrorFromText('{"allElements":')
    Assert.Equal(err.code, "bad_json")
    Assert.True(InStr(err.Message, "bad") > 0)
}

EmptyTextGivesBadJson() {
    err := ReadErrorFromText("")
    Assert.Equal(err.code, "bad_json")
}

RootArrayGivesBadPayload() {
    err := ReadErrorFromText("[1,2]")
    Assert.Equal(err.code, "bad_payload")
}

MissingAllConnectionsGivesBadPayload() {
    err := ReadErrorFromText('{"allElements":{}}')
    Assert.Equal(err.code, "bad_payload")
    Assert.True(InStr(err.Message, "allConnections") > 0)
}

AllElementsAsArrayGivesBadPayload() {
    err := ReadErrorFromText('{"allElements":[],"allConnections":{}}')
    Assert.Equal(err.code, "bad_payload")
}

ElementWithoutTypeGivesBadPayload() {
    err := ReadErrorFromText('{"allElements":{"e1":{"class":"x"}},"allConnections":{}}')
    Assert.Equal(err.code, "bad_payload")
}

ElementThatIsNotAnObjectGivesBadPayload() {
    err := ReadErrorFromText('{"allElements":{"e1":5},"allConnections":{}}')
    Assert.Equal(err.code, "bad_payload")
}

ConnectionWithoutConnectionTypeGivesBadPayload() {
    err := ReadErrorFromText('{"allElements":{},"allConnections":{"c1":{"from":"","to":""}}}')
    Assert.Equal(err.code, "bad_payload")
}

ObjectValueInNameGivesBadPayload() {
    err := ReadErrorFromText('{"name":{"x":1},"allElements":{},"allConnections":{}}')
    Assert.Equal(err.code, "bad_payload")
}

TestRun.Init()

TestRun.Case("all v1 saved flows load and have at least one trigger", LoadAllSavedFlows)
TestRun.Case("flow 464187831 has the expected names, kinds, classes and connections", KnownFlowDetails)
TestRun.Case("flow 369404488 lists its dangling connections and never as outgoing", DanglingFlowFromRealFile)
TestRun.Case("handmade flow answers lookups by element and connection", HandmadeFlowLookups)
TestRun.Case("keys the model does not know are kept in Raw", UnknownKeysAreKept)
TestRun.Case("element kinds and triggers are matched case-insensitively", KindAndTriggerAreCaseInsensitive)
TestRun.Case("connections with empty or unknown ends are dangling and not outgoing", DanglingConnectionsAreListedNotReturned)
TestRun.Case("unknown IDs give empty answers, not errors", UnknownIdsGiveEmptyAnswers)
TestRun.Case("broken JSON gives AhfError bad_json", BrokenJsonGivesBadJson)
TestRun.Case("empty text gives AhfError bad_json", EmptyTextGivesBadJson)
TestRun.Case("a JSON array as root gives bad_payload", RootArrayGivesBadPayload)
TestRun.Case("missing allConnections gives bad_payload with the key name", MissingAllConnectionsGivesBadPayload)
TestRun.Case("allElements as array gives bad_payload", AllElementsAsArrayGivesBadPayload)
TestRun.Case("element without type gives bad_payload", ElementWithoutTypeGivesBadPayload)
TestRun.Case("element that is a number gives bad_payload", ElementThatIsNotAnObjectGivesBadPayload)
TestRun.Case("connection without ConnectionType gives bad_payload", ConnectionWithoutConnectionTypeGivesBadPayload)
TestRun.Case("name that is an object gives bad_payload", ObjectValueInNameGivesBadPayload)

TestRun.Finish()
