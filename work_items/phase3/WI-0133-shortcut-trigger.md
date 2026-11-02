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

## Result

Commits (prefix WI-0133): storage writes the shortcut files; the trigger context gets launch data, the disarm reason and requests; the command `Trigger|<flow>|<element>` starts a flow at its trigger (supervisor, engine); the element `Trigger_Shortcut` with its tests, help page, MIGRATION M-0179 to M-0182, REQ-TRG-200, REQ-TRG-240 and REQ-DST-040; corpus "File link test" green on a test folder; OPEN-ITEMS F-9000* and F-9001*.

Tests (commit e98a3ed5 and the steps before it):
- AHK units: `storage_shortcut.test.ahk` 4 of 4 green; `element_shortcut.test.ahk` green (7 of 7 with the storage unit, 11 passed together).
- Integration `test_shortcut_trigger.py`: 8 of 8 green (serial).
- Corpus `test_corpus.py -k "file_link or pending"`: 2 of 2 green.
- Architecture and test group tests: 86 passed.
- `verify.py --auto` on e98a3ed5: red by a stalled selection run (window trigger tests, real windows; the run was killed, no history record). Serial rerun of `test_window_triggers.py`, `test_triggerhost.py`, `test_trigger_arming.py`: 24 passed, 2 failed (`test_gets_active_fires_when_the_matching_window_becomes_the_active_one`, `test_gets_inactive_fires_with_the_id_of_the_window_that_lost_the_focus`): both assert that the own window gets the focus, which this environment does not give. Not related to this work item; not checked on v2-port.

Decisions (made by the implementer):
- Shortcut file written by storage (`cmd.storage.shortcut.*`), not by the trigger host: the host must not do file I/O.
- The command line carries the program script (`--app-script`, passed by the supervisor to every role), session and data folder, so a shortcut from a test session reaches that session only. Alternative: a fixed `AutoHotFlow.ahk` path, which would break test sessions.
- A removal happens only on a switch-off or a re-arm; shutdown, engine restart and failed arming keep the file. Alternative: remove on every disarm, which would delete the shortcut at every exit.
- A switched-off trigger answers `denied` and is logged; nothing is started (v1 did the same, silently).
- A first start by a shortcut opens no manager window (as a start with Windows).
- The default path is `%A_Desktop%\AutoHotFlow shortcut.lnk` (v1: with the flow name); the path must be absolute (v1: relative allowed). Both are MIGRATION entries.

Findings: F-9000* (the shortcut file is written after the enable answer; a Run right after enabling fails, the corpus copy waits 2 s), F-9001* (a first start with `--command=debug` is ignored).

Not checked: the desktop shortcut itself (starting AutoHotFlow from a real shortcut on the desktop) is a manual check for the owner; the window-trigger focus tests above on a machine that gives focus; the full fast and slow tiers.
