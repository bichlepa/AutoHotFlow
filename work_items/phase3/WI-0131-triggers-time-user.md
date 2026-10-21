# WI-0131 Triggers: time of day, user idle time, clipboard, hotstring

Size: M · Depends on: WI-0117 (idle time) · Blocks: WI-0135

## Goal

Four more triggers of v1 run in the trigger host. The idle time comes through `SystemOps` (E0103), so the tests do not wait for the real user to be idle. Requirements: REQ-TRG-210 (time of day), REQ-TRG-250, REQ-TRG-230 (hotstring), REQ-TRG-020 (their arming).

## Classes

| Class | Mode | Note |
|---|---|---|
| `Trigger_Time_Of_Day` | trigger | times and week days (the `weekdays` field); a one-shot timer to the next time, set again after each fire; a change of the clock or a resume from standby must not lose a time (check against `A_Now` when the timer fires) |
| `Trigger_User_Idle_Time` | trigger | `A_TimeIdle` or `A_TimeIdlePhysical` through `SystemOps`; fires once per idle period (as v1) |
| `Trigger_Clipboard_Changes` | trigger | `OnClipboardChange` in the trigger host |
| `Trigger_Hotstring` | trigger | `Hotstring()` with the options of v1; the window conditions of `WindowIdent` as the hotkey trigger; the help names v1 key and option names (WI-0112 list) |

## Read first

The common part of the element packages (README S0008); `doc/ELEMENT-API-V2.md` 3.5 and 5 (`Trigger_Hotkey`); `src/elements/Default/Triggers/Trigger_Periodic_Timer.ahk`, `Trigger_Hotkey.ahk`; `src/triggerhost/`; `tests/integration/test_time_triggers.py`, `tests/integration/test_hotkey_input.py`; AutoHotkey docs: `Hotstring`, `OnClipboardChange`, `A_TimeIdle`, `SetTimer`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **Time in the tests:** the time of day trigger is tested with a time a few seconds ahead and with week days; no test waits for minutes.
2. **Hotstring with real input:** typed with `SendInput` under the input lock, as the hotkey input tests do, with characters that do nothing in the active window; combinations that need a real editor window are `gui` tests.
3. **Clipboard:** real, in the xdist group `clipboard`, the user's clipboard saved and restored.
4. **Corpus:** "User idle test" (`Flow 1333431302`) with an idle time of the test provider (the four units of the flow).

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

The session lock trigger and the other `later` rows of REQ-TRG-220 and REQ-TRG-250.
