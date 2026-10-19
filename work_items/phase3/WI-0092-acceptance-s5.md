# WI-0092 Acceptance S0005

Size: M · Depends on: WI-0083 to WI-0091 · Blocks: S0006

## Goal

S0005 is demonstrably finished and the documents match the code. Afterwards S0006 is detailed.

## Tasks

1. **Criteria:** go through "Acceptance S0005" in `work_items/phase3/README.md` point by point, with the evidence (test, run ID, measurement, manual check) in the result.
2. **R0002 and REQ-PRF-060:** the frame time of the generated 300-element flow with the real editor (headless and with a window, 1920×1080 and 3840×2160, the whole flow visible and at zoom 1), and the time from an event to the frame; in `doc/MEASUREMENTS.md`, ARCHITECTURE 2.1 and 10.
3. **Memory with 5 editors** (MS-0006 was open): private bytes per editor process with the Default package and with the 150 synthetic classes of MS-0033 (`tools/measure_r3.py`), five editors of flows of different sizes; editors are not in the budget (E0040), the numbers are recorded; the background processes are measured again with editors open (they must not grow).
4. **Robustness:** an editor that hangs or is killed harms no other editor and no running flow; after a restart of the engine every open editor shows the current state (REQ-ROB-040, REQ-EDT-010); the evidence from the tests of WI-0088.
5. **Manual check** (new section in `doc/MANUAL-CHECKS.md` with VS Code tasks): the owner opens his imported v1 flows, checks the look (E0088), zoom and move, tooltip, live states while a flow runs, the tray icon and menu, at 100 % and 225 % and moving the window between two screens if available; and runs the `gui` tests of S0005.
6. **Documents:** REQUIREMENTS (every requirement of S0005 with `v2`, `Plan`, `Evidence`), PROTOCOL, ARCHITECTURE 2.1, 3, 8, 10, MIGRATION, MANUAL-CHECKS, `.vscode/tasks.json`; `python tools/doc_index.py --check`.
7. **Retrospective:** what was hard (HOW-TO entries on GDI+ and drawing), what S0006 needs from the geometry and the model.
8. **Runs:** serial, parallel, `-m stress`, foundation and slow green.

## Acceptance criteria

- Every point of the S0005 acceptance has its evidence; the owner closed the manual check.

## Not part of this

Detailing S0006 (own session with the owner).
