# WI-0107 Editor `ctx` (other flows), trigger option "Switch with the flow", M-0064 back

Size: M · Depends on: WI-0105 · Blocks: WI-0114

## Goal

In the editor, the elements see what v1 gave them: the other flows, their triggers and the names of their elements. M-0064 goes back. Every trigger dialog has the checkbox "Switch with the flow" (E0056). Requirements: REQ-TRG-050 (editor part), REQ-ELM-010.

## Read first

`AGENTS.md`; `doc/ELEMENT-API-V2.md` 3; `doc/MIGRATION.md` M-0064; `doc/DECISIONS.md` E0056; `doc/PROTOCOL.md` 4.2 (`cmd.engine.snapshot`); `Action_Execute_Flow`, `Action_Stop_Flow`, `Condition_Flow_Running`, `Action_Set_Flow_Status`, `Condition_Flow_Enabled`; v1: `v1/Source_Editor/API/API for Elements.ahk` (the editor side, lines 165 to 312).

## Tasks

1. **Docs first:** the `ctx` of the editor side in ELEMENT-API-V2 3, and the engine command it needs (for example `cmd.flow.triggers {flowId}`: the manual triggers with their IDs and names) in PROTOCOL 4.2.
2. **The cache:** the editor asks the engine when a dialog opens, keeps the answer and drops it on `evt.flow.list.changed`. The scene must not wait: a name without the cache shows the IDs.
3. **The elements use it:** names and lists as in v1 (M-0064 goes back; MIGRATION is updated).
4. **"Switch with the flow":** every trigger dialog has the checkbox (`followsFlow`, E0056). It is added by the editor, not by each class, and written by the same patch; the engine follows (WI-0094).
5. **Tests:** headless dialogs of the five elements with the lists of a second flow; the checkbox written and the engine's state.

## Acceptance criteria

- The tests of task 5 are green. ELEMENT-API-V2, PROTOCOL and MIGRATION are updated. REQ-TRG-050 is updated.

## Not part of this

Lists of variables (REQ-EDT-190, later).
