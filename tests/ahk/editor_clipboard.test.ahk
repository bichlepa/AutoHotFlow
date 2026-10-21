#Requires AutoHotkey v2.0
; Unit tests for src/editor/ElementClipboard.ahk (WI-0101, REQ-EDT-080, E0091): the copy text of a selection, the parsing
; of a clipboard text (ours or not), the paste plan (new IDs, the position under the pointer, the default trigger, the
; connections whose ends are in the copy) and the delete operations. The plans are applied with FlowPatch.Apply, the rules
; of the engine, so a plan that the engine would refuse fails here.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\ElementClipboard.ahk

; A flow of a trigger (manual, the default), two actions and a connection between each pair, plus an element outside.
Skeleton() {
    els := Map()
    els["element0000000001"] := Map("ID", "element0000000001", "type", "trigger", "class", "Trigger_Manual", "x", 0, "y", 0
        , "DefaultTrigger", 1, "pars", Map())
    els["element0000000002"] := Map("ID", "element0000000002", "type", "action", "class", "Action_Sleep", "x", 0, "y", 210
        , "pars", Map())
    els["element0000000003"] := Map("ID", "element0000000003", "type", "action", "class", "Action_Sleep", "x", "0", "y", "420"
        , "pars", Map())
    cons := Map()
    cons["connection0000000004"] := Map("ID", "connection0000000004", "from", "element0000000001", "to", "element0000000002"
        , "ConnectionType", "normal")
    cons["connection0000000005"] := Map("ID", "connection0000000005", "from", "element0000000002", "to", "element0000000003"
        , "ConnectionType", "normal")
    root := Map("allElements", els, "allConnections", cons, "ElementIDCounter", 6, "flowSettings", Map())
    return root
}

Manual(id, x, y, flag := false) {
    el := Map("ID", id, "type", "trigger", "class", "Trigger_Manual", "x", x, "y", y, "pars", Map())
    if (flag)
        el["DefaultTrigger"] := Json.True
    return el
}

; The IDs of the operations of one kind, in order.
OpIds(ops, name) {
    ids := []
    for op in ops {
        if (op["op"] = name)
            ids.Push(op.Has("id") ? op["id"] : (op.Has("element") ? op["element"]["ID"] : op["connection"]["ID"]))
    }
    return ids
}

JoinIds(ids) {
    text := ""
    for id in ids
        text .= (A_Index = 1 ? "" : ",") id
    return text
}

CopyTakesTheSelectedElementsAndTheConnectionsBetweenThem() {
    root := Skeleton()
    text := ElementClipboard.Copied(root, ["element0000000002", "element0000000003", "connection0000000005"
        , "connection0000000004"])
    data := ElementClipboard.Parse(text)
    Assert.True(data is Map, "the text of the selection is ours")
    Assert.Equal(data["elements"].Length, 2, "two selected elements")
    Assert.Equal(data["connections"].Length, 1, "only the connection with both ends selected (04 has the trigger as its start)")
    Assert.Equal(data["connections"][1]["ID"], "connection0000000005")
    Assert.True(!InStr(text, "element0000000001"), "the unselected trigger is not in the copy")
}

CopyOfAConnectionAloneIsEmpty() {
    data := ElementClipboard.Parse(ElementClipboard.Copied(Skeleton(), ["connection0000000004"]))
    Assert.Equal(data["elements"].Length, 0, "a connection without its elements is not copied")
    Assert.Equal(data["connections"].Length, 0)
}

ParseRefusesWhatIsNotOurs() {
    Assert.True(ElementClipboard.Parse("hello world") == "", "plain text is not an element")
    Assert.True(ElementClipboard.Parse("") == "", "an empty text")
    Assert.True(ElementClipboard.Parse("[1,2]") == "", "a list is not the content")
    Assert.True(ElementClipboard.Parse('{"formatVersion":2,"elements":[],"connections":[]}') == "", "another format version")
    Assert.True(ElementClipboard.Parse('{"formatVersion":1,"elements":[]}') == "", "the connections are missing")
    Assert.True(ElementClipboard.Parse('{"formatVersion":1,"elements":[{"type":"action"}],"connections":[]}') == "",
        "an element without ID and position")
    Assert.True(ElementClipboard.Parse('{"formatVersion":1,"elements":[],"connections":[{"ID":"c"}]}') == "",
        "a connection without its ends")
    Assert.True(ElementClipboard.Parse('{"formatVersion":1,"elements":[],"connections":[{"ID":"c","from":{"q":1},"to":"a"}]}')
        == "", "an end of a connection that is no ID")
    Assert.True(ElementClipboard.Parse('{"formatVersion":1,"elements":[],"connections":[]}') is Map,
        "an empty copy of the right format is ours")
}

PlanPutsTheAnchorUnderThePointerOnTheGrid()
{
    root := Skeleton()
    data := ElementClipboard.Parse(ElementClipboard.Copied(root, ["element0000000002", "element0000000003"
        , "connection0000000005"]))
    plan := ElementClipboard.Plan(root, data, 500, 500)
    Assert.Equal(OpIds(plan["ops"], "element.add").Length, 2)
    ; the anchor is action 2 (x 0, y 210): its centre goes to (500, 500), snapped: x = 500 - 70 = 430 -> 420 (430/35 = 12.3)
    first := plan["ops"][1]["element"]
    Assert.Equal(first["x"], 420, "the anchor's top left: 500 - 70 = 430, snapped to 420")
    Assert.Equal(first["y"], 455, "the anchor's top: 500 - 52.5 = 447.5, snapped to 455")
    second := plan["ops"][2]["element"]
    Assert.Equal(second["x"], 420, "the second element keeps its distance (both at x 0)")
    Assert.Equal(second["y"], 665, "its y: 420 - 210 = 210 further down, 455 + 210 = 665")
}

PlanGivesNewIdsAboveTheCounterAndSkipsUsedOnes()
{
    root := Skeleton()
    root["ElementIDCounter"] := 6
    root["allElements"]["element0000000006"] := Map("ID", "element0000000006", "type", "action", "class", "Action_Sleep"
        , "x", 0, "y", 0, "pars", Map())
    data := ElementClipboard.Parse(ElementClipboard.Copied(root, ["element0000000002", "element0000000003"]))
    plan := ElementClipboard.Plan(root, data, 0, 0)
    Assert.Equal(JoinIds(plan["ids"]), "element0000000007,element0000000008,connection0000000009"
        , "6 is taken: the counter goes on at 7; the connection between the two (copied too) gets the next ID")
    result := FlowPatch.Apply(root, plan["ops"])
    Assert.True(result["allElements"].Has("element0000000008"), "the plan applies as one patch")
}

PlanKeepsConnectionsBetweenThePastedElements()
{
    root := Skeleton()
    data := ElementClipboard.Parse(ElementClipboard.Copied(root, ["element0000000002", "element0000000003"
        , "connection0000000005"]))
    plan := ElementClipboard.Plan(root, data, 300, 300)
    connAdds := []
    for op in plan["ops"] {
        if (op["op"] = "connection.add")
            connAdds.Push(op["connection"])
    }
    Assert.Equal(connAdds.Length, 1)
    Assert.Equal(connAdds[1]["from"], "element0000000006", "the connection follows the new element of its start")
    Assert.Equal(connAdds[1]["to"], "element0000000007", "and of its end")
    Assert.Equal(connAdds[1]["ConnectionType"], "normal", "the other fields stay")
    result := FlowPatch.Apply(root, plan["ops"])
    Assert.True(result["allConnections"].Has(plan["ids"][3]), "the new connection is in the flow")
}

PastedManualTriggerIsNoDefaultWhenTheFlowHasOne()
{
    root := Skeleton()                                       ; the flow has the manual trigger 01, the default
    data := Map("elements", [Manual("element0000000020", 0, 0, true)], "connections", [])
    plan := ElementClipboard.Plan(root, data, 0, 0)
    el := plan["ops"][1]["element"]
    Assert.True(!el.Has("DefaultTrigger"), "a pasted manual trigger is not the default of a flow that has one")
    result := FlowPatch.Apply(root, plan["ops"])
    Assert.True(result["allElements"]["element0000000001"].Has("DefaultTrigger"), "the default stays")
}

PastedManualTriggerIsTheDefaultWhenTheFlowHasNone()
{
    root := Skeleton()
    root["allElements"].Delete("element0000000001")
    data := Map("elements", [Manual("element0000000020", 0, 0), Manual("element0000000021", 0, 300, true)], "connections", [])
    plan := ElementClipboard.Plan(root, data, 0, 0)
    Assert.True(!plan["ops"][1]["element"].Has("DefaultTrigger"), "the flagged trigger of the copy is the default, not the first")
    Assert.True(plan["ops"][2]["element"].Has("DefaultTrigger"), "the flagged trigger of the copy is the default")
    result := FlowPatch.Apply(root, plan["ops"])
    Assert.Equal(CountDefaults(result), 1, "one default trigger")
}

PastedFirstManualTriggerIsTheDefaultWithoutAFlag()
{
    root := Skeleton()
    root["allElements"].Delete("element0000000001")
    data := Map("elements", [Manual("element0000000021", 0, 300), Manual("element0000000020", 0, 0)], "connections", [])
    plan := ElementClipboard.Plan(root, data, 0, 0)
    ; the copy is sorted by ID: 20 is the first, so it gets the default
    Assert.True(plan["ops"][1]["element"]["ID"] = "element0000000006" && plan["ops"][1]["element"].Has("DefaultTrigger")
        , "the first manual trigger of the copy (by ID) becomes the default")
    Assert.Equal(CountDefaults(FlowPatch.Apply(root, plan["ops"])), 1, "one default trigger")
}

CountDefaults(root) {
    n := 0
    for id, el in root["allElements"] {
        if (el.Has("DefaultTrigger"))
            n += 1
    }
    return n
}

PlanOfAnEmptyCopyHasNoOperations()
{
    plan := ElementClipboard.Plan(Skeleton(), Map("elements", [], "connections", []), 0, 0)
    Assert.Equal(plan["ops"].Length, 0)
    Assert.Equal(plan["ids"].Length, 0)
}

DeleteRemovesTheElementsTheirConnectionsAndTheSelectedConnections()
{
    root := Skeleton()
    ops := ElementClipboard.DeleteOps(root, ["element0000000002"])
    Assert.Equal(JoinIds(OpIds(ops, "connection.remove")), "connection0000000004,connection0000000005"
        , "both connections of the element go")
    Assert.Equal(JoinIds(OpIds(ops, "element.remove")), "element0000000002")
    Assert.True(ops[1]["op"] = "connection.remove" && ops[ops.Length]["op"] = "element.remove"
        , "the connections go before the element")
    result := FlowPatch.Apply(root, ops)
    Assert.Equal(result["allElements"].Count, 2, "two elements remain")
    Assert.Equal(result["allConnections"].Count, 0)
}

DeleteOfAConnectionKeepsTheElements()
{
    ops := ElementClipboard.DeleteOps(Skeleton(), ["connection0000000005"])
    Assert.Equal(ops.Length, 1, "only the connection")
    Assert.Equal(ops[1]["op"], "connection.remove")
    Assert.Equal(ElementClipboard.DeleteOps(Skeleton(), []).Length, 0, "an empty selection gives nothing")
}

TestRun.Case("Editor clipboard: a copy takes the selected elements and the connections between them", CopyTakesTheSelectedElementsAndTheConnectionsBetweenThem)
TestRun.Case("Editor clipboard: a connection alone is not copied", CopyOfAConnectionAloneIsEmpty)
TestRun.Case("Editor clipboard: a text that is not ours is refused", ParseRefusesWhatIsNotOurs)
TestRun.Case("Editor clipboard: the anchor goes under the pointer, snapped to the grid", PlanPutsTheAnchorUnderThePointerOnTheGrid)
TestRun.Case("Editor clipboard: new IDs follow the counter and skip the used ones", PlanGivesNewIdsAboveTheCounterAndSkipsUsedOnes)
TestRun.Case("Editor clipboard: connections are copied between the new elements", PlanKeepsConnectionsBetweenThePastedElements)
TestRun.Case("Editor clipboard: a pasted manual trigger is no default when the flow has one", PastedManualTriggerIsNoDefaultWhenTheFlowHasOne)
TestRun.Case("Editor clipboard: the flagged manual trigger of the copy is the default of an empty flow", PastedManualTriggerIsTheDefaultWhenTheFlowHasNone)
TestRun.Case("Editor clipboard: without a flag the first manual trigger of the copy is the default", PastedFirstManualTriggerIsTheDefaultWithoutAFlag)
TestRun.Case("Editor clipboard: an empty copy gives no operations", PlanOfAnEmptyCopyHasNoOperations)
TestRun.Case("Editor clipboard: a delete removes the elements, their connections and the selected connections", DeleteRemovesTheElementsTheirConnectionsAndTheSelectedConnections)
TestRun.Case("Editor clipboard: a delete of a connection keeps the elements", DeleteOfAConnectionKeepsTheElements)
TestRun.Finish()
