# WI-0072 Tray icon and tray menu of the application (role `tray`, E0075)

Size: M · Depends on: – · Blocks: WI-0073, WI-0075, WI-0079

## Goal

The tray icon of AutoHotFlow belongs to the supervisor (E0064): it is there as long as the application runs, also while the manager is not running or has crashed. Menu "Show manager" (default entry, double click) and "Exit". The manager loses its tray icon. The supervisor can show a tray notice (used by WI-0075). Requirements: REQ-MGR-090, REQ-MGR-140, REQ-ROB-120 (manager part).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 3 (supervisor: no business logic, no file I/O, no dialogs), 6.1 (start, `--background`), 6.3 (exit); E0014, E0046, E0064 in `doc/DECISIONS.md`; `src/AutoHotFlow.ahk`, `src/supervisor/Supervisor.ahk` (`cmd.app.command`, `cmd.manager.show`, `_OnManagerShown`), `src/supervisor/Children.ahk`; `src/manager/StubManager.ahk` (`_SetupTray`); `tests/integration/test_tray.py`, `tests/integration/test_entry.py`; `doc/howto/gui-and-hotkeys.md` (tray menu entry); AHK v2 docs `lib/Menu.htm` (`A_TrayMenu`), `lib/TraySetIcon.htm`, `lib/TrayTip.htm`, `Program.htm#tray-icon`.

## Tasks

1. **Docs first:** ARCHITECTURE 3 (the tray icon is a task of the supervisor; it stays small: icon, menu, notice), 6.1 (the manager is started at the first start without `--windows-startup` or `--background`, and on demand), the E0046 text in 6.1; PROTOCOL (the supervisor shows a notice: `evt.ui.notice` to the supervisor, or a command; decide with WI-0075's needs in mind); REQ-MGR-090 and REQ-MGR-140 evidence.
2. **Icon and menu:** `src/AutoHotFlow.ahk` drops `#NoTrayIcon`, the test entry keeps the icon hidden (no test-run process shows one, E0046); `src/entry/manager.ahk` gets `#NoTrayIcon`. The AHK standard entries are removed. "Show manager": `cmd.manager.show`, or start the manager when it is not running (the path of a second start exists). "Exit": the clean exit of the application (the same as the "Exit" button). Tooltip "AutoHotFlow".
3. **Texts of the menu:** through `Lang`; a change of the language (WI-0077/WI-0078) sets the entries again. The language files are read by the supervisor at start and at a change: this is a small file read of the program folder (not the data folder); mark it `; arch-ok:` with the reason, or let the engine send the texts; choose and document.
4. **Manager after a crash:** stays not restarted automatically; the icon brings it back. The manager is not started with `--windows-startup` or `--background` (implement `--background` as named in ARCHITECTURE 6.1, or drop it from the document; choose).
5. **Does an open menu block? (E0064, first, before task 2):** the owner's test (2026-10-17) only shows that an open tray menu did not block an **idle** stub manager. That is not enough for the hub. The assumption "an open menu blocks nothing" must be checked:
   - **Docs again:** read the AHK v2 docs completely on this point (`misc/Threads.htm`, `lib/Menu.htm`, `Program.htm#tray-icon`, `lib/SetTimer.htm`, `lib/OnMessage.htm`, `lib/Critical.htm`, `lib/Thread.htm`, `lib/Persistent.htm`, and whatever they link), and write down what they say about a menu that opens **while a thread is running** (does the running thread pause until the menu closes?), about timers and posted messages while a menu is open, and about the difference between a menu that is open and one the user navigates.
   - **Cases to test**, each with a test role or a small script under `ahkrun.py` (the menu opened by the tray message to the script's window, `AHK_NOTIFYICON` with right button up, closed with Esc after 15 s): (a) the menu opened while the script is idle; (b) the menu opened while a timer thread runs (a thread of several seconds): does that thread go on, and do later timer ticks run; (c) the menu opened while the wake handler is busy with a flood of frames (the hub under load); (d) the user moves through the items with the mouse or the keyboard while the menu is open; (e) a context menu of a `Gui` (the manager's tree, WI-0074) in the same cases. Measured: the progress of the running thread, the ticks of a timer, the round trip of `sys.ping` or `cmd.engine.snapshot` through the hub, and whether a child is judged hung.
   - **If a case cannot be automated** (for example the navigation with the mouse), the owner checks it by hand: a manual check step with a VS Code task that starts the case and shows the measured values afterwards.
   - **Result** in `doc/MEASUREMENTS.md` and in the HOW-TO entry about tray menus (its status changes from "verified by hand, idle only" to what was measured). If any case blocks the hub or a running thread: stop and report to the owner with the options (the menu in a small own process; `Critical` on the threads of the hub so that a menu opens only between them; showing the menu by own code after a `sys.busy` report); E0064 then needs a second look. The result also tells WI-0073 and WI-0074 whether the menus of the manager need a guard.
6. **Tests:** the existing tray tests moved to the supervisor (the menu entries, exit through the menu, no standard entries); "Show manager" starts a manager that is not running; a crashed manager is started again by "Show manager"; the icon is there with no manager at all (`--start` without manager).

## Acceptance criteria

- The tests of task 6 are green, foundation tier green (the change touches `src/supervisor/` and `src/AutoHotFlow.ahk`).
- The docs review and every case of task 5 are recorded (measured, or checked by the owner by hand); no case blocks the hub or a running thread, or the owner has decided after the report.

## Not part of this

The notices themselves (WI-0075), the language setting (WI-0077), the editor icons (S0005).

## Changed design (E0075, owner, 2026-10-17)

The measurement of task 5 (`doc/MEASUREMENTS.md`, "Open menus in a running process") showed that an open menu stops the timers and usually a running thread of its process. The owner decided: the icon and the menu run in an own small process, the new role `tray` (name chosen by the implementer), not in the supervisor and not in the manager. Tasks 1 to 3 and 6 apply to that role instead of the supervisor; task 4 is partly out of scope (see below).

## Result

- **Role `tray`:** `src/tray/Tray.ahk`, entries `src/entry/tray.ahk` and `tests/integration/helpers/entry/tray.ahk`. Icon (tooltip "AutoHotFlow"), menu "Show manager" (default entry) and "Exit" with the texts from `Lang` (`Show_Manager`, `Exit_#verb`); the standard AutoHotkey entries are removed. The handlers send `cmd.app.command {argv: []}` and `cmd.app.exit` to the supervisor (no new message types for the product); `--headless` hides the icon and adds the test driver `cmd.test.command {item}` (PROTOCOL 4.10).
- **Supervisor:** starts the role unless `--no-tray` (`--tray` forces it; `Supervisor.TrayDefault` is false in the test entry), restarts it (`Children.AUTO_RESTART`), ends it first (rank 0). The role ends with the supervisor by the orphan guard.
- **Manager:** no tray menu and `#NoTrayIcon` in its entry. Every entry script now carries `#NoTrayIcon`; `Tray.Start` shows the icon.
- **Tests:** `tests/fault/test_tray_role.py` (start, restart after a kill, exit from the menu, show manager with and without a running manager, a crashed manager opened again, bad item; gui: the real icon, the menu opened with the tray message and held 8 s, no hang, Esc closes it), `tests/integration/test_tray.py` (static), `tests/integration/test_entry.py`, `tests/test_element_includes.py`. VS Code task "Test: tray icon and menu (gui ...)".
- **Not done / left for later:** the menu texts are read once at start (`_BuildMenu` can be called again; the trigger is the language setting, WI-0077/WI-0078). `--background` and `--windows-startup` do not start the manager yet because the product start does not start the manager at all before WI-0073 (task 4). Tray notices: WI-0075.
