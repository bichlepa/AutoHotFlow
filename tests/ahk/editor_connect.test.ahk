#Requires AutoHotkey v2.0
; Unit tests for the connections of the editor (WI-0100, REQ-EDT-070): the rules of a connection (src/editor/ConnectionRules.ahk:
; the types a start element allows, the default type, the loop parts of an end, the refusals), the element under a drop
; (FlowHitTest.ElementAt) and the preview of a connection whose start follows the pointer (Scene.ConnectingOf with toId).
; The gestures themselves (the buttons, the questions, the patches) are in tests/e2e/test_editor_connect.py.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\ConnectionRules.ahk
#Include ..\..\src\editor\FlowRect.ahk
#Include ..\..\src\editor\FlowGeometry.ahk
#Include ..\..\src\editor\FlowHit.ahk
#Include ..\..\src\editor\FlowHitTest.ahk
#Include ..\..\src\editor\SceneElement.ahk
#Include ..\..\src\editor\Scene.ahk

A := "element0000000001"
B := "element0000000002"
T := "element0000000003"
C1 := "connection0000000004"

; A flow with an action A, a loop B, a trigger T and one connection A -> B (normal, no parts).
Flow() {
    els := Map()
    els[A] := Map("ID", A, "type", "action", "class", "Sleep", "x", 0, "y", 0)
    els[B] := Map("ID", B, "type", "loop", "class", "Loop", "x", 300, "y", 0, "HeightOfVerticalBar", 150)
    els[T] := Map("ID", T, "type", "trigger", "class", "trigger_manual", "x", 0, "y", 300)
    cons := Map()
    cons[C1] := Map("ID", C1, "from", A, "to", B, "ConnectionType", "normal")
    return Map("allElements", els, "allConnections", cons)
}

Spec(from, to, type := "normal", fromPart := "", toPart := "") {
    return Map("conn", "", "from", from, "to", to, "type", type, "fromPart", fromPart, "toPart", toPart)
}

OptionsOfCondition() {
    ids := []
    for option in ConnectionRules.Options("Condition")
        ids.Push(option[1])
    Assert.Equal(ids.Length, 3)
    Assert.Equal(ids[1] ids[2] ids[3], "yesnoexception")
}

OptionsOfAnyOtherElement() {
    ids := []
    for option in ConnectionRules.Options("loop")
        ids.Push(option[1])
    Assert.Equal(ids.Length, 2)
    Assert.Equal(ids[1] ids[2], "normalexception")
}

ValidTypesAreCaseFree() {
    Assert.True(ConnectionRules.Valid("condition", "No"))
    Assert.True(ConnectionRules.Valid("action", "Normal"))
    Assert.True(ConnectionRules.Valid("action", "exception"))
    Assert.Equal(ConnectionRules.Valid("action", "yes"), false)
    Assert.Equal(ConnectionRules.Valid("loop", ""), false)
    Assert.Equal(ConnectionRules.Valid("condition", "normal"), false)
}

DefaultTypeOfAConditionIsYes() {
    Assert.Equal(ConnectionRules.Default("condition"), "yes")
    Assert.Equal(ConnectionRules.Default("action"), "normal")
}

ToPartOfALoopIsHeadFootOrBreak() {
    Assert.Equal(ConnectionRules.ToPart("loop", 1), "HEAD")
    Assert.Equal(ConnectionRules.ToPart("loop", 2), "HEAD")
    Assert.Equal(ConnectionRules.ToPart("loop", 3), "TAIL")
    Assert.Equal(ConnectionRules.ToPart("loop", 4), "BREAK")
    Assert.Equal(ConnectionRules.ToPart("loop", 0), "HEAD")
    Assert.Equal(ConnectionRules.ToPart("action", 3), "")
}

FromPartOfALoopCannotBeTheBreakField() {
    Assert.Equal(ConnectionRules.FromPart("loop", 1), "HEAD")
    Assert.Equal(ConnectionRules.FromPart("loop", 2), "HEAD")
    Assert.Equal(ConnectionRules.FromPart("loop", 3), "TAIL")
    Assert.Equal(ConnectionRules.FromPart("loop", 4), "TAIL")
    Assert.Equal(ConnectionRules.FromPart("loop", 0), "TAIL")
    Assert.Equal(ConnectionRules.FromPart("condition", 1), "")
}

RefusesAConnectionIntoATrigger() {
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(A, T)), "You cannot connect to trigger!")
}

RefusesAConnectionFromAnElementToItself() {
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(A, A)), "The connection cannot start and end on the same element!")
}

RefusesAnIdenticalSecondConnection() {
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(A, B)), "This connection already exists!")
}

AnIdenticalConnectionIsNoDuplicateOfItself() {
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(A, B), C1), "")
}

ADifferentTypeOrPartIsNoDuplicate() {
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(A, B, "exception")), "")
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(A, B, "normal", "", "HEAD")), "")
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(B, A)), "")
}

TypeCaseDoesNotMakeADifferentConnection() {
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(A, B, "Normal")), "This connection already exists!")
}

ANewElementIsNeverARefusalOfItsOwn() {
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(A, ConnectionRules.NEW)), "")
    Assert.Equal(ConnectionRules.Refusal(Flow(), Spec(ConnectionRules.NEW, B)), "")
}

KindOfIsLowerCaseAndEmptyForNoElement() {
    Assert.Equal(ConnectionRules.KindOf(Flow(), A), "action")
    Assert.Equal(ConnectionRules.KindOf(Flow(), "element0000000099"), "")
}

ElementAtReturnsTheElementAndThePartUnderTheDrop() {
    sc := TwoElementScene()
    hit := FlowHitTest.ElementAt(sc, 10, 10)
    Assert.Equal(hit.Kind, "element")
    Assert.Equal(hit.Id, A)
    Assert.Equal(hit.Index, 1)
    ; the break field of the loop B: the right quarter of its foot (flow 405 to 440, 255 to 290)
    hit := FlowHitTest.ElementAt(sc, 410, 260)
    Assert.Equal(hit.Id, B)
    Assert.Equal(hit.Index, 4)
}

ElementAtIsEmptyOnEmptySpace() {
    Assert.Equal(FlowHitTest.ElementAt(TwoElementScene(), 200, 200), "")
}

ConnectingWithAStartThatFollowsThePointerAimsAtTheElement() {
    sc := TwoElementScene()
    c := Scene.ConnectingOf(sc.Elements, Map("toId", A, "toPart", "", "x", 50, "y", 300))
    Assert.Equal(c["start"][1], 50)
    Assert.Equal(c["start"][2], 300)
    Assert.True(c["aim"][1] = 70, "the top centre of an action (W/2)")   ; W/2 is a float: compare by value
    Assert.Equal(c["aim"][2], 0)
}

ConnectingWithAnUnknownEndIsNothing() {
    sc := TwoElementScene()
    Assert.Equal(Scene.ConnectingOf(sc.Elements, Map("toId", "element0000000099", "x", 1, "y", 1)), "")
}

; The sc of the two elements of Flow() without connections: A (action at 0, 0) and the loop B (at 300, 0, bar 150).
TwoElementScene() {
    elements := [
        SceneElement(A, "action", "Sleep", "", 0, 0, 0, "", "", "", "", ""),
        SceneElement(B, "loop", "Loop", "", 300, 0, 150, "", "", "", "", "")
    ]
    return Scene("", 1, "", elements, [], [])
}

TestRun.Case("Editor connect: the options of a condition are yes, no and exception", OptionsOfCondition)
TestRun.Case("Editor connect: any other element offers normal and exception", OptionsOfAnyOtherElement)
TestRun.Case("Editor connect: a type is valid for its start element, any case", ValidTypesAreCaseFree)
TestRun.Case("Editor connect: a new connection from a condition defaults to yes", DefaultTypeOfAConditionIsYes)
TestRun.Case("Editor connect: the end at a loop is head, foot or break field", ToPartOfALoopIsHeadFootOrBreak)
TestRun.Case("Editor connect: a connection cannot start at the break field of a loop", FromPartOfALoopCannotBeTheBreakField)
TestRun.Case("Editor connect: a connection into a trigger is refused", RefusesAConnectionIntoATrigger)
TestRun.Case("Editor connect: a connection from an element to itself is refused", RefusesAConnectionFromAnElementToItself)
TestRun.Case("Editor connect: an identical second connection is refused", RefusesAnIdenticalSecondConnection)
TestRun.Case("Editor connect: the connection that is changed is no duplicate of itself", AnIdenticalConnectionIsNoDuplicateOfItself)
TestRun.Case("Editor connect: another type or part is no duplicate", ADifferentTypeOrPartIsNoDuplicate)
TestRun.Case("Editor connect: the type is compared without case for a duplicate", TypeCaseDoesNotMakeADifferentConnection)
TestRun.Case("Editor connect: a connection to the new element is not refused", ANewElementIsNeverARefusalOfItsOwn)
TestRun.Case("Editor connect: the kind of an element is lower case", KindOfIsLowerCaseAndEmptyForNoElement)
TestRun.Case("Editor connect: a drop finds the element and the part under it", ElementAtReturnsTheElementAndThePartUnderTheDrop)
TestRun.Case("Editor connect: a drop on empty space finds no element", ElementAtIsEmptyOnEmptySpace)
TestRun.Case("Editor connect: a preview whose start follows the pointer aims at the end element",
    ConnectingWithAStartThatFollowsThePointerAimsAtTheElement)
TestRun.Case("Editor connect: a preview with an unknown end element is nothing", ConnectingWithAnUnknownEndIsNothing)
TestRun.Finish()
