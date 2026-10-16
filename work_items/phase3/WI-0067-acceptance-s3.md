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

## Result (agent part, 2026-10-17)

The point-by-point acceptance is in this section, not in the README (the work item allows either). Code state of the runs: commit `8e7d403`; afterwards only documents and the requirement evidence changed (`0852566`).

Commits (`7eadc35..0852566`): `752097a` (v1 Trigger test copy, M-0077), `ebd1170` (measurements MS-0038 and MS-0039, the test element and the stress tests), `5f12cb9` (manual checks 4 and 5, the flow `triggers_check`), `b13fa2c` and `0852566` (requirement fields), `11f8e3f` (TEST-STRATEGY 8b), `84a2c39` and `f92e076` (ARCHITECTURE 8, ELEMENT-API 8), `81e6064` (AGENTS status), `ee8c4c4` (hotkey arming test without keys), `8e7d403` (flaky state-file test fixed).

### Acceptance of S0003, criterion by criterion

| # | Criterion (README, S0003) | Evidence | Status |
|---|---|---|---|
| 1 | Triggers of enabled flows are active after the start, after a restart of the engine and of the trigger host; the state survives a restart; a v1 flow file loads disabled (REQ-EXE-070, REQ-TRG-020, REQ-ROB-040, E0058) | `tests/integration/test_trigger_arming.py` (10 tests, among them the restarts of the host and of the engine), `test_trigger_state.py` (survives a session restart; v1 file loads disabled), `test_engine.py::test_the_switched_state_survives_a_restart_of_the_engine`, `test_hotkey_arming.py` (hotkey re-armed after a host restart). Runs 20261017-005641-8e7d4037 and 20261017-005838-8e7d4037 (fast tier, parallel and serial) | met (verified) |
| 2 | Every trigger of S0003 has e2e tests; the hotkey also with real input (E0059); the gui tests are run by the owner | e2e without keys: Manual (`test_corpus.py`, the Trigger test), Periodic_Timer and Start_up (`test_time_triggers.py`), Hotkey (`test_hotkey_arming.py`, new). Real input: no test in the repository (owner decision, pending P1). The gui tests of WI-0064: none in the repository | **pending owner** for the real-input part and the gui tests; the rest met |
| 3 | An error of one trigger stops neither the others nor the host; the host keeps reacting while the engine is busy (REQ-TRG-010) | `test_trigger_arming.py` (a refused enable and a parameter that cannot be evaluated: the others stay armed), `test_triggerhost.py` (failing enable, throwing disable, throwing callback). Busy engine: MS-0038 (27 to 28 fires during a 3 s block, none lost). Run 20261017-005641-8e7d4037 | met without keys (verified); **pending owner** for the hotkey part of the busy measurement |
| 4 | The adapted v1 "Trigger test" runs headless and green (E0061); "variable test" runs as saved again (M-0069 back) | `test_corpus.py::test_v1_trigger_test_runs_green_on_the_adapted_copy` (end state `static_testSuccess` = 1; one expected exception, the flow's own disabled trigger, caught by its exception connection as in v1); `test_v1_variable_test_runs_green_as_saved`. Run 20261017-010701-8e7d4037 (slow tier, 150 passed) | met (verified) |
| 5 | The guard stops a runaway flow and refuses starts over the limits (REQ-EXE-170), with the defaults set by WI-0066 | `test_runaway.py` (three tests; the endless loop is also in the slow tier), defaults from MS-0036 and MS-0037. Runs 20261017-005641-8e7d4037 and 20261017-010701-8e7d4037 | met (verified); the notice in the manager and the global defaults are S0004 |
| 6 | The memory of the background processes is measured again with the real trigger host (REQ-PRF-030, E0040) | MS-0039: supervisor, storage, engine (with a warm worker), manager stub and trigger host, five periodic timers, a start-up and a manual trigger armed. 4 runs: 46.3 to 46.9 MB private bytes after 30 s (45.7 MB after 2 s), 110 MB working set; below the 100 MB budget with one worker | met (verified, one machine); editors and the real manager are not in it (S0004, S0006) |
| 7 | Serial, parallel, `-m stress`, foundation and slow runs are green | at commit `8e7d403`: fast parallel 20261017-005641-8e7d4037 (1226 passed, 1 skipped); fast serial 20261017-005838-8e7d4037 (1226 passed, 1 skipped, 643 deselected); foundation 20261017-010456-8e7d4037 (466 passed, 1 skipped); slow, not gui 20261017-010701-8e7d4037 (150 passed); stress (`test_big_flows.py`, `test_start_stop_storm.py`, serial) 20261017-011019-8e7d4037 (3 passed, 3 deselected: the smoke variants are not stress) | met (verified). The gui tier and the input tests were not run (agents do not run them) |

### Pending owner (not decided by the agents)

- **P1. How keys are delivered in tests** (`NEEDS-ATTENTION.md`). It blocks the real-input test of `Trigger_Hotkey` (criterion 2), the gui tests of WI-0064 (`doc/MANUAL-CHECKS.md` section 6), and the hotkey part of REQ-TRG-010 (a hotkey on an unassigned key during the engine block; criterion 3).
- **P2. Manual checks on the owner's machine:** `doc/MANUAL-CHECKS.md` section 4 (real start with the enabled flow `triggers_check`: periodic timer, hotkey, tooltips) and section 5 (the same with `--windows-startup`). The tasks are "Start: manual check 4" and "Start: manual check 5". The work item asks for the v2 data folder; the agents used the manual-check folder, as the other checks do (see decisions).
- **P3. Open points of the acceptance:** the acceptance rule allows an open point only in `doc/OPEN-ITEMS.md` with the owner's agreement. None is written: criteria 2 and 3 stay open until P1 is decided. The owner decides whether they become OPEN-ITEMS entries.

### Measurements (tasks 2 and 3)

- MS-0038 (REQ-TRG-010, no keys): host gap 109 ms median inside and outside the block; during the 3 s block the engine processed 0 events, the first queued event 31 to 32 ms after it, the largest lag 2.9 to 3.0 s; no event lost. Load: system CPU 10 to 13 % before, 7 to 9 % after (the machine was not idle). The 9 ms per tick above 100 ms come from the one-shot timer chain of the test element `Trigger_TestTimer`; the product's periodic timer uses `SetTimer` (not checked by a measurement).
- MS-0039 (REQ-PRF-030): see criterion 6. Load: system CPU 9 to 13 %.
- Both: 4 runs each, serial, in the stress tier (run alone by the admission of WI-0059), on the same machine as MS-0035.

### Decisions taken by the implementer

- The v1 "Trigger test" copy replaces `Action_Speech_output` by `Action_Do_nothing` with the same ID and connection (M-0077). The flow is enabled through `FlowStates` (its start-up trigger).
- `Trigger_Hotkey` is registered as complete (WI-0064), so it left the PENDING table of the hotkey test flow.
- A test element `Action_TestBlockInline` (inline, blocks on purpose) and the host time `A_TestTick` in `Trigger_TestTimer` (test code only).
- A hotkey arming test without keys (`test_hotkey_arming.py`): an unassigned key registers without input.
- The manual checks 4 and 5 use the manual-check data folder with a companion state file (`triggers_check.state.json`, copied to `FlowStates` by `tools/manual_check.py`). The work item named the v2 data folder; this keeps the default folder untouched, as sections 1 to 3 of the checks do. The owner can copy the two files into the default folder instead.
- The hotkey of the manual flow is `Ctrl+Alt+Shift+F12`, not blocked (`BlockKey` 0).

### Findings and incidents

- **Flaky test fixed (not a product bug):** `test_engine.py::test_the_switched_state_survives_a_restart_of_the_engine` read the state file during the second of two writes of the stub storage. Failure in run 20261017-005318-81e6064a (parallel fast tier); fixed in `8e7d403`; the test passed three times in a row afterwards. No OPEN-ITEMS entry (test race, fixed).
- **Own mistake, fixed in the same series:** `DOC-INDEX.md` was not committed with the TEST-STRATEGY change (`11f8e3f`); `test_doc_index` failed in runs 20261017-003823-11f8e3f8 and 20261017-004019-11f8e3f8. Fixed by `84a2c39`; all final runs use later commits.
- **Incident:** after a run of the chain at `81e6064` had gone stale, I stopped its processes (the shell chain and the `run_suite` process of that commit, my own runs, not other agents' runs). A further process listing was refused by the permission system; I did not continue with process operations. A `git worktree` of `81e6064` may be left behind by run_suite: not checked.
- `tools/manual_check.py` has a pre-existing `SyntaxWarning` (invalid escape in the module docstring): not changed.

### Retrospective (task 8)

- **What the estimate missed:** the hotkey trigger had no end-to-end test without keys; the criterion "every trigger has e2e tests" was not met by WI-0064 alone. Added (`test_hotkey_arming.py`). The manual checks needed a flow that is enabled at the start: the tool copies the enabled state into `FlowStates` (companion file), because the manager of S0004 does not exist yet.
- **FlowBuilder class names:** the trigger classes of the test package need the qualified name `Test.Trigger_TestTimer`; only `Action_Test*` is resolved to the test package. A pitfall for later tests.
- **Timing:** the trigger host measurements are clean on this machine; the 15.6 ms clock of `A_TickCount` is enough for the schedule question, not for sub-millisecond claims.
- **For S0004:** the manager shows the enabled state and the independent triggers and enables flows (then the state-file copy of the manual checks is no longer needed); the autostart entry passes `--windows-startup`; the global defaults and the notice of a limit stop (REQ-EXE-170); the memory with the real manager (MS-0006 stays open).
- **For S0008:** the speech output and the other 12 PENDING flows; the window identification of `Trigger_Hotkey` as a shared library; `ctx.Request` for triggers only when a trigger needs it.
- **Not checked:** the hotkey with real keys; the gui tier; the Windows logon start; PROTOCOL 4.2, 4.4 and 4.6 and ARCHITECTURE 3, 4, 6 and 7 were searched for stale S0003 statements by keyword, not read section by section.
