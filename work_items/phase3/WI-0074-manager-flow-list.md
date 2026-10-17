# WI-0074 Manager: flow tree with state and the operations

Size: L · Depends on: WI-0070, WI-0071, WI-0073 · Blocks: WI-0075, WI-0076, WI-0081

## Goal

The manager shows every flow in its category with its live state and offers every operation on flows and categories: run, stop, enable, disable, new, rename, duplicate, delete, move, order by drag and drop, sort alphabetically, and the category operations. It asks the questions that S0003 left for it (E0056, E0063). Requirements: REQ-MGR-010, REQ-MGR-020, REQ-MGR-030, REQ-MGR-040, REQ-EXE-060, REQ-EXE-070, REQ-EXE-140, REQ-TRG-050, REQ-MIG-070 (manager part).

## Read first

As WI-0073, plus E0056, E0063, E0066, E0067 in `doc/DECISIONS.md`; PROTOCOL 4.2 (switch commands, `force`, `all`), 4.3 (`evt.flow.state`, `evt.trigger.state`, `stateError`); REQ-TRG-050 and REQ-MIG-070 in `doc/REQUIREMENTS.md`; v1 `Manager GUI.ahk` (selection rules, several flows selected), `Change Category GUI.ahk`; AHK v2 docs `lib/TreeView.htm`.

## Tasks

1. **Tree:** categories in their order, flows in their order, the state of a flow visible (enabled, running with the number of instances, independent triggers active while the flow is inactive, unknown state, missing packages, stopped by a limit); icons or text marks, translated. Several flows can be selected (as v1).
2. **Operations** through the model: run (the default manual trigger), stop, enable, disable, new (in the selected category), rename (dialog with the check of the engine's rules), duplicate, delete (confirmation; the text says that it is final, E0066), move to a category (dialog), the category operations, drag and drop of categories and flows, "sort alphabetically". "Edit" is shown and disabled until S0005.
3. **Questions from S0003:**
   - Disabling an inactive flow with active independent triggers by hand asks whether to disable them too and says that only the editor can enable them again (E0056); "yes" sends `all: true`.
   - A switch of a flow with an unknown state that the engine refuses asks whether to overwrite the state file with the state of the session; "yes" sends `force: true` (E0063).
   - Enabling a flow whose trigger is in a missing package tells the user that this trigger is not available (REQ-MIG-070).
4. **Tests:** headless e2e through the driver for every operation and every question (both answers); the live state follows a running flow; a flow added by another client appears; the order after drag and drop as the engine keeps it. `gui` tests for the tree and drag and drop (owner).

## Acceptance criteria

- The headless tests are green, serial and parallel; the `gui` tests exist with a VS Code task (rule 10).
- The requirements of the goal have their manager evidence.

## Not part of this

Notices (WI-0075), the import (WI-0076), export (WI-0081).
