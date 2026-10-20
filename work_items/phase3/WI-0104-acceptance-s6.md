# WI-0104 Acceptance S0006

Size: M · Depends on: WI-0093 to WI-0103 · Blocks: S0007 (its packages that depend on S0006)

## Goal

S0006 is demonstrably finished and the documents match the code. Its retrospective refines the S0007 packages before they start (E0095).

## Tasks

1. **Criteria:** go through "Acceptance S0006" in `work_items/phase3/README.md` point by point, with the evidence (test, run ID, measurement, manual check) in the result.
2. **Editing during execution (E0001):** the e2e tests of WI-0093 and WI-0094 are the evidence; add any case of ARCHITECTURE 4.2 that is still missing.
3. **Nothing lost (REQ-ROB-120, REQ-EDT-100):** a killed editor, a killed engine, an exit while edits are unsaved; the backups by E0065.
4. **Measurements** (`doc/MEASUREMENTS.md`): the answer of a patch on the flow of 300 elements, the frame during a drag of 30 elements, the rebuild after the drop.
5. **Manual check 10** (new section in `doc/MANUAL-CHECKS.md` with VS Code tasks): the owner edits the imported v1 flows at 100 % and 225 %: select, rectangle, move, loop height, add, connect, connection type, delete, copy and paste between two flows, undo and redo, menu bar, keys, context menus, the trigger buttons, an editor killed by hand (the notice and the reopen); the owner also runs the `gui` tests of S0006.
6. **Documents:** REQUIREMENTS (every requirement of S0006 with `v2`, `Plan`, `Evidence`), PROTOCOL, ARCHITECTURE 2.1, 4, 4.2, 8, 10, MIGRATION, MANUAL-CHECKS, `.vscode/tasks.json`; `python tools/doc_index.py --check`.
7. **Retrospective:** what was hard (HOW-TO entries), and what S0007 needs from the patch client, the dialogs and the key and menu handling. Write the refinements of the S0007 packages into their files and into the plan, as a proposal for the owner.
8. **Runs:** serial, parallel, `-m stress`, foundation and slow green.

## Acceptance criteria

- Every point of the S0006 acceptance has its evidence; the owner closed manual check 10; the S0007 packages are refined.

## Not part of this

New features.
