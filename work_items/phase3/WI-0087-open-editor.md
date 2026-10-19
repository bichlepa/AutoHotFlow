# WI-0087 Open and close an editor: supervisor and manager

Size: M · Depends on: – · Blocks: WI-0088

## Goal

The user opens the editor of a flow from the manager, with the button "Edit" or a double click on the flow (as v1). There is one editor per flow (D0002): opening a flow whose editor runs brings it to the front. A flow ID with a space reaches the editor intact. Requirement: REQ-EDT-010 (part).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 3, 6.1, 6.3; `doc/CONVENTIONS.md`; `doc/PROTOCOL.md` 2, 3, 4.1, 4.8; `src/supervisor/Children.ahk` (`Spawn`, `_Launch`: `--flow` without quotes, line 563), `src/core/Args.ahk`, `src/core/Role.ahk` (`flowId`, `ByeFn`); `src/manager/ManagerModel.ahk` (`ButtonStates`), `src/manager/ManagerWindow.ahk`, `src/manager/ManagerOps.ahk`, `src/manager/ManagerDriver.ahk`; `v1/Source_Manager/User Interface/Manager GUI.ahk:577` (double click).

## Tasks

1. **Docs first** (PROTOCOL 4.1, 4.8): `cmd.editor.open {flowId}` (manager → supervisor): starts the role `editor:<flowId>` with `--flow`, or, if it runs, sends it `cmd.editor.show`; answer `{ ok, started }`. Errors: `denied` (sender not `manager`), `shutting_down`, `busy` (more than `Children.EDITOR_LIMIT` editors, proposal 20), `bad_payload` (empty `flowId`, or a character that a role name or a command line cannot carry). The supervisor does not check that the flow exists; the editor does (WI-0088).
2. **Command line:** `Children._Launch` quotes the value of `--flow`; `Args` reads it back. A test starts a test role with a flow ID with a space and checks the round trip.
3. **Supervisor:** an editor ends with a clean bye as a planned end (no crash report); an editor that crashes or hangs is reported and not restarted (as today); the limit is counted over the living editors.
4. **Manager:** "Edit" is enabled when exactly one flow is selected (a flow with missing packages too, REQ-MIG-070: the editor shows placeholders); a double click on a flow does the same; the model sends `cmd.editor.open` and shows an error answer as a notice. Headless driver: `cmd.test.op {op: "edit"}`.
5. **Tests** (e2e, headless): "Edit" of a flow starts one process `editor:<flowId>` with the right `--flow` (until WI-0088 it is the placeholder, which ends with exit 3: the test checks the start and the command line); a second "Edit" of the same flow while it runs starts no second process; the limit; a sender other than the manager is `denied`.

## Acceptance criteria

- The tests of task 5 are green; PROTOCOL is updated; REQ-MGR (the button "Edit") updated.

## Not part of this

The editor itself (WI-0088); its tray menu (WI-0091).
