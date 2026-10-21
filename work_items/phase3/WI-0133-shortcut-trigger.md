# WI-0133 Shortcut trigger and the flow commands of the command line

Size: M · Depends on: WI-0120, WI-0123 (corpus "File link test") · Blocks: WI-0135

## Goal

A trigger creates a shortcut file that starts its flow; the shortcut starts AutoHotFlow with a command, a second instance passes the command to the running one, and the engine starts the flow at that trigger. Requirements: REQ-TRG-240, REQ-DST-040 (the commands for flows), REQ-TRG-200 (start through the command line).

## Classes

| Class | Mode | Note |
|---|---|---|
| `Trigger_Shortcut` | trigger | the path (default on the desktop, `%A_Desktop%`), removed on disable (`RemoveShortcutOnDisabling`) |

## Read first

The common part of the element packages (README S0008); `doc/PROTOCOL.md` 4.1 (`cmd.app.command`, the second start), 4.6 (`cmd.storage.startup.check`: the shortcut of the start with Windows); `src/supervisor/SupervisorCommand.ahk`; the code of the start with Windows (WI-0079: how the command of AutoHotFlow is built); `tests/fault/test_second_start.py`; `doc/CONVENTIONS.md` 3 (rule `file-io`); v1: `Triggers/Shortcut.ahk` (`AHFCommand "Trigger|<flow>|<element>"`).

## Tasks

1. **Docs first:** PROTOCOL 4.1 gets the command that starts a flow at a trigger (its syntax on the command line and in `argv`, its answer, what happens when the flow or the trigger does not exist or the flow is disabled), and the way the supervisor hands it to the engine.
2. **Command:** the supervisor accepts it from a second instance and from the first start (AutoHotFlow not yet running: start, then run the flow when the engine is ready); the engine starts the flow at the trigger (`TriggerVariables` with empty data). A shortcut of a disabled trigger does nothing and logs why (as v1, check its help).
3. **The trigger:** creates the shortcut when armed, removes it when disarmed if the option says so. The trigger host must not access files (rule `file-io`): choose a justified exception (`; arch-ok:`) or a request to a role that may (storage, as for the startup shortcut), and write the choice into the class header.
4. **The class** with the common tasks (README S0008).
5. **Tests:** the shortcut is created in a temporary folder of the test (never the desktop); running its command starts the flow in the test session (the second-start path); removal on disable; a missing flow or trigger is answered and logged.
6. **Corpus:** "File link test" (`Flow 74366368`) on a copy with the shortcuts in a temporary folder (fix list, MIGRATION ID).

## Acceptance criteria

Those of every element package (README S0008); PROTOCOL 4.1 and REQ-DST-040 are updated.

## Not part of this

Other commands of the command line (export, import, ...); the target of the compiled program (S0009: the command is built in one place, so S0009 changes only that place).
