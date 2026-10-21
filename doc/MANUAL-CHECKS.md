# Manual checks (Handprüfung)

The automated tests do not cover the checks in this document. The project owner runs them by hand. Each step states the expected result. A step passes only if the expected result is seen. A dialog box (window class `#32770`) at any point is a failure.

The checks cover the manager (section 1), the debug window (section 2), the dialog windows at other scaling (section 3), triggers (sections 4 and 5), start with Windows and run as administrator (section 7), the settings dialog (section 8), the editor window (section 9) and the editing of the flows in the editor (section 10). The numbers are kept as they were: section 6 ("Checks that wait for a decision of the project owner", empty) was removed, and other documents refer to sections 7 and 8. Use the "Result" template at the end to record a run.

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

## 9. Editor window, look, view and live states (WI-0092, REQ-EDT-010 to REQ-EDT-040, REQ-EDT-110, REQ-EDT-150, REQ-EDT-230, REQ-USE-090, REQ-ROB-040)

Test on the real editor windows and their tray icons. Not automated: the e2e tests run the editor headless, and the window is checked by the gui tests of part D and by this section. The owner accepts the look of the editor (E0088). The look is judged on the screen; the screenshots of the tool "Tool: editor screenshots of two example flows" (PNG files in `temp/editor-screenshots`, drawn by the same renderer at zoom 0.7 and 1.5, no window) are the reference for part A, step 3, not a test.

**Start, parts A to C.** VS Code task "Start: manual check 9, editor with the imported v1 flows (manual_check.py)", or `python tools/manual_check.py start -- --start=storage,engine,triggerhost,manager`. The folder is the manual-check folder of section 1: run part B of section 1 first, so the v1 flows are imported there (they are disabled). The editor opens from the manager with the button "Edit" or a double click on the flow. Do not run an imported v1 flow: it may act on the system; the live states of part A, step 8 use the flow `skeleton`.

### Steps, part A (look, view, tooltip, live states, engine restart)

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the application (see above). | The manager window opens with the imported flows. No dialog. | |
| 2 | Select the imported v1 flow `Flow 1384439262` (129 elements) and click "Edit". Then open `Flow 2052424815` (6 elements) the same way. | One editor window per flow, titled "AutoHotFlow Editor - <name>", with the flow drawn at once. Each editor has its own tray icon. No dialog. | |
| 3 | Look at the drawing of `Flow 1384439262` at zoom 1 and with the whole flow visible. Compare with the screenshots in `temp/editor-screenshots`. | Loops are one object without seams. Actions and conditions have square corners. Icons are faded and fill the element background. Names are readable and vertically centred. Moving the pointer does not make the drawing flicker. **Owner: write here accepted or the change wanted (E0088).** | |
| 4 | Turn the wheel up and down with the pointer over an element. | Each notch changes the zoom by about 10 %. The point under the pointer stays under it. The zoom in the status bar follows. It stops at 0.10 and at 3.00. | |
| 5 | Drag the flow with the left button, then with the right button. | The content follows the pointer. The offset in the status bar changes, the zoom does not. | |
| 6 | Look at the status bar at the bottom of the window. | It reads "Offset: x <n> y <n>   \|   Zoom: <n.nn>   \|   <n> elements". It lies below the drawing and does not cover it. The text is complete. | |
| 7 | Hover an element for about one second, then a connection, then empty space. For an element with a MIGRATION place (an imported flow shows the badge) hover the badge. | The element tooltip gives kind, class and name. The connection tooltip gives its type. Empty space gives no tooltip. The badge tooltip lists the places. | |
| 8 | Live states: in the manager select `skeleton` and start it with the editor's tray menu, entry "Run" (part B, step 13), or with the button of the manager. Watch the editor. | While the elements run they are tinted, and the connection a thread took is tinted; the tint fades after the end. No dialog. | |
| 9 | Stop the engine by hand: debug window (section 2), Processes tab, stop the engine process. Watch the editor. | The engine starts again. Within a few seconds the editor shows the current state again (running elements, enabled state of the flow). The editor window stays open and its tray icon stays. | |
| 10 | Watch for dialogs during part A. | No dialog (window class `#32770`) appears. | |

### Steps, part B (tray icon and menu of an editor)

| # | Step | Expected result | Result |
|---|---|---|---|
| 11 | Hover the tray icon of the editor of `Flow 1384439262`. | The tooltip reads "Flow: Flow 1384439262". The icon of the window and the tray icon show the state of the flow (disabled, enabled, running). | |
| 12 | Open the context menu of the editor's tray icon. | Entries "Show", "Run", "Enable" or "Disable", "Close". | |
| 13 | On the editor of `skeleton`: menu "Run". Then menu "Enable", then "Disable". | Run starts the flow (live states as in part A, step 8). Enable and disable switch the flow; the manager shows the new state. No dialog. | |
| 14 | Hide the editor window behind other windows, then double-click its tray icon. | The window comes to the front. | |
| 15 | On the editor of `Flow 2052424815`: menu "Close". | The editor window and its tray icon disappear. Expected: no question (REQ-EDT-100: a flow has no unsaved state). The application, the manager and the tray icon of the application keep running. | |
| 16 | Close the editor of `skeleton` with the X button of its window. | As in step 15. | |

### Steps, part C (scaling, screens and size)

| # | Step | Expected result | Result |
|---|---|---|---|
| 17 | Set the display scaling to 100 %. Open an editor and look at text, lines and icons at zoom 1. | Sharp text, lines and icons. | |
| 18 | Set the display scaling to 225 % (restart the editor after the change). Look again at zoom 1 and at zoom 0.5. | Sharp at every zoom, the status bar text is complete. | |
| 19 | If a second screen with another scaling is there: move an open editor window to it, then back. | The drawing is sharp at the new scale after the move, without a restart (REQ-USE-090). The status bar stays at the bottom of the window. | |
| 20 | Resize the editor window: wider, narrower, taller, smaller. | The canvas takes the size, the status bar stays at the bottom, nothing is cut off, nothing overlaps. | |

### Steps, part D (gui tests of the editor; the PC is not used during them)

The gui tests open real editor windows and send real mouse and keyboard input. Run them alone, and do not move the mouse or press keys while they run. Expected result: all pass.

| # | VS Code task (label) | Test file | Tests |
|---|---|---|---|
| 21 | "Test: editor window (gui, ...)" | `tests/fault/test_editor_window.py` | the window opens with the flow and closes like the X button (a planned end) |
| 22 | "Test: editor tray icon and menu (gui, ...)" | `tests/fault/test_editor_tray_icon_gui.py` | the real icon of an editor opens its menu, and a menu open for 8 s does not make the editor hung |
| 23 | "Test: editor mouse input and status bar (gui, ...)" | `tests/fault/test_editor_mouse_gui.py` | the status bar lies below the canvas and does not overlap it; a real wheel zooms at the pointer and a real left drag moves the view |

### Steps, part E (renderer with a window, WI-0092 task 2; owner only)

| # | Step | Expected result | Result |
|---|---|---|---|
| 24 | VS Code task "Tool: renderer measurement with a window (WI-0092, owner; ...)" with the size 1920 x 1080 (whole flow). Close the other programs first. | The task opens a window of 1920 x 1080 for about two minutes and writes the line `WINDOW ...` into `temp/s5/renderer-window.txt`. Mean below 16 ms (R0002, REQ-PRF-060). Write the line in the result. | |
| 25 | The same task with 3840 x 2160 (a 4K screen is needed, otherwise the window is cut; write that down). | The `WINDOW` line for 4K is recorded (a measurement; see MEASUREMENTS.md MS-0048). Without a screen of at least 3840 x 2160 (the primary screen) the file gets the line `WINDOW skipped ...` instead of a cut window; the `RESULT` line of 3840 x 2160 is written in both cases. Write down which of the two you got. | |

## 10. Editing the flows in the editor (WI-0104, S0006: REQ-EDT-030 to REQ-EDT-110, REQ-EDT-100, REQ-ROB-120, REQ-TRG-030)

Test by hand on the real editor windows, with the mouse and the keys, at 100 % and at 225 % display scaling. Not automated: the e2e tests drive the editor headless, the gui tests of part D send real input and are run by the owner only. This section is the acceptance of editing (S0006): the owner closes it. Until the owner writes the result, the editing requirements that depend on it stay `partial`.

**Start, parts A to C.** Run section 9, part B first, or use the same folder: the editing checks need the imported v1 flows, which are disabled. VS Code task "Start: manual check 10, editing the imported v1 flows (manual_check.py)", or `python tools/manual_check.py start -- --start=storage,engine,triggerhost,manager`. Do not run an imported v1 flow: a running flow may act on the system. Edit and run the flow `skeleton` (a copy of the test skeleton) when a step says so. Nothing is asked when an editor closes (REQ-EDT-100); a change is written to the file a few seconds after it is made, so give it about 10 s before you close the application.

**Scaling.** Part A is run at 100 % display scaling. Part B is run again at 225 % (set the scaling in the Windows settings and start the application again). The look is part of section 9; here only the editing is checked.

### Steps, part A (100 %: editing with the mouse and the keys)

Open `Flow 1384439262` with "Edit" in the manager. The flow has 129 elements; the grid is 35 units.

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Click an element, then a connection, then empty space. | The element is selected alone (a frame and its buttons near it). The connection is selected alone. Empty space unselects all. The status bar names the selection. | |
| 2 | Ctrl+click a second element. Then press Ctrl+A, then Esc. | Ctrl+click adds the element to the selection. Ctrl+A selects every element and connection. Esc unselects all. | |
| 3 | Drag a rectangle on empty space over three elements and the connection between two of them. | The elements the rectangle touches are selected, and the connection between selected elements is selected too. A Ctrl drag adds the rectangle to the selection. Esc during the drag cancels it. | |
| 4 | Drag the selection by one element. Release. Press Ctrl+Z, then Ctrl+Y. | The elements follow the pointer and snap to the grid when the mouse is released. The move is one undo step: Ctrl+Z takes it back, Ctrl+Y makes it again. | |
| 5 | Drag an element and press Esc before the release. | The element goes back to its place. No change is made (no undo step). | |
| 6 | Select a loop. Drag the tail (the end of its bar) down and up. | The height of the bar changes on the grid, and the loop never gets shorter than two grid steps. One undo step per drag. | |
| 7 | Click the field "action" at the top left of the canvas. Move the pointer, then click on empty space. | A box follows the pointer. The click places a new action there (snapped to the grid) and the class list opens, grouped by category. | |
| 8 | In the class list at the user level Beginner: look at the classes. Choose one and press OK. Then start the placing again and press Cancel in the list. | The list shows only Beginner classes. OK adds the element with its default name and parameters, selected, one undo step. Cancel adds nothing. | |
| 9 | Select an action. Click its plus button, then another element. | A connection is made from the action to the element. Ctrl+Z takes it back. | |
| 10 | Connect an element to a trigger (drag from the plus button onto the trigger). | The connection is refused with a text in the status bar. Nothing is added. | |
| 11 | Double-click a connection. Choose another connection type (for example a yes connection) and press OK. | The connection shows the new type (the tooltip names it). One undo step. | |
| 12 | Select a connection. Move one of its ends with the move buttons. | The end moves to the other element; the connection follows. Ctrl+Z takes the move back. | |
| 13 | Select an action. Press Del. Answer "no" to the question, then press Del again and answer "yes". | The question is asked once per press. "no" changes nothing; "yes" removes the element and its connections (one undo step). | |
| 14 | Select an element. Click its trash button. Answer "no". | The question is asked. "no" changes nothing. | |
| 15 | Select two elements. Press Ctrl+C, then Ctrl+V with the pointer on an empty place of the canvas. | The copies appear at the pointer, selected, with their connections between them. One undo step. Ctrl+X removes the selection without a question and copies it. | |
| 16 | Use the menu Edit: Undo, Redo, Cut, Copy, Paste, Delete, Select all. | Each entry does what its key does. A disabled entry (for example Undo with no step) does nothing. | |
| 17 | Make ten changes. Press Ctrl+Z ten times, then Ctrl+Y ten times. | Each press takes back or makes one change, in order. The flow ends as it was after the ten changes. | |
| 18 | Press Ctrl+S. Look at the status bar. | The flow is saved (the status bar says so, or nothing is asked). No dialog. | |
| 19 | Right-click an element. Right-click a connection. Right-click empty space. | The context menu of the element offers Cut, Copy, Delete (and the trigger entries for a trigger). The one of the connection offers Change type and Delete. The one of empty space offers Paste, Select all and "Create new action, condition, loop, trigger" at that place. | |
| 20 | Right-drag the flow with the pointer over it. | The view moves. No context menu opens after the drag. | |
| 21 | On a trigger of `Flow 1384439262` (a manual trigger, if there is one): click its switch. Then its star on another manual trigger, if there is one. | The switch enables or disables the trigger; the state shows at once. The star makes the trigger the default: one undo step. A refused change shows a text in the status bar. | |
| 22 | Right-click the trigger of step 21. | The context menu offers the entry "Enable this trigger" or "Disable this trigger" (the opposite of the state shown) and "Set as default trigger" (for a manual trigger that is not the default). The entries do what their labels say. | |
| 23 | Change the zoom and the offset, then close the editor (menu Exit or the close box). Open the editor again. | The zoom and the offset are as they were. Nothing is asked. | |

### Steps, part B (the same at 225 %, and the killed editor)

Repeat the steps 1 to 19 of part A on `Flow 1384439262` at 225 % (the look of the drawing is not the point; the clicks and the texts are). Then:

| # | Step | Expected result | Result |
|---|---|---|---|
| 24 | Copy two elements in the editor of `Flow 1384439262`. Open `Flow 2052424815` (6 elements) with "Edit" in the manager, and paste into its editor (Ctrl+V with the pointer on its canvas). | The elements appear in the second flow. Both editors show the change. Nothing is pasted into the first flow by the paste. | |
| 25 | Cut two elements of `Flow 2052424815` and paste them back into `Flow 2052424815`. | The elements come back as new copies with new IDs (the names stay). One undo step per paste. | |
| 26 | Make a change in `skeleton` and wait about 10 s. Then end the editor process of `skeleton` in the Task Manager (not the window; the process of the editor). | The editor window and its tray icon disappear. Within a few seconds the tray icon of the application shows a balloon: the editor of `skeleton` has ended. Nothing reopens the editor by itself. | |
| 27 | Click the balloon. | The editor of `skeleton` opens again. It shows the change of step 26 (the change was written before the kill). | |
| 28 | Open the manager's list of notices (the window of the manager). Find the notice of the killed editor. | The notice is in the list, with its button "Open editor"; the button opens the editor again. | |
| 29 | Watch for dialogs during part B. | No dialog (window class `#32770`) appears, except the questions of steps 13 and 14. | |

### Steps, part C (the gui tests of S0006; the PC is not used during them)

The gui tests open real editor windows and send real mouse and keyboard input. Run them alone, and do not move the mouse or press keys while they run. Expected result: all pass.

| # | VS Code task (label) | Test file | Tests |
|---|---|---|---|
| 30 | "Test: editor menu bar and context menu (gui, a real editor window; a right click is sent; do not use the PC)" | `tests/fault/test_editor_menus_gui.py` | the menu bar has its seven entries, a right click opens a context menu that the editor answers while it is open |
| 31 | "Test: editor mouse input and status bar (gui, a real editor window; wheel and drag are sent; do not use the PC)" | `tests/fault/test_editor_mouse_gui.py` | the status bar lies below the canvas; a real wheel zooms; a real drag moves the view |
| 32 | "Test: editor crash notice, balloon click (gui, ...)" | `tests/fault/test_editor_crash_notice_gui.py` | a click on the balloon of an editor notice opens the editor again |

Not in the gui tests yet: a real mouse selection, move, connection and placing of elements (REQ-EDT-060, REQ-EDT-070, REQ-EDT-080 stay `partial` until steps 1 to 16 are checked by hand; a gui test for them is open work).

## 11. Acceptance S0007: settings of the elements, assistants, help, flow settings and the error window (WI-0114; WI-0105 to WI-0113, WI-0115)

Test by hand on the real windows, at 100 % and at 225 % display scaling. The project owner closes this section; the agent does not run it and does not claim it closed. Until the owner writes the result, the requirements REQ-EDT-120, REQ-EDT-130, REQ-EDT-140, REQ-EDT-200, REQ-ELM-020, REQ-LNG-040 and REQ-USE-080 stay `partial`. The headless part is automated: `tests/e2e/test_core_settings.py` (every element of the core set is changed in its settings form, saved and run), `tests/e2e/test_editor_settings.py`, `tests/e2e/test_editor_flow_settings.py`, `tests/test_help.py`, `tests/fault/test_help_role.py`, `tests/integration/test_error_window.py`. The gui tests of part G are the owner's and are run alone.

**Start.** Run section 9, part B first, or use the same folder: the checks need the imported v1 flows, which are disabled. VS Code task "Start: manual check 11, settings, help and the error window (manual_check.py)", or `python tools/manual_check.py start -- --start=storage,engine,triggerhost,manager`. Do not run an imported v1 flow: a running flow may act on the system. Run only the flow `skeleton` (a copy of the test skeleton) when a step says so. A change is written to the file a few seconds after it is made, so give it about 10 s before you close the application.

**Scaling.** Parts A and B are run at 100 %. Part C repeats key steps of parts B, D and E at 225 % (set the scaling in the Windows settings and start the application again).

### Steps, part A (100 %: expression check while typing, WI-0108, REQ-EDT-200)

Steps 1 to 8 are the steps of the first version of this section (WI-0108); their numbers stay. Open `skeleton` with "Edit" in the manager. Double-click an action with an expression field (for example Sleep, its field Duration). If the flow has none, add one: click the field "action" on the canvas and choose Sleep.

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | In Duration type `1 + * 2`. Stop typing and wait about one second. | Below the field, in red: "Syntax error at line 1, column 5: unexpected '*'; an operand is expected". The text is not changed. | |
| 2 | Change the text to `1 + 2`. Wait about one second. | The red line disappears. | |
| 3 | Change the text to `1 +`. Wait about one second. | "Syntax error at line 1, column 4: unexpected end of the input; an operand is expected". | |
| 4 | Press Ctrl+Z, then Ctrl+Y, in the field. Then press Cancel. | They undo and redo the typing in the field only. The flow is unchanged: after the window is closed, the Edit menu's Undo undoes the last change made before the window was opened, as it did before step 4. | |
| 5 | Press Del in the field, in the middle of the text. | One character is deleted. No question about deleting an element appears, and the element stays. | |
| 6 | With a warning shown, press OK. | The window closes and the change is kept (the warning does not refuse OK). One undo step in the editor. | |
| 7 | Open the settings again, type `1 + * 2`, and press Cancel before the warning shows. | The window closes, nothing is changed. | |
| 8 | Watch for dialogs during the section. | No dialog (window class `#32770`) appears, except the answer of step 5 if it asks for one. | |

### Steps, part B (100 %: field types, content types, checks and migration places, WI-0105, WI-0106, REQ-EDT-120)

Open the settings of an element by a double click on it, or by its button "edit". Use the imported flow `Flow 1384439262` (129 elements) or `skeleton`, as the step names. The core set has these field types: edit, multi-line edit, check box, radio, drop-down and list box, and the content icons (expression, string, variable name).

| # | Step | Expected result | Result |
|---|---|---|---|
| 9 | Open the settings of a Sleep action: the field Duration (an expression field) and the radio Unit. Choose Seconds and press OK. Then Ctrl+Z in the editor. | The field shows the value, its icon shows the expression content. OK changes the element and its name (for example "Sleep: 1 s"); Ctrl+Z takes the change back in one step. | |
| 10 | Open the settings of a New variable. Change the check box "Write only if variable does not exist", change the multi-line text of the value, press OK. | The check box and the multi-line text show what was typed, and the value is kept after OK. | |
| 11 | Open a "Variable content is" condition. Look at the radio of the content types (List, Time, Number, Integer, ...). Choose Integer and press OK. | The radio shows the chosen type, and the element has it after OK. | |
| 12 | Open a Message box whose timeout is off. Choose "Define timeout" in the radio of the timeout, then "No timeout" again. Press Cancel. | The timeout fields are enabled only for "Define timeout" (the check of the element). Cancel changes nothing. | |
| 13 | Open a Trace point check. Look at the list box of the trace points that must have been passed: the trace points of the flow are in it. Select one and press OK. | The list shows every trace point of the flow, and the selection is kept after OK. | |
| 14 | Open an Execute flow. Look at the drop-down of the flow: the names of the other flows are shown (not their IDs). Choose one, uncheck "This flow", press OK. | The drop-down lists the flows by name. The element names the chosen flow after OK. | |
| 15 | Open a Loop (Simple loop). Check "Endless loop": the field of the count is disabled. Uncheck it. | The count field is disabled exactly while the check box is on. | |
| 16 | Find an element of the imported flow with a migration badge (a small badge at its top right corner). Open its settings. | The settings show the migration place with its v2 field and the v1 text. Change the value and press OK: the badge is gone. | |
| 17 | Open the settings of an element with an expression warning (a wrong expression, typed in the field). Press OK. | The window closes and the change is kept; the warning does not refuse OK. | |
| 18 | Add a Sleep action with the field "action" on the canvas. Choose it in the class list, look at the settings window, then press OK. Add another one and press Cancel. | The settings appear before the element is added. OK adds it with its values (one undo step). Cancel adds nothing. | |
| 19 | Watch for dialogs during part B. | No dialog (window class `#32770`) appears, except the questions of the editing steps of section 10. | |

### Steps, part C (225 %: the look of the windows, repeated key steps)

| # | Step | Expected result | Result |
|---|---|---|---|
| 20 | Repeat the steps 9, 12 and 16 at 225 %. | The windows fit the screen, all buttons and fields are reachable, and the texts are not cut. | |
| 21 | Repeat the help steps 23 and 25 at 225 %. | The help window fills a sensible part of the screen, and the text is sharp. | |

### Steps, part D (assistant and help: WI-0110, WI-0111, WI-0115, E0098 to E0100; REQ-EDT-130, REQ-ELM-020, REQ-LNG-040)

Only the window assistant has an element in the product: the trigger "Hotkey". The mouse and colour assistants have no element of the core set yet; they are checked in S0008 with their elements.

| # | Step | Expected result | Result |
|---|---|---|---|
| 22 | Open the settings of a Hotkey trigger of an imported flow. Press the button "Import window identification". Move the pointer over another window, pick it in the window assistant, then press OK. | The window assistant takes a window from a list (its title, class and process). The fields of the window identification show them after OK. Cancel changes nothing. | |
| 23 | Open the settings of Sleep (step 9). Press "Help". | The help window opens with the page of Sleep: its title, the parameters and the v2 text. The window is a window of its own. | |
| 24 | In the manager, open the menu "Help". Then open the link "Variables" in the index. | The index and the general page open in the help window. | |
| 25 | In the manager: Settings, the general tab, the entry "Help viewer". Set it to `classic`, then open the help of step 23 again. Then set `webview2`, open it again, then `browser`, then `auto`. | Each choice opens the page with the viewer it names (classic: the control of Windows, webview2: the WebView2 view, browser: the default browser). `auto` shows the WebView2 view on this PC. The chosen viewer is kept after a restart of the application. | |
| 26 | In the WebView2 view, follow a link to another page and use the back button (or Alt+Left). | The page changes. A link to a web address opens the default browser, not the help window. | |
| 27 | Open the help of an element of the core set from the editor's settings for each of: Action_Trace_Point, Loop_Parse_A_String, Condition_Confirmation_Dialog. | Each page is the page of its element, with the parameters of the element. The English text is shown (the translations come in S0009). | |

### Steps, part E (flow settings: REQ-EDT-140, REQ-EXE-050, REQ-EXE-130, REQ-EXE-170, REQ-VAR-100)

| # | Step | Expected result | Result |
|---|---|---|---|
| 28 | In the editor of `skeleton`, open the menu "Settings" (the flow settings). Set the execution policy to "wait", press OK. Then Ctrl+Z. | The dialog closes on OK, the change is one undo step, and Ctrl+Z restores the policy. | |
| 29 | Open the flow settings. Choose the working directory with the folder dialog, then Cancel. Open them again and type an invalid limit (a text in the field of a limit). Press OK. | Cancel changes nothing. The invalid limit keeps the dialog open with a message, and nothing is sent. | |
| 30 | Open the flow settings of the imported flow `Flow 2052424815` (a migrated flow). Set the type mode to strict. | A warning says that the flow is migrated and may fail in strict mode. Cancel keeps the mode as it was. | |
| 31 | In the flow settings press "Show log". | The log window of the manager opens. It should show the entries of this flow only; if it shows all entries, that is finding F-0176 (`doc/OPEN-ITEMS.md`). | |
| 32 | At 100 %: check the dialog of steps 28 and 29 once more. | The dialog fits the screen, and all fields are reachable. | |

### Steps, part F (the window of an unhandled error: WI-0113, REQ-USE-080 part 2)

| # | Step | Expected result | Result |
|---|---|---|---|
| 33 | In the settings of the action Do nothing of `skeleton` set "Result" to Exception and press OK. Run `skeleton` (the manager, Start). | A notice appears in the tray (balloon) and in the manager's list of notices. The flow is marked in the manager. | |
| 34 | Open the notice of step 33 (the list of notices, the button of the variables). | A window shows the variables of the branch at the failing element, with names and values, and the copy button. The values are shown in clear text; the owner's decision on that is pending (`NEEDS-ATTENTION.md`). | |
| 35 | Switch the notices of `skeleton` off in its flow settings, run it again. | No new notice is shown; the flow is still marked as failed in the list. | |
| 36 | Set the element back to Normal, switch the notices on again. | The flow runs without an exception and without a notice. | |

### Steps, part G (gui tests of S0007; the PC is not used during them)

The gui tests open real windows and send real mouse and keyboard input. Run them alone, one after the other, and do not move the mouse or press keys while they run. Expected result: all pass. The agent does not run them (`doc/TEST-STRATEGY.md` section 6).

| # | VS Code task (label) | Test file | Tests |
|---|---|---|---|
| 37 | "Test: editor settings window (gui, a real editor window; a double click and Esc are sent; do not use the PC)" | `tests/fault/test_editor_settings_gui.py` | the settings window of an element opens by a double click and closes with Esc |
| 38 | "Test: window assistant (gui, the mouse moves onto a target window; do not use the PC)" | `tests/fault/test_editor_assist_gui.py` | the window assistant takes the window under the mouse |
| 39 | "Test: help window (gui, the classic viewer shows a page in a window, then the default browser opens the index; both hold for about 12 s, do not use the PC)" | `tests/fault/test_help_window_gui.py` | the classic viewer shows a page; the browser opens the index |
| 40 | "Test: help window with WebView2 (gui, three pages in the WebView2 view, about 18 s; set the scaling first, 100 % and 225 %; do not use the PC)" | `tests/fault/test_help_webview2_gui.py` | three pages in the WebView2 view; run it at 100 % and at 225 % |
| 41 | "Test: flow settings window (gui, a real editor window opens the dialog from the menu entry Settings; do not use the PC)" | `tests/fault/test_editor_flow_settings_gui.py` | the dialog opens from the menu entry Settings |
| 42 | "Test: error window (gui, a real manager window opens, the list of notices and the window of the variables; do not use the PC)" | `tests/fault/test_error_window_gui.py` | the list of notices and the window of the variables |

Not in the gui tests: the look of the windows (steps 20, 21, 32) and the real window assistant with a window of the owner's choice (step 22). They are checked by hand.

## Result

Record one result per run. Copy the template.

```
Date:
Tester:
Manager (section 1): parts A to E pass / fail (list failed steps)
Debug window (section 2): steps 1 to 9 pass / fail (list failed steps)
Dialog windows (section 3): steps pass / fail (list failed steps)
Triggers (sections 4 and 5): steps 1 to 7 and 1 to 6 pass / fail (list failed steps)
Start with Windows and administrator (section 7): parts A to D pass / fail (list failed steps)
Settings dialog (section 8): steps 44 to 59 pass / fail (list failed steps)
Editor (section 9): steps 1 to 25 pass / fail (list failed steps); look accepted yes / no (step 3)
Editing (section 10): steps 1 to 29 pass / fail (list failed steps) at 100 % and 225 %; gui tests 30 to 32 pass / fail; closed by the owner yes / no
Settings, help, flow settings and error window (section 11): steps 1 to 19 at 100 %, 20 to 21 at 225 %, 22 to 36 pass / fail (list failed steps); gui tests 37 to 42 pass / fail; closed by the owner yes / no
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

Run record (2026-10-20, editor, section 9):

```
Date: 2026-10-20
Tester: Paul
Editor (section 9): steps 1 to 24 pass; step 25 (4K) not run, no 4K screen; look accepted yes (step 3, E0088)
Notes: The tester reported that he did manual check 9 and is satisfied. He gave no step
  numbers, so no step is listed as failed. The look was reworked after his first
  review (loop drawn as one object, square corners for loops and actions, icons faded and
  filling the element behind a centered name) and accepted afterwards. The VS Code
  tasks of part D (three gui tests) and part E (renderer measurement with a window)
  did not start at first; they were fixed (see the how-to entries on gui tests) and
  the gui tests of part D pass now, as the tester reported. The numbers of the
  measurement with a window (the WINDOW line at 1920 x 1080) were not given for this
  record. Step 25 (4K) was not run: the tester has no 4K screen, only a 2K one; the
  4K numbers stay open (a measurement, not a requirement of the check). Postponed
  by the tester:
  the latency with 300 changing elements (F-0156) and the order inside a batch of
  element states (F-0161).
```
