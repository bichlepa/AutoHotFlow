# WI-0056 Core set E: dialogs and worker elements

Size: M · Depends on: WI-0050, WI-0051 · Blocks: WI-0057

## Goal

The first real worker elements run: `Action_Message_Box`, `Condition_Confirmation_Dialog`, `Condition_Debug_Dialog`, `Action_Tooltip`. They are tested headless through the dialog test seam (E0038). Requirements: REQ-ELM-270, REQ-DBG-060 (the debug dialog is specified there in detail).

## Read first

As WI-0052, plus REQ-DBG-060 and REQ-USE-080, `doc/ARCHITECTURE.md` 2.3 and 6.4 (worker, blocking, `JobTimeoutMs`), `doc/MIGRATION.md` M-0002, result of WI-0050 and WI-0051, the v1 elements and their help texts.

## Tasks

1. Port by hand as in WI-0052, tasks 1 and 2. `Message_Box`, `Confirmation_Dialog`, `Debug_Dialog`: mode `worker`, dialogs only through the indirection of WI-0051.
2. `Condition_Debug_Dialog` as specified in REQ-DBG-060, in the worker through the requests of WI-0050 (reading **and writing** variables):
   - every variable the branch can see, grouped by scope (loop, thread, instance, static, global), with a refresh;
   - the value of a variable; an object as readable text, special characters optionally converted;
   - change the value and the type (value or object) of a variable, delete a variable (static and global ones change the permanent store, REQ-VAR-050);
   - the buttons "Yes" and "No" are the outputs; **closing the window ends the element with `exception`** (check against the v1 help text and `Debug_dialog.ahk`, deviations into MIGRATION);
   - other branches and flows go on while the dialog is open.
   Build the display part so that a read-only mode is possible: REQ-USE-080 (S0004) shows the variables of a failed branch in a window "like the debug dialog", without changing them. Secret values are masked later (REQ-SEC-040, `later`): show values through one function, so a mask can be added in one place.
3. `Action_Tooltip`: decide inline or worker (a tooltip does not block, but the engine shows no UI, ARCHITECTURE 1, goal 2; a worker that holds a tooltip for its duration occupies a pool slot). Record the decision with the reason in the result and in ELEMENT-API.
4. Stop while a dialog is open: behaviour as in ELEMENT-API 2 (worker blocked in a single call, terminated after 2 s); test with the test provider ("no answer").
   The test provider (WI-0051) must be able to answer the debug dialog with a script: "set variable X to V, delete Y, then Yes", "No" and "close window". If it cannot, extend it in this package, with its test.
5. e2e tests: every button and result, timeout of the dialog, two dialogs of two instances at the same time (two workers); the debug dialog: change of a value and of a type, a delete, every scope visible, the closed window, a changed `static_`/`global_` variable visible to another flow.

## Acceptance criteria

- **Load path (F-0073, README S0002):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- Smoke test and e2e tests green without the `gui` tier.
- One `gui` test per element (marked, run only by the project owner) shows the real dialog. The real dialogs should be sharp and correctly sized with a display scaling above 100 % (REQ-USE-090): the manual check asks the owner to look.

## Docs

`doc/ELEMENT-API-V2.md` (mode of `Tooltip`), `doc/MIGRATION.md`. `doc/REQUIREMENTS.md` (AGENTS rule 12): REQ-ELM-270, REQ-DBG-060, REQ-TST-030 (`v2`, table rows, `Evidence`), then `python tools/req_index.py`.

## Not part of this

`Input_Box`, `Select_file`, `Select_folder` (S0008); the error notice window (REQ-USE-080, S0004); an expression field in the dialog (REQ-SCR-120, `later`).
