# Manual checks (Handprüfung)

The automated tests do not cover the checks in this document. The project owner runs them by hand. Each step states the expected result. A step passes only if the expected result is seen. A dialog box (window class `#32770`) at any point is a failure.

The checks cover two interfaces: the manager (section 1) and the debug window (section 2). Use the "Result" template at the end to record a run.

Where a step starts the application, the VS Code task is named by its label in `.vscode/tasks.json`, followed by the same call for a terminal.

**Data folder and session.** The checks run with `tools/manual_check.py` in their own data folder `%TEMP%\ahf_manual_check` and their own session `manual`. The default folder `%APPDATA%\AutoHotFlow v2` stays untouched, and an instance that runs for something else (session `main`) is not met. The tool starts `AutoHotkey64.exe` without a timeout and without a dialog guard, waits until the application ends, and then prints `AutoHotFlow ended with exit code <n>` in the task terminal. The logs and reports of a check are in `%TEMP%\ahf_manual_check\Log` and `...\Reports`. A fresh folder (VS Code task "Setup: fresh data folder for the manual checks (manual_check.py prepare)", or `python tools/manual_check.py prepare`) holds only `Flows\skeleton.json`, a copy of `tests/data/skeleton_flow.json`.

## 1. Manager (GUI)

Test on the manager window (REQ-MGR-010 to REQ-MGR-050, REQ-MIG-060, REQ-USE-030, REQ-LNG-010). Not automated: the tests use the headless manager (`--headless`), and the window and its drag and drop are only checked by the gui tier, which agents do not run. Written after block A of S0004 (WI-0076).

**Start, part A (the tree and the operations).** VS Code task "Start: manual check 1, manager in a fresh data folder (manual_check.py)", or in a terminal:
`python tools/manual_check.py start --fresh -- --start=storage,engine,triggerhost,manager,debug`

The start prepares a fresh data folder first (see above), so no preparation by hand is needed. It also starts the debug window.

**Start, part B (the import from v1).** VS Code task "Setup: copy of the v1 data folder for the import check (manual_check.py copy-v1)" first: it copies `%APPDATA%\AutoHotFlow` (the v1 data folder, only read) to `%TEMP%\ahf_manual_check_v1`. Then the same start as in part A (the task "Start: manual check 1 ..."). The import in part B takes the copy, not the original; the folder dialog (choice "Import from v1" of the button "Import and export") opens at `%APPDATA%\AutoHotFlow`, so the copy has to be chosen by hand.

### Steps, part A

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the application (part A). | The manager window opens with the tree and the buttons. No dialog. The debug window "AutoHotFlow - debug" also opens. | |
| 2 | Look at the tree and the status line. | The flow `skeleton` is listed in the uncategorized group. The status line shows the connection `ready`, `epoch` and `seq`. | |
| 3 | Click New flow, then New category. Type a name for the category (for example `Tests`). | A new flow `New flow 1` appears in the category of the selection. The category appears. A second name equal to an existing one (ignoring case) is refused in the dialog, before anything is sent. | |
| 4 | Drag `skeleton` onto the category `Tests`, then drag the category header onto the top of the list. | The flow moves into the category, the category moves. The new order stays after a restart of the application. | |
| 5 | Select `skeleton`, Ctrl-click `New flow 1`, then click Enable. | Both flows are enabled (the state mark changes). Disable works the same way. | |
| 6 | Enable a flow whose independent trigger is enabled, then disable it again. | The question about the independent triggers appears (Yes disables them too, No changes nothing). The dialog says that only the editor can undo this. | |
| 7 | Click Duplicate on `skeleton`. Then Rename the copy to a name that the other flow has (ignoring case). | The copy is named `skeleton 2`. The rename with a taken name is refused in the dialog with the reason. | |
| 8 | Click Delete on the copy and answer No, then Delete again and answer Yes. | With No the flow stays. With Yes it is removed for good. | |
| 9 | Click Run on `skeleton`, then Stop while it runs. | The state mark shows running and then stopped. The button label changes between Run and Stop. | |
| 10 | Click Notices. | The list of notices opens; with no errors it says that there are none. | |
| 11 | Click Show log, then close it with the X. | The log window opens and shows the entries of the session. Closing it hides it. | |
| 12 | Right-click the tray icon (the only icon of the application). | The menu has two entries: `Show manager` (the default, a double click does the same) and `Exit` (German: `Beenden`). `Show manager` brings the window to the front; `Exit` ends the application with exit code 0 (the task terminal prints it). Source: `src/tray/Tray.ahk`, not yet checked by hand. | |
| 13 | Watch for dialogs during the whole check. | No dialog (window class `#32770`) appears, except the questions of the steps above. | |

### Steps, part B (the import from v1)

| # | Step | Expected result | Result |
|---|---|---|---|
| 14 | Start part B. Click "Import and export", then choose "Import from v1" (the third item). | A folder dialog opens. Choose `%TEMP%\ahf_manual_check_v1` (the copy). The window stays usable while the dialog is open. | |
| 15 | Wait for the import to end. | A report window "Import from v1 - report" opens. It lists the flows: created, skipped or failed with the reason, and the MIGRATION places (`MIGRATION M-...`). The text can be selected and copied (Ctrl+A, Ctrl+C). | |
| 16 | In the report, look at the flows of the folder. | Every flow of the copy's `Saved Flows` is listed, none from `demo flows`. The broken file (a file that is not valid JSON, if the copy has one) is listed as failed; the others are imported. | |
| 17 | Look at the imported flows in the tree. | They are listed under their names, all disabled (no state mark of a running or enabled flow). | |
| 18 | Start the import a second time into the same window (Import and export, then Import from v1, same folder). | A question asks whether to import the flows that exist already as copies. No: they are skipped (reason: a flow with this ID exists already). Yes: they come as copies with a number in the name (`<name> 2`). | |
| 19 | Look at the variables of the report. | Global variables that v2 has keep their value and are listed as kept. Static variables of an imported flow are listed as taken over. | |
| 20 | When the copy has an autostart shortcut of v1 (a shortcut `AutoHotFlow.lnk` in the Startup folder that starts AutoHotFlow.exe; check it with `shell:startup` first), the import asks whether to remove it. | The question appears with the preselection "No". No: the shortcut stays. Yes: it is removed. A shortcut of another program is not asked. | |
| 21 | Check the original folder `%APPDATA%\AutoHotFlow`. | Nothing in it has changed (compare with the folder before the import, for example by the file dates). | |
| 22 | Quit the application. Look at the log (`%TEMP%\ahf_manual_check\Log\Log.txt`). | The report of the import is in the log (manager, level a1), one line per item. | |

### Steps, part C (scaling and a killed manager)

| # | Step | Expected result | Result |
|---|---|---|---|
| 23 | At 100 % scaling: resize the window to the smallest size and back to the largest. | The buttons and the tree stay readable, no text is cut off, the window is not blank. | |
| 24 | At 225 % scaling (Windows settings): open the manager and the report window, look at both. | Both windows are sharp. The text of the buttons fits. The report text is readable and can be scrolled. | |
| 25 | Kill the manager process by hand (Task Manager, or the debug window's Processes tab). The tray icon stays. Then double-click the tray icon. | The manager does not come back by itself: the supervisor does not restart it (source: `src/supervisor/Children.ahk`, `AUTO_RESTART` has no manager). The double click starts a new manager, which shows its window; the log says `manager is not running (not_running), started it`. Source checked, not yet by hand. | |
| 26 | Watch for dialogs during the whole check. | No dialog (window class `#32770`) appears except the questions of the steps above. | |

### Steps, part D (enabling imported flows, notices, categories)

Start part B first (or continue in its window), so that imported v1 flows exist. Some of them may use a trigger or an element of a package that v2 does not have yet.

| # | Step | Expected result | Result |
|---|---|---|---|
| 27 | Select an imported flow that has a trigger and click Enable. Watch for up to 30 s. | If all its triggers are available: the state mark changes to enabled, nothing else. If a trigger is not available (missing package, not ported yet): a dialog "Trigger not available" names the flow and the reason; the flow stays enabled, the tree line carries the mark `a trigger is not available`. Known: the message is a blocking dialog, not a notice (F-0123), and the dialog leaves too little room for the text (owner's finding; check that you can still read the full reason, otherwise note it). | |
| 28 | Look at the tree line of a flow with an element of a missing package (any element type, not only the trigger). | The line names the missing packages (`missing package: <package>`), also when the flow is disabled. | |
| 29 | Click Notices after step 27. | The list opens. Note whether the unavailable trigger is listed there (not expected while F-0123 is open). | |
| 30 | Disable the flow of step 27 again. | The mark of the unavailable trigger and the enabled mark go away; no question appears (a question only comes for independent triggers, step 6). | |
| 31 | Create a category `Tests` with two flows in it. Select the category and click Delete; answer No, then Delete again and answer Yes. | With No nothing changes. With Yes a second question asks where the flows of the category go; after the choice they are in that category and the category is gone. Cancelling the second question keeps the category. | |
| 32 | Select a flow, click Change category and choose another category. Rename a category (to a name that exists, ignoring case, and to a free name). | The flow moves. The taken name is refused in the dialog, the free name is applied. Both survive a restart. | |
| 33 | Read the text of every dialog of this check (questions, folder dialog, report, notices). | No text is clipped; the full text is readable without resizing. Report each clipped dialog (the owner's finding: the dialogs of the manager leave too little space for the text). | |

### Steps, part E (export and import of `.ahf` files, WI-0081, REQ-MGR-050, REQ-SEC-060)

Start with the VS Code task of part A (or its terminal command), with a few flows in the fresh folder. The steps write `%TEMP%\ahf_manual_check\export-test.ahf`.

| # | Step | Expected result | Result |
|---|---|---|---|
| 34 | Select two flows in the tree (Ctrl click). Click "Import and export", choose "Export the selected flows", and save to `%TEMP%\ahf_manual_check\export-test.ahf`. | A save dialog opens and asks before it overwrites a file. The file is written. The flows do not change. | |
| 35 | Open the file in Explorer as a ZIP (or with 7-Zip). | The flow files are at the root of the archive, named by their IDs (`<flowId>.json`). Only `Variables/` entries besides them, and only if a flow has static variables. | |
| 36 | Click "Import and export", choose "Import flows from an .ahf file", and choose the file. | A warning says that a flow is a program with your rights, and lists the elements that act on the system. The preselection is "No". | |
| 37 | Answer "No". | Nothing is imported. The tree is unchanged. | |
| 38 | Repeat step 36 and answer "Yes". | For each flow whose name is taken, a question asks what to do: rename with the next free number, type a name, skip, or cancel. Choose "Rename: next free number". | |
| 39 | Look at the report and at the tree. | The imported flows are copies with a number in the name (`<name> 2`), all disabled (no state mark of a running or enabled flow). The report lists them as imported. | |
| 40 | Drag `export-test.ahf` from Explorer onto the manager window. | The warning of step 36 appears again. "No" changes nothing. | |
| 41 | Drag a text file (for example `%TEMP%\ahf_manual_check\note.txt`) onto the manager window. | The report window says that the file is not an .ahf file. Nothing is imported. | |
| 42 | Click "Import and export", choose "Export the selected flows", with no flow selected. | The report window says to select at least one flow. No save dialog opens. | |
| 43 | Watch for dialogs during the part. | Only the questions above appear as dialog windows (class `#32770`). | |

**Not covered by these checks** (listed as not checked in the source): drag and drop with a real mouse at 225 %, the folder dialog with a network folder, a v1 folder with a shortcut to another v1 installation, and a v1 folder that is larger than a few hundred flows (not measured).

## 2. Debug window

Test on the debug window (role `debug`). The source records that the window was checked without a mouse (`PrintWindow` screenshots, `BM_CLICK` on the buttons, `WM_CLOSE` to close), but not with real mouse operation. These steps are the manual check with a real user.

**Start.** Use either:

- VS Code task "Start: manual check 2, debug window in the manual-check data folder (manual_check.py)", or in a terminal `python tools/manual_check.py start -- --start=storage,engine,debug`. It uses the data folder as it is (with the flow `skeleton` of section 1, or a fresh one if there is none).
- When the application of section 1 still runs: VS Code task "Start: manual check, debug window on the running manual-check session (--command=debug)", or `python tools/manual_check.py start -- --command=debug`. This second start only forwards the command and ends at once with exit code 0. The same task is the second `--command=debug` of step 1.

Step 6 uses the test role `echo:a`, which exists only in the test entry; its task "Start: test entry with test roles and debug window (echo:a, debug)" runs in the session `main`, outside the manual-check folder.

### Steps

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the debug window (see above). | The window "AutoHotFlow - debug" appears. A second `--command=debug` does not open a second window; it brings the existing one to the front. | pass |
| 2 | Processes tab: look at the table. Then stop one process by hand. | All roles are listed with state and PID. After the process is stopped, the table changes within about one second. | pass |
| 3 | Snapshots tab: click "Aktualisieren" (Refresh), then select a role in the list. Tick "alle 2 s" and wait. | Formatted JSON is shown. The time at the top of the text keeps running. Scroll and selection positions do not jump; the text is replaced only when it has changed. | pass (after the fix, see notes) |
| 4 | Log tab: change the level filter and the source filter. Wait for new lines. | The list changes at once when a filter changes. New lines appear at the bottom. | pass |
| 5 | Events tab: start a flow. Click "Pause", then "Weiter". | "Pause" stops the list and shows the text "angehalten bei Nr ... neue Ereignisse wartend". "Weiter" shows all events again. | pass |
| 6 | Values tab: call `Debug.Dump(Map("a", 1), "test")` in a role (the guide suggests temporarily in the engine). Or run the VS Code task "Debug: trigger Debug.Dump in test role echo:a (ahf_dump.py)". Select the new entry. | The entry appears. The selection shows the JSON. | pass |
| 7 | Click "Bericht exportieren" (Export report). | The status line names the folder `Reports/<time>_manual`. The folder contains `report.json`, `summary.txt` and `Log.txt`. | pass |
| 8 | Close the window with X. | Only the debug window process ends. The supervisor log has no "ended unexpectedly" entry. No report is created. Note the session and the window you closed: the hub log line "debug gone" does not name the window. | pass |
| 9 | Watch for dialogs during the whole check. | No dialog appears. The window never blocks the other roles. | pass |

**Not covered by these checks** (listed as not checked in the source): real mouse operation, resizing the window, other DPI settings, and long running with "alle 2 s".

## 3. Dialog windows at other scaling (DPI)

Test on the real dialog windows of the elements Message_Box, Confirmation_Dialog and Condition_Debug_Dialog (the debug dialog), and on the Tooltip. Not automated. The check is by eye: no screenshot is compared. The dialog windows are AutoHotkey GUI windows, so the dialog rule of this document (window class `#32770`) does not cover them; a window that is not the element's window is still a failure.

**Why.** The code sets the DPI awareness of the dialog thread (`SetThreadDpiAwarenessContext`), and the layout of the windows is scaled by the DPI of the window (`src/elements/base/DialogWindow.ahk`, `_Apply` and `_OnDpiChanged`). Whether the text stays sharp and the controls fit at 125 % and 150 % is not tested. The source marks this as assumed. This check decides whether it holds. The first run (2026-10-16, before the scaling was added) found that the windows kept their pixel size, the title bar grew and pushed the button out, and that a scale change with an open window broke the layout.

**What to look for.** The text is sharp (not blurred), no button or label is clipped, the window size is reasonable, and the window fits on the screen.

**Set the scaling.** Windows Settings > System > Display > Scale: choose 100 %, 125 % or 150 %. Log off and on only if the text stays blurred after a change.

**Start.** VS Code task "Start: manual check 3, dialog windows at other DPI scaling (manual_check.py)", or in a terminal:
`python tools/manual_check.py start --flow dpi_dialogs -- --start=storage,engine,manager`

The start prepares a fresh data folder with the flow `dpi_dialogs` (`tests/data/manual/dpi_dialogs.json`, which runs the message box, the confirmation dialog, the debug dialog with a few variables and the tooltip, in this order). The flow does not start by itself: in the manager stub select `dpi_dialogs` and click Start. The window of an element that ends the flow early (for example the debug window closed with X) stops the flow at that element; then start the flow again in the stub.

### Steps

Close each dialog after its step (button or X). Steps 2 to 5 are repeated at each scaling level (steps 7 to 10 and 12 to 15).

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Set the Windows scale to 100 %. | Settings shows 100 %. | pass |
| 2 | Start the message box (see Start). | The text is sharp. The buttons and the text are fully visible. The window fits on the screen and its size looks reasonable. | pass |
| 3 | Start the confirmation dialog. | The text is sharp. Both buttons are fully visible. The window fits on the screen. | pass (scale not recorded separately) |
| 4 | Start the debug dialog with a few variables. | The text and the variable values are sharp and not cut off. The window fits on the screen. | pass |
| 5 | Start the tooltip. | The text is sharp and not cut off. The tooltip is shown near the mouse pointer and fits on the screen. | pass |
| 6 | Set the Windows scale to 125 %. | Settings shows 125 %. | pass |
| 7 | Start the message box. | As step 2. | pass (sporadic) |
| 8 | Start the confirmation dialog. | As step 3. | pass (scale not recorded separately) |
| 9 | Start the debug dialog with a few variables. | As step 4. | pass (checked with focus) |
| 10 | Start the tooltip. | As step 5. | pass (sporadic) |
| 11 | Set the Windows scale to 150 %. | Settings shows 150 %. | pass |
| 12 | Start the message box. | As step 2. | pass |
| 13 | Start the confirmation dialog. | As step 3. | pass (scale not recorded separately) |
| 14 | Start the debug dialog with a few variables. | As step 4. | pass (checked with focus) |
| 15 | Start the tooltip. | As step 5. | pass (sporadic) |
| 16 | Optional: with a second monitor at another scale, start the message box and the debug dialog on that monitor. | The text is sharp on that monitor too, and each window fits on the screen of its monitor. If no second monitor with another scale is available, write "not run" in the Result column. | pass |
| 18 | Test the start order. (a) Start the application at 225 % (restart it after the change) and open the message box. (b) Start it at 100 %, set 225 %, then open the message box. | Both windows look the same as at step 2 at 225 %: the text and the OK button are fully visible, the button has a margin to the edge. | pass (after the last fix) |
| 17 | At 100 %, start the message box and leave it open. Set the scale to 150 %, look at the window, then set it back to 100 %. Repeat with the debug dialog. | The window grows and shrinks with the scale. Text, buttons and size follow it, nothing is cut off, and no empty area remains. (Before the fix of 2026-10-16 only the title bar scaled.) | pass |

**Not covered by these checks:** a screenshot comparison, the exact pixel sizes, and how a dialog reacts when it is moved between monitors while it is shown (not checked).

## 4. Enabled flow with a hotkey and a periodic timer (REQ-TRG-010, REQ-TRG-020)

Test with a real start of the application and with real keys: the triggers of an enabled flow work without any click. The flow `triggers_check` (`tests/data/manual/triggers_check.json`, enabled state in `triggers_check.state.json`) has three triggers, all enabled at the start: a hotkey `Ctrl+Alt+Shift+F12` (the key is not blocked), a periodic timer of 5 s, and a start-up trigger of the type Windows (it fires only with `--windows-startup`, section 5). Each one shows a tooltip.

This check runs in the manual-check data folder, not in the default folder `%APPDATA%\AutoHotFlow v2` (the rule of this document). To run it in the default folder instead, copy the two files into `Flows\` and `FlowStates\` of that folder; the owner decides.

**Start.** VS Code task "Start: manual check 4, enabled flow with a hotkey and a periodic timer (manual_check.py)", or in a terminal `python tools/manual_check.py start --flow triggers_check -- --start=storage,engine,triggerhost,manager`. Without `--start` no role runs: no window and no log folder appear.

### Steps

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the application (see above). | The manager window opens and lists `triggers_check`. No dialog. | pass |
| 2 | Wait 12 s without touching the keyboard. | A tooltip "Periodic timer fired" appears two or three times. No tooltip "Started with Windows". | pass |
| 3 | Press `Ctrl+Alt+Shift+F12` once. | The tooltip "Hotkey fired" appears within about one second. | pass |
| 4 | Press `Ctrl+Alt+Shift+F12` three times in quick succession. | Each press shows the tooltip "Hotkey fired" (the tooltips may follow each other). | pass |
| 5 | In VS Code open the keyboard shortcuts (`Ctrl+K Ctrl+S`), click into the search field, click the "Record Keys" button on its right and press `Ctrl+Alt+Shift+F12`. (A plain text editor does nothing with this key, so it shows nothing.) | The search field shows `Ctrl+Alt+Shift+F12`: the application received the key as well (the key is not blocked). The tooltip "Hotkey fired" appears too. | pass |
| 6 | Watch for dialogs during the whole check. | No dialog (window class `#32770`) appears. | pass |
| 7 | Quit the application (button Beenden, or close the window). | The task terminal prints `AutoHotFlow ended with exit code 0`. | pass |

**Not covered by these checks:** the hotkey with window conditions (the flow uses "Everywhere"), a second flow with the same hotkey, and the start with Windows at log on (section 7). Not checked: the hotkey while another application holds the key.

## 5. Start with `--windows-startup` (REQ-TRG-220)

The same flow, started as after a start of Windows. The supervisor option `--windows-startup` tells the engine that AutoHotFlow starts with Windows (WI-0063).

**Start.** VS Code task "Start: manual check 5, the same enabled flow started with --windows-startup (manual_check.py)", or `python tools/manual_check.py start --flow triggers_check -- --start=storage,engine,triggerhost,manager --windows-startup`.

### Steps

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the application (see above). | No manager window opens (a start with Windows shows only the tray icon, E0083); the tray icon is there. No dialog. A double click on the tray icon shows the manager. | |
| 2 | Look at the screen within 5 s after the start. | Exactly one tooltip "Started with Windows" appears. | pass |
| 3 | Wait 12 s. | The periodic timer tooltips appear as in section 4, step 2. The start-up tooltip does not come again. | pass |
| 4 | Press `Ctrl+Alt+Shift+F12` once. | The tooltip "Hotkey fired" appears (as in section 4, step 3). | pass |
| 5 | Quit the application, then start it again with the task of section 4 (no option). | The second start shows no tooltip "Started with Windows". | pass |
| 6 | Watch for dialogs during the whole check. | No dialog appears. | pass |

## 7. Start with Windows, run as administrator, start without parameters (WI-0079, REQ-SET-030, REQ-SET-040, REQ-TRG-220, E0070, E0073, E0083)

**Warning for the owner.** Parts B to D change your real startup folder (`shell:startup`, the shortcut `AutoHotFlow v2.lnk`; the shortcut of v1, `AutoHotFlow.lnk`, is never touched), and parts C and D show the Windows question (UAC) several times. Parts B and D need a log off and log on. The settings are switched in the settings dialog of the manager (WI-0078). Switch both settings off at the end (step 17), so that no shortcut stays behind. If one is left over (a failed run), delete `AutoHotFlow v2.lnk` by hand: open `shell:startup` in the Explorer and delete the file. The shortcut of this check carries `--data=%TEMP%hf_manual_check`; it dangles (the application would start with a new empty data folder) if that folder is deleted, so delete the shortcut first. If your administrator account is not your user account (UAC asks for a password), the elevated session may use another profile (`%APPDATA%`, the startup folder): note what you see.

**Starts.** VS Code task "Start: AutoHotFlow without parameters" (part A; the real data folder `%APPDATA%\AutoHotFlow v2`). VS Code task "Start: manual check 7, start with Windows and run as administrator (manual_check.py)" (parts B to D; the data folder `%TEMP%\ahf_manual_check` with the flow `triggers_check`, session `manual`; the option `--startup-dir=default` lets this start handle the real startup folder, and the shortcut carries `--data` of this folder, so a log on starts the same data). In a terminal: `python tools/manual_check.py start --flow triggers_check -- --startup-dir=default`. To see the processes: Task Manager, tab Details, right click on a column header, "Select columns", "Elevated".

### Steps, part A (a start without parameters)

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the task "Start: AutoHotFlow without parameters". | The manager window opens (an empty list on a first start), one tray icon appears. No dialog. In Task Manager: the processes storage, engine, trigger host, manager, tray (command lines with `--role=...`). No debug window. | |
| 2 | Start the same task a second time while the first runs. | No second tray icon and no second set of processes; the running manager window comes to the front. The second start ends at once. | |
| 3 | Exit through the tray menu. | All processes end. | |

### Steps, part B (start with Windows)

| # | Step | Expected result | Result |
|---|---|---|---|
| 4 | Start the task of check 7. Open `shell:startup` in the Explorer. Switch "Start with Windows" on in the settings. | Within 2 s `AutoHotFlow v2.lnk` appears; its properties: target `AutoHotkey64.exe`, arguments with `AutoHotFlow.ahk`, `--data=...ahf_manual_check`, `--start=storage,engine,triggerhost` and `--windows-startup`. A v1 shortcut `AutoHotFlow.lnk` (if any) is unchanged. | |
| 5 | Switch the setting off, then on again. | The shortcut disappears, then comes back. | |
| 6 | Exit AutoHotFlow. Change the target in the properties of the shortcut (for example to `notepad.exe`), start the task again. | The shortcut has its old target and arguments again (repaired at the start). | |
| 7 | Exit AutoHotFlow. Log off and log on again (setting on). | After the logon only the tray icon appears, no manager window. The tooltip "Started with Windows" appears (the start-up trigger of `triggers_check` sees "Windows"). | |
| 8 | Double click the tray icon. | The manager window opens. | |

### Steps, part C (run as administrator)

| # | Step | Expected result | Result |
|---|---|---|---|
| 9 | Exit AutoHotFlow, start the task of check 7 (not elevated), switch "Start with Windows" off. Open Notepad as administrator and click into it. Press `Ctrl+Alt+Shift+F12` (flow `triggers_check`, enabled). | No tooltip "Hotkey fired": Windows does not give a not elevated program the keys of an elevated window. (This is the reason for the setting.) | |
| 10 | Switch "Run as administrator" on, answer No to the question "restart now?". | Nothing changes: the processes stay not elevated. | |
| 11 | Switch it off and on again, answer Yes. | AutoHotFlow closes, the Windows question (UAC) appears, accept it: the manager window comes back. In Task Manager every AutoHotkey64.exe process of AutoHotFlow (supervisor, storage, engine, trigger host, manager, tray, worker) shows "Elevated: Yes". No dialog of AutoHotFlow. | |
| 12 | Click into the elevated Notepad and press `Ctrl+Alt+Shift+F12`. | The tooltip "Hotkey fired" appears. The manager still lists and runs the flows (pipes and messages work between the elevated processes). | |
| 13 | Exit AutoHotFlow, start the task again, decline the question of Windows. | AutoHotFlow runs without elevation: manager window, all processes "Elevated: No", and a tray notice says that it runs without administrator rights. No second question. | |
| 14 | Exit. Start the task, accept the question. While the elevated session runs, start the same task of check 7 a second time (it is not elevated). | Known limit (F-0135, F-0137): the second start cannot reach the elevated session; it ends at once with exit 1. The log line about higher rights is visible only when it is started from a terminal (task output); a start by double click or from the shortcut shows nothing. The elevated session is not disturbed. Start it elevated, or end the session first. | |
| 15 | In the elevated session switch "Run as administrator" off, exit. Start the task. | No question; all processes "Elevated: No". | |

### Steps, part D (both together)

| # | Step | Expected result | Result |
|---|---|---|---|
| 16 | Switch both settings on, exit AutoHotFlow, log off and log on. At the Windows question first accept, then repeat the logon and decline. | Accept: the question appears at the logon, then only the tray icon; all processes elevated. Decline: only the tray icon, not elevated, and a tray notice. | |
| 17 | Cleanup: start the task, switch both settings off, check `shell:startup`, exit. | `AutoHotFlow v2.lnk` is gone. | |

## 8. Settings dialog, language and about window (WI-0078, REQ-SET-010, REQ-SET-070, REQ-LNG-010, REQ-LNG-020, REQ-MGR-100)

Not automated in full: the values and the messages are tested headless (`tests/e2e/test_manager_settings.py`, `tests/ahk/manager_settings_*.test.ahk`) and the windows are made in a unit test, but the look (the texts at other DPI, the clipping) and the drawn windows are checked here. The gui test `tests/fault/test_manager_settings_window.py` (VS Code task "Test: settings dialog and about window") covers the opening, Cancel, the language change of an open dialog and the About window, and is run by the owner only.

Start with the VS Code task of part A (or its terminal command), in the fresh folder. The DPI steps need the display scaling of Windows at 100 % and at 225 % (Settings, System, Display).

| # | Step | Expected result | Result |
|---|---|---|---|
| 44a | On the tab General, read the checkbox "Notify about unhandled errors". | The whole text is shown beside the box (not cut to the box). | |
| 44 | Click "Settings". | A window "Settings" opens with the tabs General, Flow settings and Debugging. Its texts are complete (no cut-off word or line), the buttons OK and Cancel are at the bottom. At 225 % the same holds. | |
| 45 | On the tab Flow settings, read the field "Elements waiting at the same time". | The value is 8, the note "1 to 16" stands beside it. The three runaway guard fields show "0 means no limit". | |
| 46 | Type 17 in "Elements waiting at the same time" and click OK. | The dialog stays open. The status line says that the settings are not changed and names the field with the range (1 to 16). Nothing is written (no `Settings.json` in `%TEMP%hf_manual_check`). | |
| 47 | Type 4 there, click OK. | The dialog closes. `%TEMP%hf_manual_check\Settings.json` has `"workers": 4`. | |
| 48 | Click "Settings" again. On the tab General choose "Deutsch", leave the dialog open with the choice, and click OK. | The dialog closes. The manager window shows German texts (the button "Einstellungen", the tree and the status line) without a restart. | |
| 49 | Right-click the tray icon. | The menu shows "Manager zeigen" and "Beenden". The old English entries are gone. | |
| 50 | Open the log window and the list of notices (their buttons), then open "Settings" again. | Their column titles and the drop-down lists are German. The settings dialog is German, its tabs are "Allgemein", "Flow-Einstellungen" and "Debugging". | |
| 51 | In the German dialog click "Durchsuchen..." on the tab General, then Cancel in the folder dialog. | The folder dialog opens and closes. The working directory of the dialog is unchanged. | |
| 52 | In the dialog choose the first item of the language list ("Sprache von Windows"), click OK. | The texts return to the language of Windows (English on the test PC) at once. The tray menu follows. | |
| 53 | Click "About". | A window "About AutoHotFlow" shows "AutoHotFlow version 2.0.0-phase2b", "AutoHotkey version" with the version of the installed AutoHotkey, the license line (GNU General Public License 3) and the project site. The site text is complete. | |
| 54 | Click "Open the project site". | The browser opens https://github.com/bichlepa/AutoHotFlow. | |
| 55 | Watch for dialogs during the part. | Only the folder dialog of step 51 appears as a dialog window (class `#32770`). | |
| 56 | On the tab General, read the two checkboxes "Start with windows" and "Run as admin" with their notes. | Both texts and notes are complete. The notes say that the shortcut is made for the current user only and that Windows asks for permission (UAC) at every start. | |
| 57 | Switch "Start with windows" on in the dialog, click OK. | Within 2 s `AutoHotFlow v2.lnk` appears in `shell:startup` (part B of section 7 describes it). Switching it off again and clicking OK removes it. | |
| 58 | Switch "Run as admin" on in the dialog, click OK. | Exactly one question asks whether to restart now (Yes on the left, No on the right). Answer No: nothing changes, the dialog is closed. | |
| 59 | Repeat step 58 and answer Yes. | AutoHotFlow closes, the Windows question (UAC) appears, and the manager comes back elevated (section 7, part C). The question does not appear a second time. | |

## Result

Record one result per run. Copy the template.

```
Date:
Tester:
Stub (section 1): steps 1 to 7 pass / fail (list failed steps)
Debug window (section 2): steps 1 to 9 pass / fail (list failed steps)
Triggers (sections 4 and 5): steps 1 to 7 and 1 to 6 pass / fail (list failed steps)
Start with Windows and administrator (section 7): steps 1 to 17 pass / fail (list failed steps)
Notes:
```

Run record (2026-10-14, stub, section 1):

```
Date: 2026-10-14
Tester: Paul
Stub (section 1): steps 1 to 6 pass
Debug window (section 2): not run
Notes: Steps 1 to 4 and 6 checked by the tester on screen. Step 5 exit code 0
  taken from the log of a `tools/ahkrun.py` start (shutdown finished with exit
  code 0). The VS Code task terminal shows no exit code, because the product
  process is not bound to the terminal. Step 1 started with the debug task, so
  the debug window opened next to the stub window (the step does not mention
  this yet). The data folder had no skeleton flow at first: the preparation
  was skipped; it was done for the default folder AutoHotFlow v2 afterwards.
  The dialog guard holds a #Warn dialog of 16:42 from another workspace
  (AutoHotFlow-wt\wi-41, src/engine/vars/VarLoader.ahk:101), not from this run.
```

Run record (2026-10-14, debug window, section 2):

```
Date: 2026-10-14
Tester: Paul
Stub (section 1): not part of this record (see the run record above)
Debug window (section 2): steps 1 to 9 pass (step 3 after the fix)
Notes: Step 3 first failed: the Snapshots text jumped to the top on every 2-second
  refresh. Cause (src/debugview/DebugGui.ahk, _DrawSnapshots): the text was replaced
  on every refresh, and setting the Edit value resets the scroll position. First fix
  attempt (commit bfda2d9): the time "Stand ..." was moved into its own label. This
  did not help, because uptimeMs and rssBytes in the JSON change on every refresh as
  well. Fix (commit ca9fbc6): the first visible line and the selection are kept when
  the text is replaced. Re-checked after this fix: no jump, the selection stays, and the
  time and the content update every 2 seconds. Horizontal scroll is not restored
  (not checked). Step 1: the second start with --start=debug on a running
  system only shows the manager; the debug window was opened with --command=debug
  (the way the guide describes for a running system). Step 2: the table changed
  after the engine was stopped by hand (a crash report was written for each stop).
  Step 6: the dump reached the debug window of a separate test session (m6), which
  was closed afterwards. Step 8: the debug role of session main (PID 21472) ended
  with peer_closed, no "ended unexpectedly" entry. Open point: the hub log shows only
  one "debug gone" entry (17:04:13), so it is not fully clear which debug window it
  belonged to; the window of session main may have been closed earlier than step 8.
```

Run record (2026-10-17, dialog windows, section 3):

```
Date: 2026-10-17
Tester: Paul
Dialog windows (section 3): steps 2 to 5 and 7 to 10 pass at 100 % and 225 %.
  Steps 12 to 15 (150 %) pass for the message box; the tooltip and the other
  dialogs at 150 % and the message box and tooltip at 125 % were checked
  sporadically, not systematically. Step 16 (second monitor at another scale):
  pass, a window moved between the two monitors stayed sharp and correctly
  sized. Step 17 (DPI change while the window is open): pass for the debug
  dialog at 100, 125 and 150 %; for the message box at 100, 150 and 225 %.
Notes: The debug dialog was checked with focus: started at 100 % and at 125 %;
  while open, the scale was changed to 100, 125 and 150 % and the window was
  moved between the screens; always sharp and correctly sized. The flow was run
  again from the start at each of the three scales, so the first appearance of
  the debug dialog was checked at each scale too. The confirmation dialog was
  checked, without a separate record of the scales. No flicker when the windows
  open was seen. Tooltip: good at all scales checked.
  Earlier problems that led to the fixes (not repeated here): the window size
  was wrong at a start with another scale than the current one (fixed by
  -DPIScale and by showing the window only after the size is set).
```

Run record (2026-10-17, triggers, sections 4 and 5):

```
Date: 2026-10-17
Tester: Paul
Triggers (sections 4 and 5): steps 1 to 7 and 1 to 6 pass
Notes: The first attempt showed no tooltip at all: the Start tasks passed
  --start=storage,engine,manager, so the triggerhost never started and nothing
  was armed. Fixed by adding triggerhost to --start (tasks.json and this
  document). Section 4 step 5 was reworded (a plain text editor shows nothing
  for this key; VS Code "Record Keys" does). All expectations met after that.
```

Run record (2026-10-19, block B of S0004, sections 1, 7 and 8):

```
Date: 2026-10-19
Tester: Paul
Manager (section 1, parts A to E): pass
Start with Windows, administrator, start without parameters (section 7): pass
Settings dialog, language and about window (section 8): pass, one cosmetic defect (see notes)
Notes: The tester reported "all manual checks work" and gave no step numbers, so no
  step is listed as failed. One cosmetic defect: in the settings dialog a checkbox was
  too wide and covered the text on its right, visible only after the mouse moved over
  it. Cause: the checkbox was 600 px wide and overlapped the note column. Fixed in
  commit dae9fee6 (width measured from the label; a probe test checks that no two
  controls of the dialog overlap at 96 and 216 dpi). The tester looked at the fix
  on his screen afterwards: pass. Earlier findings of the same checks, fixed before this
  record: question dialogs showed only their first text line (F-0128), the import
  from v1 was a button of its own (now the third choice of "Import and export"), and
  the Yes and No buttons of three questions were in the other order (all questions
  now have Yes left, No right). The gui test of the settings dialog
  (tests/fault/test_manager_settings_window.py) was not run after its fixes.
```
