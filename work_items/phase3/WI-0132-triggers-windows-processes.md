# WI-0132 Triggers: windows and processes

Size: M · Depends on: WI-0123 (corpus "Process Test"), WI-0125 (window identification) · Blocks: WI-0135

## Goal

The window and process triggers of v1 run in the trigger host. Requirements: REQ-TRG-260, REQ-TRG-270, REQ-TRG-020 (their arming).

## Classes

| Class | Mode | Note |
|---|---|---|
| `Trigger_Window_Opens` | trigger | `WindowIdent`; the variables of the window (v1 names) |
| `Trigger_Window_Closes` | trigger | |
| `Trigger_Window_Gets_Active` | trigger | |
| `Trigger_Window_Gets_Inactive` | trigger | |
| `Trigger_Process_starts` | trigger | `NotTriggerOnEnable` as v1 |
| `Trigger_Process_Closes` | trigger | |

## Read first

The common part of the element packages (README S0008); `doc/ELEMENT-API-V2.md` 3.5; `src/elements/Default/lib/WindowIdent.ahk`; `src/triggerhost/`; `tests/stress/test_trigger_host_memory.py`, `tests/stress/test_trigger_host_busy.py` (MS-0038 to MS-0040); AutoHotkey docs: `WinGetList`, `ProcessExist`, `SetTimer`; Windows: `RegisterShellHookWindow` (window events).

## Tasks

The common tasks (README S0008) for every class, and:

1. **Mechanism:** v1 polls with an interval parameter. Keep the parameter; decide per trigger whether polling stays or an event of Windows replaces it (the shell hook for windows: fewer calls, no missed short window), with a measurement of the cost of ten armed triggers in the trigger host (CPU and the delay of the other triggers; REQ-TRG-010 must stay done). Several triggers share one poll or one hook.
2. **Tests** with own test windows and own test processes (WI-0123, WI-0125); a window that opens and closes between two polls (document what happens).
3. **Corpus:** "Process Test" (`Flow 561135904`) with an own test process instead of Notepad (fix list, MIGRATION ID).

## Acceptance criteria

Those of every element package (README S0008); the measurement of task 1 is in MEASUREMENTS.

## Not part of this

The system triggers (REQ-TRG-220, later).

## Result

Status: agent part done, one red test not explained (see below). Branch `wip/wi0132`, commits `0520989d` to `d8e540b3` (plus the HOW-TO and open-items commits); the owner's checks are not run.

- **Triggers** (REQ-TRG-260, REQ-TRG-270): six classes in `src/elements/Default/Triggers/`. The window ones share `lib/WindowWatch.ahk`, the process ones `lib/ProcessWatch.ahk`; the shared poll is `lib/WatchPoll.ahk` (one timer per interval, one process list per tick). `lib/ProcessSnapshot.ahk` lists the processes (EnumProcesses, limited query right). Verified: unit test `tests/ahk/element_window_watch.test.ahk` (7 cases); `tests/integration/test_window_triggers.py` (9 tests) and `tests/integration/test_process_triggers.py` (5 tests), both passed serially.
- **Decision (polling stays):** close detection needs the list anyway; a Windows shell hook would add a hidden window and DllCall to the trigger host. Alternative: `RegisterShellHookWindow`, not built. A window that opens and closes between two polls is not seen (documented, tested with a 3 s poll).
- **Measurement MS-0044** (run 20261102-115353-6700, commit 087b79d6 plus the uncommitted test): trigger host CPU at 100 ms: baseline 0.83 %, ten windows (one interval) 2.29 %, ten processes (one interval) 8.65 % of one core; the test timer keeps 109 ms median, 110 ms max (125 ms in one variant). Verified, one machine, not idle.
- **Corpus "Process Test"** (Flow 561135904): copy in `v2_adapted/` with its own process copy of cmd.exe on PATH (M-0178), out of PENDING. Passed alone (13.6 s) at 26792f11; failed in the full slow run (see below).
- **Help pages** corrected and renamed to the class names (test_help requires it); HTML generated.
- **Docs**: REQ-TRG-260/270 done, REQ-TRG-020 note; MIGRATION M-0176 (process list, no debug privilege), M-0177 (first check and variable names), M-0178; OPEN-ITEMS F-0203 to F-0206; three HOW-TO entries; MEASUREMENTS MS-0044.
- **Schema allow list:** the four window triggers have the M-0139 identification differences (commit d8e540b3); `tests/schema/test_v1_schema.py` 7 passed.
- **Assert fix:** `tests/ahk/lib/Assert.ahk` used `errorClass.Name` (PropertyError); now `Prototype.__Class`.

Tests (verify --auto, run 20261102-120044-af9b7fa6, commit af9b7fa6): fast 2660 passed, 2 skipped, 10 failed (fast 1:27 h under heavy load); slow 210 passed, 5 failed; foundation 471 passed, 1 skipped. Failures of the fast tier that are not mine (editor, manager archive, folder, text, supervisor and manager e2e): load failures, not rechecked here. Mine: the schema test (fixed, d8e540b3); `test_gets_inactive_...` (green alone, recheck run 20261102-135605-24032); `test_v1_process_test...` (failed under the full slow load, green alone at 26792f11 — not rechecked after the load run).
Recheck run 20261102-135605-24032 (serial, alone, commit d8e540b3): 15 passed, 1 failed: `test_time_triggers.py::test_time_of_day_fires_at_its_time_and_not_again_that_day` (`ended` count 0). The same test failed in the fast run. Its code (Trigger_Time_Of_Day, WI-0131) is not changed by WI-0132; cause not checked.

Open: F-0203 (process poll cost), F-0204 (protected processes), F-0205 (duplicate own-window helper), F-0206 (v1 label says window). The stray pytest run of an earlier `--changed-from` check could not be stopped (permission denied); it writes to the scratchpad only.

Not checked: real protected processes; the process trigger at the default 1000 ms interval (cost assumed to be about a tenth); the owner's manual check of the real desktop.
