# WI-0067 Acceptance S0003

Size: M · Depends on: WI-0060 to WI-0066 · Blocks: S0004

## Goal

S0003 is demonstrably finished and the documents match the code. Afterwards S0004 is detailed.

## Tasks

1. **The v1 flow "Trigger test" (E0061):** an adapted copy of `tests/data/flows/v1_examples/Flow 884290977.json` in `tests/data/flows/v2_adapted/` without `Action_Speech_output` (element `element0000000174`; the connection is kept through an `Action_Do_nothing`, or the element is removed; whichever keeps the paths of the flow), entered in `FIX_LIST` with a MIGRATION ID. The test prepares `FlowState.json` so that the flow is enabled at the start of the session (its `Trigger_Start_up`), answers the debug dialogs by the dialog seam and checks the end state (`static_testSuccess`). The table `PENDING` drops the flow.
2. **REQ-TRG-010 measurement:** the engine is kept busy (an inline element that blocks it for some seconds, a test element) while a `Trigger_TestTimer` and a hotkey on an unassigned key fire: the host-side times of the events stay on schedule, the hook is not removed by Windows (the hotkey still fires afterwards), the engine processes the events after the busy time. Result in `doc/MEASUREMENTS.md`.
3. **Memory** of the background processes with the real trigger host and some armed triggers (REQ-PRF-030, E0040). `doc/MEASUREMENTS.md`.
4. **Checks:** the acceptance of S0003 in the README, point by point, with run IDs.
5. **Acceptance runs:** serial, parallel, `-m stress`, foundation, slow (`tools/verify.py`).
6. **Manual check for the owner** (`doc/MANUAL-CHECKS.md`, VS Code tasks): the `gui` tests of WI-0064; a real start of AutoHotFlow with an enabled flow with a hotkey and a periodic timer in the v2 data folder; the start with `--windows-startup`.
7. **Documents:** PROTOCOL 4.2, 4.4, 4.6; ARCHITECTURE 3, 4, 6, 7, 8; ELEMENT-API 2, 3, 5 and 8; MIGRATION; TEST-STRATEGY; MEASUREMENTS; HOW-TO; `AGENTS.md` (status); `work_items/phase3/STATUS.md`; the requirements of the step.
8. **Retrospective:** what did the estimate miss; what belongs in the scope of S0004. Briefly in the result.

## Acceptance criteria

All points of the acceptance of S0003 are met, or an open point is recorded in `doc/OPEN-ITEMS.md` with the agreement of the project owner.
