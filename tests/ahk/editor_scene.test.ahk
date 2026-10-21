#Requires AutoHotkey v2.0
; Unit tests for src/editor/SceneBuilder.ahk, Scene.ahk and FlowHitTest.ahk (WI-0084, ARCHITECTURE 2.1). The classes of
; the package Default come from its generated block, as the editor role has them (the Test package is not needed).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\core\Json.ahk
#Include ..\..\src\editor\SceneBuilder.ahk
#Include ..\..\src\editor\FlowHitTest.ahk
#Include ..\..\src\editor\NewElementFields.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk

; Numbers are compared with a tolerance: the arithmetic of the drawing is in floats.
Near(actual, expected, msg := "") {
    if (Abs(actual - expected) > 0.000001)
        throw AssertFailed(Assert.Join(msg, "expected " expected " but got " actual))
}

; The element of a scene with this ID (the scene lists the elements in ID order).
ElementById(sc, id) {
    for element in sc.Elements {
        if (element.Id = id)
            return element
    }
    throw AssertFailed("no element '" id "' in the scene")
}

; The parsed flow of a JSON text (as the editor gets it from the storage).
FlowOf(text) => Json.Parse(text)

; Two actions A (0,0) and B (200,300), a loop L (400,0) with a bar of 40, connection c1 from A to B (normal).
SmallFlow() {
    return FlowOf('{"allElements": {'
        . '"A": {"ID": "A", "type": "action", "class": "action_Sleep", "package": "Default", "x": 0, "y": 0, "name": "a"},'
        . '"B": {"ID": "B", "type": "action", "class": "action_Sleep", "package": "Default", "x": 200, "y": 300, "name": "b"},'
        . '"L": {"ID": "L", "type": "loop", "class": "loop_Simple_loop", "package": "Default", "x": 400, "y": 0,'
        . ' "HeightOfVerticalBar": 40, "name": "l"}},'
        . '"allConnections": {"c1": {"ID": "c1", "from": "A", "to": "B", "ConnectionType": "normal"}}}')
}

TestRun.Init()

TestRun.Case("Scene: every v1 example flow builds a scene with all its elements and connections", AllExamplesBuild)
TestRun.Case("Scene: an element of an unknown class is a placeholder with its reason", UnknownClassIsPlaceholder)
TestRun.Case("Scene: an element of a package that is not installed is a placeholder naming the package", MissingPackage)
TestRun.Case("Scene: a known class gets its display name and its icon", KnownClassHasName)
TestRun.Case("Scene: the drawn text is the user's name, the package is kept", TextAndPackage)
TestRun.Case("Scene: run states, trigger states, migration places and warnings are copied", StatesAreCopied)
TestRun.Case("Scene: a connection without its source or target is a warning, not a connection", DanglingConnection)
TestRun.Case("Scene: positions given as text are numbers", TextPositions)
TestRun.Case("Scene: the scene keeps no reference into the flow", SceneIsACopy)
TestRun.Case("Scene: the version and the hovered item are kept, the box covers all items", VersionAndBounds)
TestRun.Case("Scene: an empty flow gives an empty scene", EmptyFlow)
TestRun.Case("Hit test: an element part, the parts of a loop", HitElementParts)
TestRun.Case("Hit test: a connection segment within the margin of 20", HitConnectionSegment)
TestRun.Case("Hit test: an element wins over a connection, nothing far away", HitOrderAndMiss)
TestRun.Case("Hit test: the switch of a trigger, the star only of a manual trigger (WI-0102)", HitTriggerMarks)
TestRun.Case("Scene: the default manual trigger comes from the definition (DefaultTrigger), not from a state key", DefaultTriggerFromDefinition)
TestRun.Case("Scene: WithStates gives the states of Build and shares the objects whose state did not change", WithStatesSharesUnchanged)
TestRun.Case("Scene: WithStates changes the view and keeps the flow", WithStatesChangesView)
TestRun.Case("Buttons: a selected action has edit, trash and plus at the v1 positions; the button wins the hit", ButtonsOfAnElement)
TestRun.Case("Buttons: a loop has a second plus below its foot", ButtonsOfALoop)
TestRun.Case("Buttons: a selected connection has five buttons, the move buttons only when they do not overlap", ButtonsOfAConnection)
TestRun.Case("Drag: the element and its connection move, the base scene and the buttons stay as they are", DragMovesElementAndConnection)
TestRun.Case("Interaction: the connection being drawn and the selection rectangle are kept", ConnectingAndRectangle)
TestRun.Case("Fields: the four fields for new elements at the v1 positions, scaled by the DPI", NewElementFieldsAt)

; Two triggers: T1 is the default manual trigger (class Trigger_Manual, DefaultTrigger "1"), T2 is a manual trigger
; without the key. A state key "default" in the engine's state does not make a trigger the default one.
DefaultTriggerFromDefinition() {
    raw := FlowOf('{"allElements": {'
        . '"T1": {"ID": "T1", "type": "trigger", "class": "Trigger_Manual", "package": "Default", "x": 0, "y": 0,'
        . ' "DefaultTrigger": "1"},'
        . '"T2": {"ID": "T2", "type": "trigger", "class": "trigger_manual", "package": "Default", "x": 0, "y": 300},'
        . '"T3": {"ID": "T3", "type": "trigger", "class": "Trigger_Periodic_Timer", "package": "Default", "x": 0, "y": 600,'
        . ' "DefaultTrigger": "1"}},'
        . '"allConnections": {}}')
    trigger := Map("T2", Map("enabled", 1, "armed", 0, "message", "", "default", 1))
    sc := SceneBuilder.Build(raw, "", "", trigger)
    Assert.Equal(ElementById(sc, "T1").Trigger["default"], 1, "the DefaultTrigger key marks the star")
    Assert.Equal(ElementById(sc, "T2").Trigger["default"], 0, "a state key 'default' does not mark it")
    Assert.Equal(ElementById(sc, "T3").Trigger["default"], 0, "only the class Trigger_Manual can be the default")
}

; The marks of a trigger (FlowGeometry.TriggerMarks): the switch at (80 %, 25 %) of the element, the star of a manual trigger
; at (15 %, 20 %). Centres in flow units for an element at (0, y): switch (112, y + 26.25), star (21, y + 21).
HitTriggerMarks() {
    raw := FlowOf('{"allElements": {'
        . '"T1": {"ID": "T1", "type": "trigger", "class": "Trigger_Manual", "package": "Default", "x": 0, "y": 0,'
        . ' "DefaultTrigger": "1"},'
        . '"T2": {"ID": "T2", "type": "trigger", "class": "Trigger_Manual", "package": "Default", "x": 0, "y": 300},'
        . '"T3": {"ID": "T3", "type": "trigger", "class": "Trigger_Periodic_Timer", "package": "Default", "x": 0, "y": 600}},'
        . '"allConnections": {}}')
    sc := SceneBuilder.Build(raw)
    h := FlowHitTest.At(sc, 112, 26)
    Assert.Equal(h.Kind, "mark", "the switch of T1")
    Assert.Equal(h.Id, "T1", "the switch belongs to its trigger")
    Assert.Equal(h.Index, "switch", "the switch, not the star")
    h := FlowHitTest.At(sc, 21, 21)
    Assert.Equal(h.Kind, "mark", "the star of the default trigger")
    Assert.Equal(h.Index, "star", "the star")
    h := FlowHitTest.At(sc, 21, 321)
    Assert.Equal(h.Index, "star", "the star of the manual trigger T2, which is not the default")
    h := FlowHitTest.At(sc, 112, 626)
    Assert.Equal(h.Index, "switch", "the switch of the timer trigger T3")
    h := FlowHitTest.At(sc, 21, 621)
    Assert.Equal(h.Kind, "element", "a timer trigger has no star: the element is hit")
    h := FlowHitTest.At(sc, 70, 60)
    Assert.Equal(h.Kind, "element", "the body of an element is not a mark")
}

; A flow with three actions, the scene built, then the states changed: the result equals a build with those states,
; the unchanged elements and the unchanged connection are the same objects, the changed ones are new.
WithStatesSharesUnchanged() {
    raw := SmallFlow()
    first := SceneBuilder.Build(raw, "", Map("A", "running"), Map(), "", "", 1)
    second := first.WithStates(first.View, Map("B", "running", "c1", "recent"), Map(), 2)
    full := SceneBuilder.Build(raw, "", Map("B", "running", "c1", "recent"), Map(), "", "", 2)
    Assert.Equal(second.Version, 2, "version")
    for element in full.Elements {
        mine := ElementById(second, element.Id)
        Assert.Equal(mine.Run, element.Run, "run state of " element.Id " as a build gives it")
        Assert.Equal(mine.Bounds.W, element.Bounds.W, "geometry of " element.Id)
    }
    Assert.Equal(second.Connections[1].Run, "recent", "run state of the connection")
    Assert.Equal(second.Connections[1].Segments.Length, full.Connections[1].Segments.Length, "segments")
    Assert.True(ElementById(second, "A") != ElementById(first, "A"), "A changed (no longer running): a new object")
    Assert.True(ElementById(second, "L") == ElementById(first, "L"), "L did not change: the same object")
    Assert.True(second.Connections[1] != first.Connections[1], "the connection changed: a new object")
}

; The view of a scene changes with WithStates, the element positions in flow coordinates do not.
WithStatesChangesView() {
    raw := SmallFlow()
    first := SceneBuilder.Build(raw, EditorView(0.7, -200, -200, 96, 800, 600))
    view := EditorView(1.5, 0, 0, 96, 800, 600)
    second := first.WithStates(view, Map(), Map(), 3)
    Assert.True(second.View == view, "the new view")
    Assert.Equal(ElementById(second, "A").X, 0, "x in flow coordinates")
    Assert.Equal(second.Bounds.Right, first.Bounds.Right, "the flow box is the same")
}

AllExamplesBuild() {
    count := 0
    loop files A_ScriptDir "\..\..\tests\data\flows\v1_examples\*.json" {
        raw := FlowOf(FileRead(A_LoopFileFullPath, "UTF-8"))
        sc := SceneBuilder.Build(raw)
        allElements := raw["allElements"]
        allConnections := raw["allConnections"]
        Assert.Equal(sc.Elements.Length, allElements.Count, A_LoopFileName ": elements")
        dangling := 0
        for id, c in allConnections {
            if (!allElements.Has(c["from"]) || !allElements.Has(c["to"]))
                dangling++
        }
        Assert.Equal(sc.Connections.Length + dangling, allConnections.Count, A_LoopFileName ": connections")
        count++
    }
    Assert.True(count >= 20, "the 23 v1 example flows were found, got " count)
}

UnknownClassIsPlaceholder() {
    sc := SceneBuilder.Build(FlowOf('{"allElements": {"X": {"ID": "X", "type": "action", "class": '
        . '"action_No_Such_Thing", "package": "Default"}}, "allConnections": {}}'))
    el := sc.Elements[1]
    Assert.True(InStr(el.Placeholder, "unknown element class 'Default.action_No_Such_Thing'"), el.Placeholder)
    Assert.Equal(el.Icon, "", "a placeholder has no icon")
    Assert.Equal(el.ClassName, "action_No_Such_Thing", "the display name is the class as written")
}

MissingPackage() {
    sc := SceneBuilder.Build(FlowOf('{"allElements": {"X": {"ID": "X", "type": "action", "class": '
        . '"action_Other", "package": "Extra"}}, "allConnections": {}}'))
    el := sc.Elements[1]
    Assert.True(InStr(el.Placeholder, "package 'Extra' is not installed"), el.Placeholder)
}

KnownClassHasName() {
    sc := SceneBuilder.Build(SmallFlow())
    el := sc.Elements[1]
    Assert.Equal(el.Placeholder, "", "a known class has no placeholder")
    Assert.Equal(el.ClassName, Default.Action_Sleep.Name(), "the display name of the class")
    Assert.True(el.ClassName != "action_Sleep", "the name is a text of the language, not the class ID")
}

; The text on an element is the name the user gave it; without a name the display name of the class; the package is
; kept for the icon path.
TextAndPackage() {
    sc := SceneBuilder.Build(SmallFlow())
    Assert.Equal(sc.Elements[1].Name, "a", "the user's name of element A")
    Assert.Equal(sc.Elements[1].Package, "Default", "the package of the class")
    nameless := FlowOf('{"allElements": {"N": {"ID": "N", "type": "action", "class": "action_Sleep", '
        . '"package": "Default", "x": 0, "y": 0}}, "allConnections": {}}')
    el := SceneBuilder.Build(nameless).Elements[1]
    Assert.Equal(el.Name, Default.Action_Sleep.Name(), "without a name the display name is drawn")
}

StatesAreCopied() {
    raw := FlowOf('{"allElements": {'
        . '"T": {"ID": "T", "type": "trigger", "class": "trigger_manual", "package": "Default", "x": 0, "y": 0,'
        . ' "migration": [{"par": "p1", "ids": ["M-0025"], "v1": "%a%"}]},'
        . '"A": {"ID": "A", "type": "action", "class": "action_Sleep", "package": "Default", "x": 0, "y": 300}},'
        . '"allConnections": {"c1": {"ID": "c1", "from": "T", "to": "A", "ConnectionType": "normal"}}}')
    runStates := Map("A", "running", "c1", "recent")
    trigger := Map("T", Map("enabled", 1, "armed", 0, "message", "missing package"))
    warnings := Map("A", "a warning of the evaluation")
    sc := SceneBuilder.Build(raw, "", runStates, trigger, warnings)
    t := ElementById(sc, "T")
    a := ElementById(sc, "A")
    Assert.Equal(t.Kind, "trigger", "kind")
    Assert.Equal(t.Trigger["enabled"], 1, "enabled state")
    Assert.Equal(t.Trigger["armed"], 0, "armed state")
    Assert.Equal(t.Trigger["message"], "missing package", "message of the trigger")
    Assert.Equal(t.Migration.Length, 1, "migration places are copied")
    Assert.Equal(t.Migration[1]["par"], "p1", "the parameter of the migration place")
    Assert.Equal(t.Migration[1]["ids"][1], "M-0025", "the ID list of the migration place")
    Assert.True(!(t.Migration[1] == raw["allElements"]["T"]["migration"][1]), "the migration Map is a copy")
    Assert.Equal(a.Run, "running", "run state of an element")
    Assert.Equal(a.Trigger, "", "a non-trigger has no trigger state")
    Assert.Equal(sc.Connections[1].Run, "recent", "run state of a connection")
    Assert.Equal(a.Warning, "a warning of the evaluation", "warning of an element")
    Assert.Equal(sc.Warnings.Length, 1, "the warning is listed in the sc")
}

DanglingConnection() {
    raw := FlowOf('{"allElements": {"A": {"ID": "A", "type": "action", "class": "action_Sleep", "package": "Default"}},'
        . '"allConnections": {"c1": {"ID": "c1", "from": "A", "to": "nope", "ConnectionType": "normal"},'
        . '"c2": {"ID": "c2", "from": "", "to": "", "ConnectionType": "normal"}}}')
    sc := SceneBuilder.Build(raw)
    Assert.Equal(sc.Connections.Length, 0, "no connection is drawn")
    Assert.Equal(sc.Warnings.Length, 2, "both are warnings")
}

TextPositions() {
    sc := SceneBuilder.Build(FlowOf('{"allElements": {"A": {"ID": "A", "type": "Action", "class": "action_Sleep",'
        . ' "package": "Default", "x": "175", "y": "-20.5"}}, "allConnections": {}}'))
    Assert.Equal(sc.Elements[1].X, 175, "x of a text")
    Near(sc.Elements[1].Y, -20.5, "y of a text")
    Assert.Equal(sc.Elements[1].Kind, "action", "the kind is lowercased")
}

SceneIsACopy() {
    raw := FlowOf('{"allElements": {"A": {"ID": "A", "type": "action", "class": "action_Sleep", "package": "Default",'
        . ' "x": 10, "y": 20}}, "allConnections": {}}')
    sc := SceneBuilder.Build(raw)
    raw["allElements"]["A"]["x"] := 999
    Assert.Equal(sc.Elements[1].X, 10, "a change of the flow does not reach the sc")
}

VersionAndBounds() {
    hit := FlowHit("element", "A", 1)
    sc := SceneBuilder.Build(SmallFlow(), "", "", "", "", hit, 7)
    Assert.Equal(sc.Version, 7, "version")
    Assert.True(sc.Hovered == hit, "the hovered item is the one given")
    b := sc.Bounds
    Near(b.X, 0, "left of the box")
    Near(b.Y, 0, "top of the box")
    Near(b.Right, 540, "right: the loop")
    Near(b.Bottom, 405, "bottom: the target B (200,300) and its box")
}

EmptyFlow() {
    sc := SceneBuilder.Build(Map())
    Assert.Equal(sc.Elements.Length, 0, "no elements")
    Assert.Equal(sc.Connections.Length, 0, "no connections")
    Near(sc.Bounds.W, 0, "empty box")
    Assert.True(sc.View.Zoom = 0.7, "the default view")
}

HitElementParts() {
    sc := SceneBuilder.Build(SmallFlow())
    h := FlowHitTest.At(sc, 70, 50)
    Assert.Equal(h.Kind, "element", "kind")
    Assert.Equal(h.Id, "A", "element")
    Assert.Equal(h.Index, 1, "the only part of an action")
    h := FlowHitTest.At(sc, 405, 120)
    Assert.Equal(h.Id, "L", "loop")
    Assert.Equal(h.Index, 2, "the bar of the loop")
    h := FlowHitTest.At(sc, 500, 150)
    Assert.Equal(h.Index, 3, "the foot of the loop")
    h := FlowHitTest.At(sc, 520, 150)
    Assert.Equal(h.Index, 4, "the break field of the loop")
    h := FlowHitTest.At(sc, 450, 50)
    Assert.Equal(h.Index, 1, "the head of the loop")
}

HitConnectionSegment() {
    sc := SceneBuilder.Build(SmallFlow())
    h := FlowHitTest.At(sc, 120, 212.5)
    Assert.Equal(h.Kind, "connection", "kind")
    Assert.Equal(h.Id, "c1", "connection")
    Assert.Equal(h.Index, 2, "the horizontal segment")
    h := FlowHitTest.At(sc, 120, 222)
    Assert.Equal(h.Index, 2, "inside the margin of 20 below the segment")
    h := FlowHitTest.At(sc, 75, 190)
    Assert.Equal(h.Index, 1, "the vertical segment from the source (checked before the horizontal one)")
    Assert.Equal(FlowHitTest.At(sc, 120, 230), "", "outside the margin of 20")
}

HitOrderAndMiss() {
    sc := SceneBuilder.Build(SmallFlow())
    h := FlowHitTest.At(sc, 70, 105)
    Assert.Equal(h.Kind, "element", "the bottom edge of A is A, not the connection that starts there")
    Assert.Equal(FlowHitTest.At(sc, 1000, 1000), "", "nothing far away")
}

; The buttons of a selected action: edit left, trash right, plus below (v1 positions, size 35); a click on the plus
; button is the button, not the element; the element alone is not a button.
ButtonsOfAnElement() {
    sc := SceneBuilder.Build(SmallFlow()).WithInteraction(Map("A", true))
    Assert.Equal(sc.Buttons.Length, 3, "edit, trash and plus")
    Assert.Equal(sc.Buttons[1]["name"], "edit", "first button")
    Near(sc.Buttons[1]["rect"].X, -24.5 - 17.5, "edit box left: centre minus half the size")
    Near(sc.Buttons[3]["rect"].Y, 122.5 + 7 - 17.5, "plus box top")
    h := FlowHitTest.At(sc, 70, 129.5)
    Assert.Equal(h.Kind, "button", "the plus button wins")
    Assert.Equal(h.Index, "plus", "its name")
    Assert.Equal(h.Id, "A", "its element")
    Assert.Equal(FlowHitTest.At(sc, 70, 105).Kind, "element", "the bottom edge of the element is the element")
    Assert.Equal(SceneBuilder.Build(SmallFlow()).Buttons.Length, 0, "no selection, no buttons")
}

; A loop has a second plus below its foot (v1: width / 8 + 4/3 of the height + bar + 0.2 of the size).
ButtonsOfALoop() {
    sc := SceneBuilder.Build(SmallFlow()).WithInteraction(Map("L", true))
    Assert.Equal(sc.Buttons.Length, 4, "edit, trash, plus and the plus of the foot")
    Near(sc.Buttons[4]["rect"].Y + 17.5, 17.5 + 140 + 40 + 7, "the second plus is below the foot")
}

; A selected connection A to B: edit, trash and plus on the middle of its third segment, and two move buttons at the
; ends (the first and the last segment); with a short connection the move buttons are left out (v1 rule).
ButtonsOfAConnection() {
    sc := SceneBuilder.Build(SmallFlow()).WithInteraction(Map("c1", true))
    Assert.Equal(sc.Buttons.Length, 5, "five buttons for a long connection")
    names := ""
    for button in sc.Buttons
        names .= button["name"] " "
    Assert.Equal(names, "edit trash plus move1 move2 ", "the names in order")
    h := FlowHitTest.At(sc, 170, 202.5)
    Assert.Equal(h.Kind, "button", "the plus button is on the middle of the third segment (x 70 + (270 - 70) / 2)")
    Assert.Equal(h.Index, "plus", "plus")
    Assert.Equal(h.Id, "c1", "of the connection")
    raw := FlowOf('{"allElements": {'
        . '"A": {"ID": "A", "type": "action", "class": "action_Sleep", "package": "Default", "x": 0, "y": 0},'
        . '"B": {"ID": "B", "type": "action", "class": "action_Sleep", "package": "Default", "x": 0, "y": 130}},'
        . '"allConnections": {"c1": {"ID": "c1", "from": "A", "to": "B", "ConnectionType": "normal"}}}')
    short := SceneBuilder.Build(raw).WithInteraction(Map("c1", true))
    Assert.Equal(short.Buttons.Length, 3, "no move buttons for a short connection")
}

; A drag: the dragged element and its connection are moved, the base scene is not changed, and no buttons are shown
; while the drag runs.
DragMovesElementAndConnection() {
    plain := SceneBuilder.Build(SmallFlow()).WithInteraction(Map("B", true))
    sc := plain.WithDrag(Map("B", true), 10, 20)
    Assert.True(sc.Dragged.Has("B"), "B is dragged")
    Near(ElementById(sc, "B").X, 210, "x moved")
    Near(ElementById(sc, "B").Y, 320, "y moved")
    Near(ElementById(plain, "B").X, 200, "the base scene keeps the position")
    Near(sc.Connections[1].AimX, 280, "the connection ends at the moved element")
    Near(sc.Connections[1].AimY, 320, "its aim y")
    Near(sc.Connections[1].StartX, 70, "the other end stays")
    Assert.Equal(sc.Buttons.Length, 0, "no buttons during a drag")
    Assert.Equal(plain.Buttons.Length, 3, "the base scene keeps its buttons")
    Assert.True(sc.Connections[1] != plain.Connections[1], "the connection is a new object")
    Assert.True(ElementById(sc, "A") == ElementById(plain, "A"), "an element not dragged is the same object")
    states := sc.WithStates(sc.View, Map("A", "running"), Map(), 7)
    Assert.True(states.Dragged.Has("B") && ElementById(states, "B").X = 210, "a state change keeps the drag")
}

; The interaction that is not the selection: the connection being drawn starts at the part of the element and the
; rectangle is kept; both are copies of the request.
ConnectingAndRectangle() {
    sc := SceneBuilder.Build(SmallFlow()).WithInteraction(Map(), FlowRect(1, 2, 3, 4)
        , Map("fromId", "A", "fromPart", "", "type", "normal", "x", 100, "y", 200))
    Near(sc.Connecting["start"][1], 70, "start x: bottom centre of A")
    Near(sc.Connecting["start"][2], 105, "start y")
    Near(sc.Connecting["aim"][1], 100, "aim x")
    Assert.Equal(sc.Rect.W, 3, "the rectangle width")
    Assert.Equal(sc.WithInteraction(Map()).Connecting, "", "a new interaction without a connection")
    Assert.Equal(SceneBuilder.Build(SmallFlow()).Connecting, "", "none by default")
}

; The fields for new elements: fixed in device pixels (not in the flow), scaled by the DPI, in the order action,
; condition, loop, trigger (v1 positions).
NewElementFieldsAt() {
    Assert.Equal(NewElementFields.At(96, 50, 40), "action", "the action field")
    Assert.Equal(NewElementFields.At(96, 140, 40), "condition", "the condition field")
    Assert.Equal(NewElementFields.At(96, 260, 40), "loop", "the loop field")
    Assert.Equal(NewElementFields.At(96, 380, 40), "trigger", "the trigger field")
    Assert.Equal(NewElementFields.At(96, 200, 300), "", "an empty place")
    Assert.Equal(NewElementFields.At(192, 50, 40), "action", "scaled by 2 at 192 DPI")
    Assert.Equal(NewElementFields.At(192, 15, 40), "", "the field at 192 DPI starts at 20 pixels")
}

TestRun.Finish()
