# WI-0123 Programs and processes, clipboard, power and session

Size: M · Depends on: WI-0117 · Blocks: WI-0125 (corpus "file test"), WI-0132, WI-0133, WI-0135

## Goal

The elements that run programs, end processes, read and write the clipboard, and shut down, restart or lock the computer exist in v2. Power and session go through `SystemOps` (E0103). Requirements: REQ-ELM-390, REQ-ELM-290, REQ-ELM-400.

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Run` | worker | `Run` with the run modes of v1 (normal, max, min, hide) and the working folder of the flow; the help has `%name%` examples (WI-0112 list) |
| `Action_Kill_Process` | worker | `ProcessClose` by name or PID |
| `Action_Set_Process_Priority` | worker | |
| `Condition_Process_Is_Running` | worker | |
| `Action_Get_Clipboard` | worker | text; the formats of v1 |
| `Action_Set_Clipboard` | worker | |
| `Action_Lock_Computer` | worker | `SystemOps` |
| `Action_Log_Off` | worker | `SystemOps` |
| `Action_Shutdown` | worker | `SystemOps`, the force option of v1 |
| `Action_Reboot_Computer` | worker | `SystemOps` |
| `Action_Hibernate_Computer` | worker | `SystemOps` |
| `Action_Suspend_Computer` | worker | `SystemOps` |

## Read first

The common part of the element packages (README S0008); `tests/e2e/test_editor_clipboard.py` (the real clipboard in the xdist group `clipboard`); AutoHotkey docs: `Run`, `ProcessClose`, `ProcessExist`, `ProcessSetPriority`, `A_Clipboard`, `ClipWait`, `Shutdown`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **Processes in the tests:** an own test process (a small AutoHotkey script of the test helpers with a unique name, or a copy of a harmless program in the temporary folder); never a process the user may have open (no `notepad.exe` by name).
2. **Clipboard:** real clipboard tests in the xdist group `clipboard`; the test saves and restores the user's clipboard.
3. **Power and session:** the test provider records the call and its flags; nothing is shut down.

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

Running a program and reading its output (REQ-ELM-390 `later` rows).
