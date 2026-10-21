#Requires AutoHotkey v2.0
; Unit tests for src/editor/EditorDraft.ahk (WI-0096, PROTOCOL 4.2 and 4.11, ARCHITECTURE 4.2): the draft and the patch client
; (one patch in flight, the queue, the conflict rule, refusals, a lost answer, an answer that waits), undo and redo (the stacks,
; the limit of 100 steps, a step whose inverse no longer applies), the selection and the view that is written as flowSettings.
; The peer is a fake that records the requests; the test answers them by hand.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\core\Json.ahk
#Include ..\..\src\core\FlowPatch.ahk
#Include ..\..\src\editor\EditorModel.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk

; The peer of the draft: records requests; the test answers them by hand.
class FakePeer {
    __New() {
        this.requests := []
    }

    Subscribe(topic) {
    }

    Request(to, type, payload, callback, timeoutMs := 5000) {
        this.requests.Push(Map("to", to, "type", type, "payload", payload, "cb", callback, "ms", timeoutMs))
    }

    ; Answers the oldest open request of the type with the payload. Throws when there is none.
    Answer(type, payload) {
        for i, req in this.requests {
            if (req["type"] = type) {
                this.requests.RemoveAt(i)
                req["cb"](FakeAnswer(payload))
                return
            }
        }
        throw AssertFailed("no open request of " type)
    }

    ; The oldest open request of the type (its record), or "" when there is none.
    Open(type) {
        for req in this.requests {
            if (req["type"] = type)
                return req
        }
        return ""
    }

    Count(type) {
        n := 0
        for req in this.requests {
            if (req["type"] = type)
                n += 1
        }
        return n
    }
}

class FakeAnswer {
    __New(payload) {
        this.payload := payload
    }
}

; The retries of the model: fn runs when the test calls RunLater().
class FakeLater {
    __New() {
        this.pending := []
    }

    Add(ms, fn) {
        this.pending.Push(fn)
    }
}

FLOW := "Flow 7"
TRIGGER := "element0000000001"
ACTION := "element0000000002"
CONNECTION := "connection0000000001"
NEW := "element0000000003"

; A trigger, an action and the connection between them, with the IDs of the v1 format (ElementIDCounter 2).
Definition(name := "Demo") {
    return Json.Parse('{"name": "' name '", "category": "", "ElementIDCounter": 2, "flowSettings": {"zoomFactor": "0.700000", '
        . '"Offsetx": "-200.000000", "Offsety": "-200.000000"}, "allElements": {'
        . '"' TRIGGER '": {"ID": "' TRIGGER '", "type": "trigger", "class": "Trigger_Manual", "package": "Default", '
        . '"packageVersion": "1", "x": 0, "y": 0, "name": "Manual", "StandardName": "Manual", "pars": {}, "DefaultTrigger": "1"},'
        . '"' ACTION '": {"ID": "' ACTION '", "type": "action", "class": "action_Sleep", "package": "Default", '
        . '"packageVersion": "1", "x": 0, "y": 300, "name": "Sleep", "StandardName": "Sleep", "pars": {}}},'
        . '"allConnections": {"' CONNECTION '": {"ID": "' CONNECTION '", "from": "' TRIGGER '", "to": "' ACTION
        . '", "ConnectionType": "normal", "type": "connection"}}}')
}

; An operation that adds an action with the given ID.
AddAction(id) {
    return Map("op", "element.add", "element", Map("ID", id, "type", "action", "class", "action_Sleep", "package", "Default"
        , "packageVersion", "1", "x", 0, "y", 600, "name", "Sleep", "StandardName", "Sleep", "pars", Map()))
}

Rename(id, name) => Map("op", "element.update", "id", id, "fields", Map("name", name))

; A model with a fake peer and a fake later, and the definition accepted as the engine's answer (rev 1).
Setup() {
    peer := FakePeer()
    later := FakeLater()
    model := EditorModel(peer, FLOW)
    model.later := (ms, fn) => later.Add(ms, fn)
    model.draft.Accept(Definition(), 1)
    return Map("peer", peer, "model", model, "later", later, "draft", model.draft)
}

; The name of an element in the committed definition of the draft.
CommittedName(t, id) => t["draft"].committed["allElements"][id]["name"]

CommitSendsOnePatch() {
    t := Setup()
    res := t["draft"].Commit([AddAction(NEW)])
    Assert.True(res["ok"], "the commit is accepted")
    Assert.Equal(t["peer"].Count("cmd.flow.patch"), 1, "one patch on its way")
    req := t["peer"].Open("cmd.flow.patch")
    Assert.Equal(req["payload"]["baseRev"], 1, "the base is the rev of the definition")
    Assert.Equal(req["payload"]["flowId"], FLOW, "the flow")
    Assert.Equal(t["draft"].root["allElements"].Has(NEW), true, "the draft has the element at once")
    Assert.Equal(t["draft"].committed["allElements"].Has(NEW), false, "the committed definition does not yet")
    t["peer"].Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    Assert.Equal(t["draft"].rev, 2, "the new rev is taken")
    Assert.Equal(t["draft"].committed["allElements"].Has(NEW), true, "the committed definition has it after the answer")
    Assert.Equal(t["draft"].queue.Length, 0, "nothing waits")
}

; One patch is in flight: the next one is sent when the answer is in, with the new rev as its base.
PatchesWaitInTheQueue() {
    t := Setup()
    t["draft"].Commit([AddAction(NEW)])
    t["draft"].Commit([Rename(ACTION, "Renamed")])
    Assert.Equal(t["peer"].Count("cmd.flow.patch"), 1, "only the first patch is sent")
    Assert.Equal(t["model"].State()["pending"], 2, "two patches are pending")
    t["peer"].Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    req := t["peer"].Open("cmd.flow.patch")
    Assert.Equal(req["payload"]["baseRev"], 2, "the second one goes out on the new rev")
    t["peer"].Answer("cmd.flow.patch", Map("ok", 1, "rev", 3))
    Assert.Equal(t["draft"].rev, 3, "two patches, two revs")
    Assert.Equal(CommittedName(t, ACTION), "Renamed", "the second change is in the definition")
}

UndoAndRedoSendTheInverseAndTheOperations() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    d.Commit([AddAction(NEW)])
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    Assert.Equal(d.undoSteps.Length, 1, "one step")
    Assert.Equal(d.Undo()["done"], true, "undo goes")
    Assert.Equal(d.root["allElements"].Has(NEW), false, "the element is taken away at once")
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 3))
    Assert.Equal(d.committed["allElements"].Has(NEW), false, "the inverse is committed")
    Assert.Equal(d.redoSteps.Length, 1, "the step waits for redo")
    Assert.Equal(d.Redo()["done"], true, "redo goes")
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 4))
    Assert.Equal(d.root["allElements"].Has(NEW), true, "redo brings it back")
    Assert.Equal(d.undoSteps.Length, 1, "redo is no new step")
    Assert.Equal(d.redoSteps.Length, 0, "and the redo stack is empty")
}

ANewStepClearsRedo() {
    t := Setup()
    d := t["draft"]
    d.Commit([AddAction(NEW)])
    t["peer"].Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    d.Undo()
    t["peer"].Answer("cmd.flow.patch", Map("ok", 1, "rev", 3))
    Assert.Equal(d.redoSteps.Length, 1, "one redo step")
    d.Commit([Rename(ACTION, "Other")])
    Assert.Equal(d.redoSteps.Length, 0, "a new step clears redo")
}

; 101 steps keep the last 100 (v1).
UndoStackKeepsOneHundredSteps() {
    t := Setup()
    d := t["draft"]
    loop 101 {
        id := "element" Format("{:010}", 100 + A_Index)
        d.Commit([AddAction(id)])
        t["peer"].Answer("cmd.flow.patch", Map("ok", 1, "rev", 1 + A_Index))
    }
    Assert.Equal(d.undoSteps.Length, 100, "100 steps kept")
    Assert.Equal(d.undoSteps[1]["ops"][1]["element"]["ID"], "element0000000102", "the oldest one was dropped")
}

; A conflict: the operations are applied again on the definition of the answer and sent once more.
ConflictRebasesTheHeadOnce() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    d.Commit([AddAction(NEW)])
    theirs := Definition("Demo renamed")
    theirs["allElements"][ACTION]["name"] := "Theirs"
    peer.Answer("cmd.flow.patch", Map("ok", 0, "error", Map("code", "conflict", "message", "rev"), "rev", 2, "definition", theirs))
    Assert.Equal(peer.Count("cmd.flow.patch"), 1, "sent once more")
    req := peer.Open("cmd.flow.patch")
    Assert.Equal(req["payload"]["baseRev"], 2, "on the rev of the answer")
    Assert.Equal(d.root["allElements"].Has(NEW), true, "the own change is on top")
    Assert.Equal(d.root["allElements"][ACTION]["name"], "Theirs", "and the other change is in")
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 3))
    Assert.Equal(d.rev, 3, "the rebased patch is committed")
    Assert.Equal(CommittedName(t, ACTION), "Theirs", "the committed definition has the other change")
    Assert.Equal(d.message, "", "no refusal")
}

; A second conflict refuses the queue: the engine's definition is taken, the stacks go, the status says so.
SecondConflictRefuses() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    d.Commit([AddAction(NEW)])
    peer.Answer("cmd.flow.patch", Map("ok", 0, "error", Map("code", "conflict", "message", "rev"), "rev", 2
        , "definition", Definition()))
    peer.Answer("cmd.flow.patch", Map("ok", 0, "error", Map("code", "conflict", "message", "rev"), "rev", 3
        , "definition", Definition()))
    Assert.Equal(d.queue.Length, 0, "the queue is gone")
    Assert.Equal(d.undoSteps.Length, 0, "the undo stack is cleared")
    Assert.True(d.message != "", "the status bar says so")
    Assert.True(peer.Count("cmd.flow.runstate") >= 1, "the engine state is asked for")
    Assert.Equal(d.root["allElements"].Has(NEW), false, "the draft is the engine's definition")
}

; A refused operation (bad_payload): the same as a second conflict.
RefusedOperationTakesTheEngineState() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    d.Commit([AddAction(NEW)])
    peer.Answer("cmd.flow.patch", Map("ok", 0, "error", Map("code", "bad_payload", "message", "patch operation 1")))
    Assert.Equal(d.queue.Length, 0, "the queue is gone")
    Assert.Equal(d.undoSteps.Length, 0, "the undo stack is cleared")
    Assert.True(d.message != "", "the status bar says so")
    Assert.True(peer.Count("cmd.flow.get") >= 1, "the definition is asked for")
    Assert.Equal(d.root["allElements"].Has(NEW), false, "nothing of the refused change is shown")
}

; A timeout is an unknown outcome: the queue and the stacks go, the engine's saved state is asked for.
LostAnswerResyncs() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    d.Commit([AddAction(NEW)])
    peer.Answer("cmd.flow.patch", Map("ok", 0, "error", Map("code", "timeout", "message", "no answer")))
    Assert.Equal(d.queue.Length, 0, "the queue is gone")
    Assert.Equal(d.inFlight, false, "nothing is in flight")
    Assert.True(d.message != "", "the status bar says so")
    Assert.True(peer.Count("cmd.flow.runstate") >= 1, "resync")
}

; A busy engine (a deletion pending): the same patch is sent again later.
BusyIsAskedAgainLater() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    d.Commit([AddAction(NEW)])
    peer.Answer("cmd.flow.patch", Map("ok", 0, "error", Map("code", "busy", "message", "busy")))
    Assert.Equal(peer.Count("cmd.flow.patch"), 0, "not sent at once")
    Assert.Equal(t["later"].pending.Length, 1, "a retry is scheduled")
    t["later"].pending[1]()
    Assert.Equal(peer.Count("cmd.flow.patch"), 1, "sent again")
    Assert.Equal(d.queue.Length, 1, "the patch is still queued")
}

; Undo of a step whose inverse no longer applies (the element is gone from the engine's definition): refused, the step stays.
UndoRefusedWhenTheInverseDoesNotApply() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    d.Commit([AddAction(NEW)])
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    d.Accept(Definition(), 5)                  ; the engine's definition without the element
    res := d.Undo()
    Assert.Equal(res["ok"], false, "refused")
    Assert.Equal(d.undoSteps.Length, 1, "the step stays on the stack")
    Assert.True(d.message != "", "the status bar says so")
}

; An answer of a resync that comes while a patch is in flight waits for the answer; the answer includes the patch.
DefinitionWaitsForThePatchInFlight() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    d.Commit([AddAction(NEW)])
    engine := FlowPatch.Apply(Definition(), [AddAction(NEW)])
    d.Accept(engine, 2)
    Assert.Equal(d.deferred != "", true, "the definition waits")
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    Assert.Equal(d.deferred, "", "applied after the answer")
    Assert.Equal(d.rev, 2, "rev 2")
    Assert.Equal(d.root["allElements"].Has(NEW), true, "the element is there once")
    Assert.Equal(d.queue.Length, 0, "the queue is empty: the patch was not applied twice")
}

; The selection: one, toggle, all, none; an ID the flow does not have is left out; the scene carries the selection.
SelectionModes() {
    t := Setup()
    d := t["draft"]
    d.SetSelection([TRIGGER, "element9999999999"], "one")
    Assert.Equal(d.selection.Count, 1, "the unknown ID is left out")
    d.SetSelection([ACTION], "toggle")
    Assert.Equal(d.selection.Count, 2, "toggle adds")
    d.SetSelection([TRIGGER], "toggle")
    Assert.Equal(d.selection.Has(TRIGGER), false, "toggle removes")
    d.SetSelection([], "all")
    Assert.Equal(d.selection.Count, 3, "all: two elements and a connection")
    d.SetSelection([], "none")
    Assert.Equal(d.selection.Count, 0, "none")
    d.SetSelection([ACTION], "one")
    t["model"].SelectionChanged()
    Assert.Equal(t["model"].CurrentScene().Selected.Has(ACTION), true, "the scene carries the selection")
}

; A removed element leaves the selection (the draft prunes it when the definition changes).
SelectionLosesRemovedIds() {
    t := Setup()
    d := t["draft"]
    d.SetSelection([ACTION], "one")
    d.Accept(Definition(), 2)
    Assert.Equal(d.selection.Count, 1, "the action is still there")
    d.Commit([Map("op", "element.remove", "id", ACTION)])
    Assert.Equal(d.selection.Count, 0, "the removed action is dropped")
}

; The view is written as flowSettings (view: true), not as an undo step; an unchanged view sends nothing.
ViewIsSavedAsFlowSettings() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    view := EditorView(1.5, 10, 20, 96, 800, 600)
    d.SaveView(view)
    Assert.Equal(d.undoSteps.Length, 0, "not an undo step")
    req := peer.Open("cmd.flow.patch")
    op := req["payload"]["ops"][1]
    Assert.Equal(op["op"], "flow.settings", "the flow settings")
    Assert.Equal(op["view"] == Json.True, true, "the view flag")
    Assert.Equal(op["settings"]["zoomFactor"], "1.500000", "the zoom as the file writes it")
    Assert.Equal(op["settings"]["Offsetx"], "10.000000", "the offset")
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    d.SaveView(view)
    Assert.Equal(peer.Count("cmd.flow.patch"), 0, "the same view is not sent again")
    Assert.Equal(d.undoSteps.Length, 0, "still no undo step")
}

; A refused view patch (zoom, offset) alone keeps the undo steps; a refused element patch clears them (F-0166).
RefusedViewPatchKeepsTheUndoSteps() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    d.Commit([AddAction(NEW)])
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    Assert.Equal(d.undoSteps.Length, 1, "one step")
    d.SaveView(EditorView(1.5, 10, 20, 96, 800, 600))
    peer.Answer("cmd.flow.patch", Map("ok", 0, "error", Map("code", "bad_payload", "message", "view")))
    Assert.Equal(d.undoSteps.Length, 1, "the refused view patch keeps the step")
    d.Commit([Rename(ACTION, "Other")])
    peer.Answer("cmd.flow.patch", Map("ok", 0, "error", Map("code", "bad_payload", "message", "rename")))
    Assert.Equal(d.undoSteps.Length, 0, "a refused element patch clears the steps")
}

; A new epoch (the engine restarted): the queue and both stacks go.
NewEpochClearsTheDraftState() {
    t := Setup()
    d := t["draft"]
    d.Commit([AddAction(NEW)])
    t["peer"].Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    d.Commit([Rename(ACTION, "Other")])
    d.NewEpoch()
    Assert.Equal(d.undoSteps.Length, 0, "undo cleared")
    Assert.Equal(d.redoSteps.Length, 0, "redo cleared")
    Assert.Equal(d.queue.Length, 0, "queue cleared")
}

; New IDs come from the draft's ElementIDCounter (the v1 format), and an ID that a commit adds raises the counter.
NewIdsComeFromTheCounter() {
    t := Setup()
    d := t["draft"]
    Assert.Equal(d.NextId("element"), "element0000000003", "the counter of the definition is 2")
    Assert.Equal(d.NextId("connection"), "connection0000000002", "connections take the same counter (v1)")
    d.Commit([AddAction(d.NextId("element"))])
    t["peer"].Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    Assert.Equal(d.NextId("element"), "element0000000004", "the next one after the added element")
}

; Before the definition arrived nothing can be edited.
CommitBeforeTheDefinitionIsBusy() {
    peer := FakePeer()
    model := EditorModel(peer, FLOW)
    res := model.draft.Commit([AddAction(NEW)])
    Assert.Equal(res["ok"], false, "refused")
    Assert.Equal(res["code"], "busy", "the code")
    Assert.Equal(peer.Count("cmd.flow.patch"), 0, "nothing sent")
}

; A view that needs no patch still waits for the patches that are on their way (the flush before the bye).
UnchangedViewWaitsForTheQueue() {
    t := Setup()
    d := t["draft"]
    box := Map("answered", "")
    d.Commit([AddAction(NEW)])
    d.SaveView(EditorView.FromFlowSettings(d.root["flowSettings"]), (ok) => box["answered"] := ok)
    Assert.Equal(box["answered"], "", "not done while the edit is on its way")
    t["peer"].Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    Assert.Equal(box["answered"], true, "done when the edit is answered")
}

; Undo of a change of the default trigger: the inverse sets the old default again and clears the new one (FlowPatch.Diff),
; and the draft ends in the state before the change. FlowPatch does not promise exactly one default by itself.
UndoOfADefaultTriggerChange() {
    t := Setup()
    d := t["draft"], peer := t["peer"]
    second := "element0000000005"
    d.Commit([Map("op", "element.add", "element", Map("ID", second, "type", "trigger", "class", "Trigger_Manual"
        , "package", "Default", "packageVersion", "1", "x", 0, "y", 0, "name", "Manual 2", "StandardName", "Manual 2"
        , "pars", Map(), "DefaultTrigger", Json.False))])
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 2))
    d.Commit([Map("op", "element.update", "id", second, "fields", Map("DefaultTrigger", Json.True))])
    peer.Answer("cmd.flow.patch", Map("ok", 1, "rev", 3))
    Assert.True(d.Undo()["done"], "undo goes")
    ops := peer.Open("cmd.flow.patch")["payload"]["ops"]
    Assert.Equal(ops.Length, 2, "the inverse sets the old default and clears the new one in one patch")
    els := d.root["allElements"]
    Assert.True(els[TRIGGER]["DefaultTrigger"] = "1" || els[TRIGGER]["DefaultTrigger"] = Json.True, "the old default is back")
    Assert.True(els[second]["DefaultTrigger"] = Json.False, "the new one is no default any more")
}

TestRun.Case("Editor draft: a commit is sent as one patch and taken at its answer", CommitSendsOnePatch)
TestRun.Case("Editor draft: patches wait in the queue, one in flight", PatchesWaitInTheQueue)
TestRun.Case("Editor draft: undo sends the inverse, redo the operations again", UndoAndRedoSendTheInverseAndTheOperations)
TestRun.Case("Editor draft: a new step clears the redo steps", ANewStepClearsRedo)
TestRun.Case("Editor draft: 101 steps keep the last 100", UndoStackKeepsOneHundredSteps)
TestRun.Case("Editor draft: a conflict is applied again on the answer and sent once", ConflictRebasesTheHeadOnce)
TestRun.Case("Editor draft: a second conflict refuses the queue and takes the engine's state", SecondConflictRefuses)
TestRun.Case("Editor draft: a refused operation takes the engine's state", RefusedOperationTakesTheEngineState)
TestRun.Case("Editor draft: a lost answer clears the queue and asks the engine", LostAnswerResyncs)
TestRun.Case("Editor draft: a busy engine is asked again later", BusyIsAskedAgainLater)
TestRun.Case("Editor draft: an undo whose inverse no longer applies is refused and keeps the step",
    UndoRefusedWhenTheInverseDoesNotApply)
TestRun.Case("Editor draft: a definition during a patch waits for the answer", DefinitionWaitsForThePatchInFlight)
TestRun.Case("Editor draft: the selection modes and the IDs the flow does not have", SelectionModes)
TestRun.Case("Editor draft: a removed element leaves the selection", SelectionLosesRemovedIds)
TestRun.Case("Editor draft: the view is written as flow settings and is no undo step", ViewIsSavedAsFlowSettings)
TestRun.Case("Editor draft: a refused view patch keeps the undo steps, a refused element patch clears them",
    RefusedViewPatchKeepsTheUndoSteps)
TestRun.Case("Editor draft: a new epoch clears the queue and both stacks", NewEpochClearsTheDraftState)
TestRun.Case("Editor draft: new IDs come from the counter of the draft", NewIdsComeFromTheCounter)
TestRun.Case("Editor draft: a commit before the definition is busy", CommitBeforeTheDefinitionIsBusy)

TestRun.Case("Editor draft: undo of a change of the default trigger", UndoOfADefaultTriggerChange)
TestRun.Case("Editor draft: an unchanged view waits for the queue", UnchangedViewWaitsForTheQueue)
TestRun.Finish()
