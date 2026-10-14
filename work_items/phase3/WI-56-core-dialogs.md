# WI-56 Core set E: dialogs and worker elements

Size: M · Depends on: WI-50, WI-51 · Blocks: WI-57

## Goal

The first real worker elements run: `Action_Message_Box`, `Condition_Confirmation_Dialog`, `Condition_Debug_Dialog`, `Action_Tooltip`. They are tested headless through the dialog test seam (E38).

## Read first

As WI-52, plus `doc/ARCHITECTURE.md` 2.3 and 6.4 (worker, blocking, `JobTimeoutMs`), `doc/MIGRATION.md` M-02, result of WI-50 and WI-51, the v1 elements and their help texts.

## Tasks

1. Port by hand as in WI-52, tasks 1 and 2. `Message_Box`, `Confirmation_Dialog`, `Debug_Dialog`: mode `worker`, dialogs only through the indirection of WI-51.
2. `Condition_Debug_Dialog` shows the variables of the instance: in the worker through the requests of WI-50.
3. `Action_Tooltip`: decide inline or worker (a tooltip does not block, but the engine shows no UI, ARCHITECTURE 1, goal 2; a worker that holds a tooltip for its duration occupies a pool slot). Record the decision with the reason in the result and in ELEMENT-API.
4. Stop while a dialog is open: behaviour as in ELEMENT-API 2 (worker blocked in a single call, terminated after 2 s); test with the test provider ("no answer").
5. e2e tests: every button and result, timeout of the dialog, two dialogs of two instances at the same time (two workers).

## Acceptance criteria

- **Load path (F-282, README S2):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- Smoke test and e2e tests green without the `gui` tier.
- One `gui` test per element (marked, run only by the project owner) shows the real dialog.

## Docs

`doc/ELEMENT-API-V2.md` (mode of `Tooltip`), `doc/MIGRATION.md`.

## Not part of this

`Input_Box`, `Select_file`, `Select_folder` (S8).
