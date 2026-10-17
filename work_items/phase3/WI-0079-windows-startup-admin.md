# WI-0079 Start with Windows, run as administrator

Size: M · Depends on: WI-0072, WI-0077 · Blocks: WI-0082

## Goal

The settings "Start with Windows" and "Run as administrator" work (E0070, E0073). Start with Windows is a shortcut in the startup folder of the user with `--windows-startup`; such a start shows only the tray icon. Run as administrator restarts AutoHotFlow elevated; all processes of the session then run elevated. Both are checked by hand. Requirements: REQ-SET-030, REQ-SET-040, REQ-TRG-220 (start context).

## Read first

As WI-0077, plus E0070, E0073; `doc/ARCHITECTURE.md` 6.1 and 6.3 (start and exit; a restart means a clean exit and a new start); `src/supervisor/Supervisor.ahk` (second start, `cmd.app.command`), `src/supervisor/ChildLauncher.ahk`; `src/core/PipeNames.ahk` (the pipe DACL of F-0017: does it allow an elevated client?); v1 `Global_Settings.ahk` (autostart shortcut, `runAsAdmin`), and how v1 restarts itself elevated; AHK v2 docs `lib/FileCreateShortcut.htm`, `lib/Run.htm` (`*RunAs`), `Variables.htm#IsAdmin`.

## Tasks

1. **Docs first:** ARCHITECTURE 6.1 (start with Windows, elevated restart), PROTOCOL (storage creates and removes the shortcut, or the supervisor; decide by D0007: storage owns files), MIGRATION if the shortcut differs from v1.
2. **Start with Windows:** switching the setting on creates the shortcut (target: the program with `--windows-startup`, the working directory, the icon); off removes it; at start the supervisor checks that a shortcut that exists matches (a moved program) and repairs it. A start with `--windows-startup` starts no manager (E0064).
3. **Run as administrator:** switching it on asks whether to restart now; the restart is the clean exit plus a new start with `*RunAs`, which keeps `--data` and the other options; at a start without elevation and the setting on, the supervisor restarts itself elevated before it starts any child. If the user refuses the UAC question, AutoHotFlow runs without elevation and tells it (notice). Check that every child is elevated and that the pipes and wake-up messages work (UIPI).
4. **Tests:** the shortcut with a test startup folder (an option or an environment variable for the folder, never the real one in a test): created, removed, repaired; the start with `--windows-startup` starts no manager. The elevation by a manual check only.
5. **Manual check** in `doc/MANUAL-CHECKS.md` with VS Code tasks: logon with the setting on (only the icon, the start-up trigger sees "Windows"), the elevated restart (UAC question, every process elevated in the Task Manager, a flow controls an elevated window), refusing the UAC question, both together (the question at logon, E0070).

## Acceptance criteria

- The tests of task 4 are green; the manual check is written; the owner has run it (or it is listed for WI-0082).

## Not part of this

A start as administrator without the question (REQ-SET-080, `later`).
