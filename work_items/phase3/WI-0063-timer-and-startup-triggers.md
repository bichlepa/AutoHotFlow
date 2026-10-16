# WI-0063 `Trigger_Periodic_Timer` and `Trigger_Start_up`

Size: M · Depends on: WI-0062 · Blocks: WI-0067

## Goal

The two time triggers of the v1 flow "Trigger test" work in v2. Requirements: REQ-TRG-210 (row `Trigger_Periodic_Timer`), REQ-TRG-220 (row `Trigger_Start_up`).

## Read first

As WI-0052 (porting an element by hand), `doc/ELEMENT-API-V2.md` 2 and 5, the v1 classes `v1/Source_Elements/Default/Triggers/Periodic_Timer.ahk` and `Start_up.ahk`, their help texts `v1/Source_Elements/Default/help/en/Triggers/` (specification, E0035), `src/elements/Default/Triggers/Trigger_Manual.ahk` as the pattern, WI-0062 (start context).

## Tasks

1. **`Trigger_Periodic_Timer`:** parameters as v1 (`Interval`, content number, `WarnIfEmpty`; `Unit` milliseconds, seconds, minutes). `Enable` refuses an interval that is not above 0 (`ElementError` with the v1 text) and starts a `SetTimer` through the trigger context; `Disable` stops it. No minimum beyond the timer resolution; a flood is the job of the guard (WI-0066). `GenerateName` as v1.
2. **`Trigger_Start_up`:** parameter `startupType` (`AutoHotFlow`, `Windows`). `Enable` fires at once when the start context says so: `AutoHotFlow` on `ahfStartup`, `Windows` on `windowsStartup` (WI-0062). A start with Windows is also a start of AutoHotFlow (as v1: both types fire then).
3. **Tests:** smoke test (WI-0048) green with the new classes; e2e: the timer fires about every interval (`scaled()`, tolerant window), stops on disable, a bad interval gives the trigger state with the message; `Start_up` fires once at the start of a session with the flow enabled in `FlowState.json`, not after an engine or host restart, not when enabled later, the type `Windows` only with `--windows-startup`.

## Acceptance criteria

The tests of task 3 are green, serial and parallel. The language keys of both classes are found (`Lang()` gives no key text).

## Docs

`doc/MIGRATION.md` if a behaviour differs from v1, `doc/REQUIREMENTS.md` REQ-TRG-210 and REQ-TRG-220 (rows and `Evidence`), the table `PENDING` of `tests/integration/test_corpus.py` (the test keeps it equal to the registry), then `python tools/doc_index.py`.

## Not part of this

`Trigger_Time_of_Day` (S0008); the autostart entry that passes `--windows-startup` (S0004).
