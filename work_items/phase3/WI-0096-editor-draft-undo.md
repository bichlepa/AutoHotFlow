# WI-0096 Editor: draft, patch client, undo and redo, selection model, the view written

Size: L · Depends on: WI-0093 · Blocks: WI-0098, WI-0109

## Goal

The editor can change its flow. Its model gets a draft, sends patches, keeps the steps for undo and redo and holds the selection, all without a window and driven headless. The view is saved (E0086). Requirements: REQ-EDT-090, REQ-EDT-100 (editor part), REQ-EDT-030 (the view is saved).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 4, 4.2; `doc/PROTOCOL.md` 4.2, 4.11; `src/editor/EditorModel.ahk`, `EditorDriver.ahk`, `SceneBuilder.ahk`, `EditorView.ahk`; WI-0093 (result, `FlowPatch`); v1: `v1/Source_Common/Flows/States.ahk`.

## Tasks

1. **Docs first:** PROTOCOL 4.11 (the requests that write, the session ID, the conflict rule, the test commands); ARCHITECTURE 4 (draft, undo and selection in the editor).
2. **Draft:** the committed definition plus the operations that are not answered yet. The scene is built from the draft. New IDs come from `ElementIDCounter` of the draft, in the v1 format.
3. **Patch client:** `Commit(ops, undoable := true)` applies the operations to the draft and sends `cmd.flow.patch {flowId, baseRev, ops, session}`. One patch is in flight and the others wait in a queue.
   - `ok`: the new `rev` is taken.
   - `conflict`: the operations are applied again on the definition of the answer and sent once more.
   - A refused operation or a second conflict: the editor takes the engine's definition, clears the undo stack and says so in the status bar.
   - `timeout` or `peer_gone`: a resync.

   `evt.flow.committed` with the editor's own `rev` is ignored.
4. **Undo and redo:** a step holds the operations and their inverse (`FlowPatch.Inverse`); undo sends the inverse as a new patch. At most 100 steps (v1). A new step clears redo. A new `epoch` clears both stacks. A step whose inverse no longer applies is refused with a text in the status bar.
5. **Selection:** a set of element and connection IDs. An ID that the definition no longer has is dropped. The functions are select one, toggle, select all and select none. The scene carries the selection (WI-0097 draws it).
6. **The view written (E0086):** a `flow.settings` patch with `view: true` (`zoomFactor`, `Offsetx`, `Offsety`, in the types the file has), sent 2 s after the last change of the view and when the editor closes (before the bye, with a short timeout). It is not an undo step.
7. **Headless driver:** `cmd.test.edit {ops}` (the operations as one step), `cmd.test.undo`, `cmd.test.redo`, `cmd.test.select {ids, mode}`. `cmd.test.state` adds `selection`, `undo` and `redo` (counts) and `pending`.
8. **Tests:**
   - e2e: an edit is committed (`cmd.flow.get` shows it); undo and redo; 101 steps keep 100; a rename by the manager while the editor has a patch on its way is merged (REQ-EDT-100); an engine restart clears the stacks and the editor shows the saved state; the view is saved and an editor opened again uses it.
   - Unit tests with a fake peer: the queue and the conflict rule.

## Acceptance criteria

- The tests of task 8 are green. PROTOCOL and ARCHITECTURE are updated. REQ-EDT-090, REQ-EDT-100 and REQ-EDT-030 are updated.

## Not part of this

The mouse and the keys (WI-0098 to WI-0102); the drawing of the selection (WI-0097).
