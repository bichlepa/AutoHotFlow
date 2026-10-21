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
