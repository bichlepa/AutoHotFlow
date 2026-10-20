#Requires AutoHotkey v2.0
; Unit tests for src/core/FlowPatch.ahk (WI-0093, PROTOCOL 4.2): every operation and its rules, all or nothing, revisions
; that share the unchanged maps, and Inverse (applying the operations and then their inverse gives the original) on
; random lists of operations over the flows of the corpus (tests/data/flows/v1_examples).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\FlowPatch.ahk

CORPUS := A_ScriptDir "\..\data\flows\v1_examples"

Index() {
    m := Map()
    m.CaseSense := "Off"
    return m
}

Elem(id, type, cls, pars := "") {
    el := Map("ID", id, "type", type, "class", cls, "name", id, "package", "Default", "packageVersion", "1.2.0"
        , "x", 0, "y", 0)
    el["pars"] := (pars is Map) ? pars : Map()
    return el
}

Conn(id, from, to, ctype := "normal") {
    return Map("ID", id, "from", from, "to", to, "ConnectionType", ctype, "type", "Connection")
}

; An operation from name and key/value pairs: Op("element.update", "id", "element0000000002", "fields", Map(...)).
Op(name, kv*) {
    item := Map("op", name)
    loop kv.Length // 2
        item[kv[2 * A_Index - 1]] := kv[2 * A_Index]
    return item
}

; A small valid flow: trigger 1 (the default manual trigger) -> 2 (sleep) -> 3 (do nothing), counter "6".
BaseFlow() {
    els := Index()
    els["element0000000001"] := Elem("element0000000001", "trigger", "Trigger_Manual", Map("ID", "T"))
    els["element0000000001"]["DefaultTrigger"] := Json.True
    els["element0000000002"] := Elem("element0000000002", "action", "Action_Sleep"
        , Map("Duration", "200", "Unit", "Milliseconds"))
    els["element0000000003"] := Elem("element0000000003", "action", "Action_Do_nothing")
    cons := Index()
    cons["connection0000000004"] := Conn("connection0000000004", "element0000000001", "element0000000002")
    cons["connection0000000005"] := Conn("connection0000000005", "element0000000002", "element0000000003", "Yes")
    settings := Index()
    settings["ExecutionPolicy"] := "default"
    settings["strictTypes"] := Json.True
    return Map("name", "Base", "category", "", "ElementIDCounter", "6", "flowSettings", settings
        , "allElements", els, "allConnections", cons)
}

; The part of a flow that a patch may change, as text. The counter is not undone by Inverse, so it is left out.
Canon(root) {
    return Json.Stringify(Map("allElements", root["allElements"], "allConnections", root["allConnections"]
        , "flowSettings", root.Get("flowSettings", "")))
}

; Passes if fn throws a bad_payload AhfError whose message contains part.
Refused(fn, part) {
    try {
        fn()
    } catch as e {
        Assert.True(e is AhfError && e.code = ErrCode.BAD_PAYLOAD, "bad_payload expected, got " Type(e) ": " e.Message)
        Assert.True(InStr(e.Message, part) > 0, "message should contain '" part "': " e.Message)
        return
    }
    throw AssertFailed("the operation was accepted, '" part "' was expected to refuse it")
}

; --- add and update of elements --------------------------------------------------------------------------------------

AddsAnElementAndRaisesTheCounterKeepingItsType() {
    raw := BaseFlow()
    after := FlowPatch.Apply(raw, [Op("element.add", "element", Elem("element0000000009", "action", "Action_Do_nothing"))])
    Assert.True(after["allElements"].Has("element0000000009"), "element added")
    Assert.Equal(after["ElementIDCounter"], "10", "counter above the used number, still a text")
    Assert.Equal(raw["ElementIDCounter"], "6", "the old revision keeps its counter")
    Assert.True(!raw["allElements"].Has("element0000000009"), "the old revision keeps its elements")
}

AddRefusesAUsedOrMalformedOrUnknownElement() {
    raw := BaseFlow()
    Refused(() => FlowPatch.Apply(raw, [Op("element.add", "element", Elem("element0000000002", "action", "X"))])
        , "exists already")
    Refused(() => FlowPatch.Apply(raw, [Op("element.add", "element", Elem("element12", "action", "X"))])
        , "not an element ID")
    Refused(() => FlowPatch.Apply(raw, [Op("element.add", "element", Elem("element0000000009", "wobble", "X"))])
        , "unknown type")
    Refused(() => FlowPatch.Apply(raw, [Op("element.add", "element", Elem("element0000000009", "action", ""))])
        , "needs a class")
    Refused(() => FlowPatch.Apply(raw, [Op("element.add", "element", "nope")]), "must be an object")
}

UpdateMergesParametersByIdAndDeletesOnNull() {
    raw := BaseFlow()
    fields := Map("name", "Pause", "pars", Map("Duration", "500", "Unit", Json.Null))
    after := FlowPatch.Apply(raw, [Op("element.update", "id", "element0000000002", "fields", fields)])
    el := after["allElements"]["element0000000002"]
    Assert.Equal(el["name"], "Pause")
    Assert.Equal(el["pars"]["Duration"], "500")
    Assert.True(!el["pars"].Has("Unit"), "null deletes the parameter")
    Assert.Equal(raw["allElements"]["element0000000002"]["pars"]["Unit"], "Milliseconds", "old revision unchanged")
    Assert.Equal(raw["allElements"]["element0000000002"]["name"], "element0000000002", "old name unchanged")
}

UpdateKeepsTheIdAndRefusesUnknownElements() {
    raw := BaseFlow()
    Refused(() => FlowPatch.Apply(raw, [Op("element.update", "id", "element0000000777", "fields", Map("x", 1))])
        , "does not exist")
    Refused(() => FlowPatch.Apply(raw, [Op("element.update", "id", "element0000000002"
        , "fields", Map("ID", "element0000000005"))]), "cannot be changed")
}

UpdateToTriggerIsRefusedWhileAConnectionLeadsIntoIt() {
    raw := BaseFlow()
    Refused(() => FlowPatch.Apply(raw, [Op("element.update", "id", "element0000000002"
        , "fields", Map("type", "trigger"))]), "into the trigger")
}

ChangedParameterLosesItsMigrationEntryOnly() {
    raw := BaseFlow()
    entries := [Map("par", "Duration", "ids", ["M-0025"], "v1", "1+1"), Map("par", "Unit", "ids", ["M-0026"], "v1", "x")]
    raw["allElements"]["element0000000002"]["migration"] := entries
    after := FlowPatch.Apply(raw, [Op("element.update", "id", "element0000000002"
        , "fields", Map("pars", Map("Duration", "300")))])
    el := after["allElements"]["element0000000002"]
    Assert.Equal(el["migration"].Length, 1, "the entry of the changed parameter is gone")
    Assert.Equal(el["migration"][1]["par"], "Unit", "the other entry stays")
    Assert.Equal(raw["allElements"]["element0000000002"]["migration"].Length, 2, "old revision keeps both entries")
    same := FlowPatch.Apply(raw, [Op("element.update", "id", "element0000000002"
        , "fields", Map("pars", Map("Unit", "Milliseconds")))])
    Assert.Equal(same["allElements"]["element0000000002"]["migration"].Length, 2, "an unchanged value keeps the entries")
}

; --- removal and the default trigger ---------------------------------------------------------------------------------

RemoveTakesItsConnections() {
    raw := BaseFlow()
    after := FlowPatch.Apply(raw, [Op("element.remove", "id", "element0000000002")])
    Assert.True(!after["allElements"].Has("element0000000002"))
    Assert.Equal(after["allConnections"].Count, 0, "both connections of element 2 are gone")
    Assert.Equal(raw["allConnections"].Count, 2, "old revision keeps them")
    Refused(() => FlowPatch.Apply(raw, [Op("element.remove", "id", "element0000000777")]), "does not exist")
}

; Two more manual triggers (6 and 7) that are not the default: removing the default promotes the first of them.
WithTwoManualTriggers() {
    raw := BaseFlow()
    for id in ["element0000000006", "element0000000007"] {
        trigger := Elem(id, "trigger", "Trigger_Manual", Map("ID", id))
        trigger["DefaultTrigger"] := Json.False
        raw["allElements"][id] := trigger
    }
    return raw
}

RemovingTheDefaultTriggerPromotesTheFirstRemainingManualTrigger() {
    after := FlowPatch.Apply(WithTwoManualTriggers(), [Op("element.remove", "id", "element0000000001")])
    Assert.True(after["allElements"]["element0000000006"]["DefaultTrigger"] == Json.True, "the first manual trigger is default")
    Assert.True(after["allElements"]["element0000000007"]["DefaultTrigger"] == Json.False, "the others stay")
}

RemovingANonDefaultTriggerPromotesNothing() {
    after := FlowPatch.Apply(WithTwoManualTriggers(), [Op("element.remove", "id", "element0000000007")])
    Assert.True(after["allElements"]["element0000000001"]["DefaultTrigger"] == Json.True)
    Assert.True(after["allElements"]["element0000000006"]["DefaultTrigger"] == Json.False)
}

SettingTheDefaultClearsTheOthers() {
    after := FlowPatch.Apply(WithTwoManualTriggers(), [Op("element.update", "id", "element0000000006"
        , "fields", Map("DefaultTrigger", Json.True))])
    Assert.True(after["allElements"]["element0000000006"]["DefaultTrigger"] == Json.True)
    Assert.True(after["allElements"]["element0000000001"]["DefaultTrigger"] == Json.False, "the old default is cleared")
}

; --- connections -----------------------------------------------------------------------------------------------------

AddsAValidConnectionAndRefusesEachRule() {
    raw := BaseFlow()
    ok := FlowPatch.Apply(raw, [Op("connection.add", "connection", Conn("connection0000000006", "element0000000003"
        , "element0000000002", "No"))])
    Assert.True(ok["allConnections"].Has("connection0000000006"), "connection added")
    Assert.Equal(ok["ElementIDCounter"], "7", "counter raised by the connection number")
    Refused(() => FlowPatch.Apply(raw, [Op("connection.add", "connection", Conn("connection0000000006", "element0000000002"
        , "element0000000001"))]), "into the trigger")
    Refused(() => FlowPatch.Apply(raw, [Op("connection.add", "connection", Conn("connection0000000006", "element0000000002"
        , "element0000000002"))]), "to itself")
    Refused(() => FlowPatch.Apply(raw, [Op("connection.add", "connection", Conn("connection0000000006", "element0000000002"
        , "element0000000003", "YES"))]), "identical connection")
    Refused(() => FlowPatch.Apply(raw, [Op("connection.add", "connection", Conn("connection0000000006", "element0000000002"
        , "element0000000003", "maybe"))]), "unknown connection type")
    Refused(() => FlowPatch.Apply(raw, [Op("connection.add", "connection", Conn("connection0000000006", "element0000000002"
        , "element0000000999"))]), "does not exist")
    Refused(() => FlowPatch.Apply(raw, [Op("connection.add", "connection", Conn("connection0000000004", "element0000000002"
        , "element0000000003"))]), "exists already")
}

ConnectionUpdateChangesTypeAndRefusesADuplicate() {
    raw := BaseFlow()
    after := FlowPatch.Apply(raw, [Op("connection.update", "id", "connection0000000005"
        , "fields", Map("ConnectionType", "No"))])
    Assert.Equal(after["allConnections"]["connection0000000005"]["ConnectionType"], "No")
    Assert.Equal(raw["allConnections"]["connection0000000005"]["ConnectionType"], "Yes", "old revision unchanged")
    Refused(() => FlowPatch.Apply(raw, [Op("connection.update", "id", "connection0000000005"
        , "fields", Map("from", "element0000000001", "to", "element0000000002", "ConnectionType", "normal"))])
        , "identical connection")
}

ConnectionRemoveRemovesOnlyThatConnection() {
    raw := BaseFlow()
    after := FlowPatch.Apply(raw, [Op("connection.remove", "id", "connection0000000004")])
    Assert.True(!after["allConnections"].Has("connection0000000004"))
    Assert.True(after["allConnections"].Has("connection0000000005"))
    Refused(() => FlowPatch.Apply(raw, [Op("connection.remove", "id", "connection0000000777")]), "does not exist")
}

; The rules are judged on the final state of the list: a connection that is changed twice is judged once, at the end.
RulesAreCheckedOnTheFinalStateOfTheList() {
    raw := BaseFlow()
    ops := [Op("connection.update", "id", "connection0000000005", "fields", Map("to", "element0000000001"))
        , Op("connection.update", "id", "connection0000000005", "fields", Map("to", "element0000000003"))]
    after := FlowPatch.Apply(raw, ops)
    Assert.Equal(after["allConnections"]["connection0000000005"]["to"], "element0000000003")
}

; --- settings and all or nothing -------------------------------------------------------------------------------------

FlowSettingsMergesKeysDeletesOnNullAndChecksView() {
    raw := BaseFlow()
    after := FlowPatch.Apply(raw, [Op("flow.settings", "settings", Map("ExecutionPolicy", "wait", "zoomFactor", "0.7"
        , "strictTypes", Json.Null))])
    Assert.Equal(after["flowSettings"]["ExecutionPolicy"], "wait")
    Assert.Equal(after["flowSettings"]["zoomFactor"], "0.7")
    Assert.True(!after["flowSettings"].Has("strictTypes"))
    Assert.Equal(raw["flowSettings"]["ExecutionPolicy"], "default", "old revision unchanged")
    view := FlowPatch.Apply(raw, [Op("flow.settings", "settings", Map("Offsety", "5"), "view", Json.True)])
    Assert.Equal(view["flowSettings"]["Offsety"], "5")
    Refused(() => FlowPatch.Apply(raw, [Op("flow.settings", "settings", Map(), "view", "yes")]), "must be true or false")
}

ListIsAllOrNothing() {
    raw := BaseFlow()
    before := Canon(raw)
    ops := [Op("element.update", "id", "element0000000002", "fields", Map("x", 99))
        , Op("connection.add", "connection", Conn("connection0000000006", "element0000000002", "element0000000002"))]
    Refused(() => FlowPatch.Apply(raw, ops), "to itself")
    Assert.Equal(Canon(raw), before, "the flow is unchanged")
}

UnknownOperationAndMissingOpAreRefused() {
    raw := BaseFlow()
    Refused(() => FlowPatch.Apply(raw, [Map("op", "element.teleport")]), "unknown patch operation")
    Refused(() => FlowPatch.Apply(raw, [Map("x", 1)]), "needs an 'op' field")
    Assert.Equal(Canon(FlowPatch.Apply(raw, [])), Canon(raw), "an empty list is a valid patch")
}

; --- revisions that share ----------------------------------------------------------------------------------------------

RevisionsShareTheMapsThatDoNotChange() {
    raw := BaseFlow()
    before := Canon(raw)
    after := FlowPatch.Apply(raw, [Op("element.update", "id", "element0000000002", "fields", Map("x", 42))])
    Assert.Equal(Canon(raw), before, "the old revision is unchanged")
    Assert.True(after["allElements"]["element0000000003"] == raw["allElements"]["element0000000003"]
        , "an untouched element is shared")
    Assert.True(!(after["allElements"]["element0000000002"] == raw["allElements"]["element0000000002"])
        , "the changed element is new")
    Assert.True(after["allConnections"] == raw["allConnections"], "an untouched connection map is shared")
    later := FlowPatch.Apply(after, [Op("element.remove", "id", "element0000000003")])
    Assert.True(after["allElements"].Has("element0000000003"), "a later patch does not change its base")
    Assert.True(!later["allElements"].Has("element0000000003"), "the later revision has the removal")
    Assert.Equal(Canon(raw), before, "and the first revision is still unchanged")
}

; --- inverse -----------------------------------------------------------------------------------------------------------

InverseUndoesEachKindOfOperation() {
    raw := BaseFlow()
    cases := [[Op("element.add", "element", Elem("element0000000009", "action", "Action_Do_nothing"))]
        , [Op("element.remove", "id", "element0000000002")]
        , [Op("element.remove", "id", "element0000000001")]
        , [Op("element.update", "id", "element0000000002", "fields", Map("name", "X", "pars", Map("Duration", "7"
            , "Unit", Json.Null)))]
        , [Op("connection.add", "connection", Conn("connection0000000006", "element0000000003", "element0000000002"))]
        , [Op("connection.update", "id", "connection0000000005", "fields", Map("ConnectionType", "No"))]
        , [Op("connection.remove", "id", "connection0000000004")]
        , [Op("flow.settings", "settings", Map("ExecutionPolicy", "wait", "strictTypes", Json.Null))]]
    for ops in cases {
        back := FlowPatch.Apply(FlowPatch.Apply(raw, ops), FlowPatch.Inverse(raw, ops))
        Assert.Equal(Canon(back), Canon(raw), "inverse of " ops[1]["op"])
    }
    Assert.Equal(FlowPatch.Inverse(raw, []).Length, 0, "the inverse of an empty list is empty")
}

; Removing the default trigger and its inverse: the promoted trigger goes back to not default.
InverseOfADefaultPromotionRestoresTheOthers() {
    raw := WithTwoManualTriggers()
    ops := [Op("element.remove", "id", "element0000000001")]
    back := FlowPatch.Apply(FlowPatch.Apply(raw, ops), FlowPatch.Inverse(raw, ops))
    Assert.Equal(Canon(back), Canon(raw))
    Assert.True(back["allElements"]["element0000000001"]["DefaultTrigger"] == Json.True)
    Assert.True(back["allElements"]["element0000000006"]["DefaultTrigger"] == Json.False)
}

; Random lists of operations over every corpus flow: the operations are applied, then their inverse. The result must be
; the original flow again (without the counter). Refused lists are skipped; enough lists must be accepted.
InverseOfRandomListsGivesTheOriginalOnTheCorpus() {
    accepted := 0
    rejected := 0
    seed := 20261020
    for path in CorpusFiles() {
        raw := Json.Parse(FileRead(path, "UTF-8"))
        loop 12 {
            ops := RandomOps(raw, 1 + Mod(seed, 6), &seed)
            try {
                after := FlowPatch.Apply(raw, ops)
            } catch AhfError {
                rejected += 1
                continue
            }
            accepted += 1
            back := FlowPatch.Apply(after, FlowPatch.Inverse(raw, ops))
            Assert.Equal(Canon(back), Canon(raw), "random list " A_Index " on " path)
        }
    }
    Assert.True(accepted >= 150, "enough lists were accepted: " accepted " (rejected " rejected ")")
}

CorpusFiles() {
    out := []
    loop files CORPUS "\*.json"
        out.Push(A_LoopFileFullPath)
    return out
}

; A random list over a flow of the corpus. Operations refer to the flow as it is before the list, or to new IDs.
RandomOps(raw, count, &seed) {
    ops := []
    els := raw["allElements"]
    ids := []
    for id in els
        ids.Push(id)
    cids := []
    for cid, c in raw["allConnections"] {
        if (els.Has(c["from"]) && els.Has(c["to"]))
            cids.Push(cid)
    }
    fresh := 900000
    loop count {
        seed := Mod(seed * 1103515245 + 12345, 2147483648)
        pick := Mod(seed // 65536, 6)
        seed := Mod(seed * 1103515245 + 12345, 2147483648)
        r := Mod(seed // 65536, 1000000)
        fresh += 1
        if (pick = 0 && ids.Length)
            ops.Push(Op("element.update", "id", ids[1 + Mod(r, ids.Length)]
                , "fields", Map("x", r, "pars", Map("Duration", String(r)))))
        else if (pick = 1)
            ops.Push(Op("element.add", "element", Elem("element" Format("{:010}", fresh), "action", "Action_Do_nothing")))
        else if (pick = 2 && ids.Length)
            ops.Push(Op("element.remove", "id", ids[1 + Mod(r, ids.Length)]))
        else if (pick = 3 && ids.Length >= 2) {
            from := ids[1 + Mod(r, ids.Length)]
            to := ids[1 + Mod(r // 7, ids.Length)]
            if (from != to && FlowPatch._KindOf(els[to]) != "trigger")
                ops.Push(Op("connection.add", "connection", Conn("connection" Format("{:010}", fresh), from, to)))
        } else if (pick = 4 && cids.Length)
            ops.Push(Op("connection.remove", "id", cids[1 + Mod(r, cids.Length)]))
        else
            ops.Push(Op("flow.settings", "settings", Map("zoomFactor", String(r))))
    }
    return ops
}

TestRun.Init()

TestRun.Case("FlowPatch: add an element, raise the counter, keep the old revision", AddsAnElementAndRaisesTheCounterKeepingItsType)
TestRun.Case("FlowPatch: add refuses a used, malformed or unknown element", AddRefusesAUsedOrMalformedOrUnknownElement)
TestRun.Case("FlowPatch: update merges parameters by ID and deletes on null", UpdateMergesParametersByIdAndDeletesOnNull)
TestRun.Case("FlowPatch: update keeps the ID and refuses unknown elements", UpdateKeepsTheIdAndRefusesUnknownElements)
TestRun.Case("FlowPatch: update to a trigger is refused while a connection leads into it", UpdateToTriggerIsRefusedWhileAConnectionLeadsIntoIt)
TestRun.Case("FlowPatch: a changed parameter loses its migration entry only", ChangedParameterLosesItsMigrationEntryOnly)
TestRun.Case("FlowPatch: remove takes the connections of the element", RemoveTakesItsConnections)
TestRun.Case("FlowPatch: removing the default trigger promotes the first manual trigger", RemovingTheDefaultTriggerPromotesTheFirstRemainingManualTrigger)
TestRun.Case("FlowPatch: removing a trigger that is not the default promotes nothing", RemovingANonDefaultTriggerPromotesNothing)
TestRun.Case("FlowPatch: setting the default clears the others", SettingTheDefaultClearsTheOthers)
TestRun.Case("FlowPatch: connection add accepts a valid one and refuses each rule", AddsAValidConnectionAndRefusesEachRule)
TestRun.Case("FlowPatch: connection update changes the type and refuses a duplicate", ConnectionUpdateChangesTypeAndRefusesADuplicate)
TestRun.Case("FlowPatch: connection remove removes only that connection", ConnectionRemoveRemovesOnlyThatConnection)
TestRun.Case("FlowPatch: the rules are checked on the final state of the list", RulesAreCheckedOnTheFinalStateOfTheList)
TestRun.Case("FlowPatch: flow settings merge keys, delete on null, check view", FlowSettingsMergesKeysDeletesOnNullAndChecksView)
TestRun.Case("FlowPatch: a refused operation refuses the whole list", ListIsAllOrNothing)
TestRun.Case("FlowPatch: unknown and malformed operations are refused", UnknownOperationAndMissingOpAreRefused)
TestRun.Case("FlowPatch: revisions share the maps that do not change", RevisionsShareTheMapsThatDoNotChange)
TestRun.Case("FlowPatch: the inverse undoes each kind of operation", InverseUndoesEachKindOfOperation)
TestRun.Case("FlowPatch: the inverse of a default promotion restores the others", InverseOfADefaultPromotionRestoresTheOthers)
TestRun.Case("FlowPatch: the inverse of random lists gives the original on the corpus", InverseOfRandomListsGivesTheOriginalOnTheCorpus)

TestRun.Finish()
