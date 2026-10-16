# Manual checks (Handprüfung)

The automated tests do not cover the checks in this document. The project owner runs them by hand. Each step states the expected result. A step passes only if the expected result is seen. A dialog box (window class `#32770`) at any point is a failure.

The checks cover two interfaces: the manager stub (section 1) and the debug window (section 2). Use the "Result" template at the end to record a run.

Where a step starts the application, the VS Code task is named by its label in `.vscode/tasks.json`, followed by the same call for a terminal.

**Data folder and session.** The checks run with `tools/manual_check.py` in their own data folder `%TEMP%\ahf_manual_check` and their own session `manual`. The default folder `%APPDATA%\AutoHotFlow v2` stays untouched, and an instance that runs for something else (session `main`) is not met. The tool starts `AutoHotkey64.exe` without a timeout and without a dialog guard, waits until the application ends, and then prints `AutoHotFlow ended with exit code <n>` in the task terminal. The logs and reports of a check are in `%TEMP%\ahf_manual_check\Log` and `...\Reports`. A fresh folder (VS Code task "Setup: fresh data folder for the manual checks (manual_check.py prepare)", or `python tools/manual_check.py prepare`) holds only `Flows\skeleton.json`, a copy of `tests/data/skeleton_flow.json`.

## 1. Manager stub (GUI)

Test on the stub GUI. Not automated; the stub has a headless variant that the tests use.

**Start.** VS Code task "Start: manual check 1, manager stub in a fresh data folder (manual_check.py)", or in a terminal:
`python tools/manual_check.py start --fresh -- --ui=stub --start=storage,engine,manager,debug`

The start prepares a fresh data folder first (see above), so no preparation by hand is needed. It also starts the debug window.

### Steps

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the application (see above). | The stub window opens. No dialog. The debug window "AutoHotFlow - debug" also opens next to it. | pass |
| 2 | Check the window. | The list shows `skeleton`. The status line shows connection `ready`, `epoch` and `seq`. | pass |
| 3 | Click `skeleton`, then click Start. | The element list shows the states `running` and `finished` for three elements. The status line shows a command latency. | pass |
| 4 | During a run, move the window and click Start several times. | The window stays usable. Moving and clicking do not freeze it. | pass |
| 5 | Quit the application (button Beenden, or close the window). | The application ends: the task terminal prints `AutoHotFlow ended with exit code 0`. | pass (exit code 0 from an `ahkrun.py` start, before `manual_check.py` existed) |
| 6 | Watch for dialogs during the whole check. | No dialog (window class `#32770`) appears. The dialog guard would store one under `%TEMP%\ahf_dialogs\`. | pass |
| 7 | Right-click the tray icon of the manager (the only icon), choose `Beenden`. Start again, double-click the icon. | The menu has exactly one entry, `Beenden` (no AutoHotkey standard items such as Exit or Reload). It ends the application like the button (exit code 0, supervisor shutdown). The double click does nothing. | pass (owner, 2026-10-15: the tray entry ends the application like the button) |

**Not covered by these checks** (listed as not checked in the source): the GUI clicks of steps 3 and 4 are not covered by automated tests, so these steps are the only check of them. The labels are ASCII on purpose, so the display of umlauts is not checked. An engine restart while an instance runs is not checked.

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

**Why.** The code sets the DPI awareness of the dialog thread (`SetThreadDpiAwarenessContext`), and the pixel sizes of the windows are hard-coded (`src/elements/base/DialogWindow.ahk`). Whether the text stays sharp and the controls fit at 125 % and 150 % is not tested. The source marks this as assumed. This check decides whether it holds.

**What to look for.** The text is sharp (not blurred), no button or label is clipped, the window size is reasonable, and the window fits on the screen.

**Set the scaling.** Windows Settings > System > Display > Scale: choose 100 %, 125 % or 150 %. Log off and on only if the text stays blurred after a change.

**Start.** Not yet possible, see NEEDS-ATTENTION. A start path that shows a dialog element without the manager is not known yet. The tasks `Start:` in `.vscode/tasks.json` were checked by label only; no flow file in `tests/data` was checked for these elements. Do not run the steps until a start path is written here.

### Steps

Close each dialog after its step (button or X). Steps 2 to 5 are repeated at each scaling level (steps 7 to 10 and 12 to 15).

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Set the Windows scale to 100 %. | Settings shows 100 %. | |
| 2 | Start the message box (see Start). | The text is sharp. The buttons and the text are fully visible. The window fits on the screen and its size looks reasonable. | |
| 3 | Start the confirmation dialog. | The text is sharp. Both buttons are fully visible. The window fits on the screen. | |
| 4 | Start the debug dialog with a few variables. | The text and the variable values are sharp and not cut off. The window fits on the screen. | |
| 5 | Start the tooltip. | The text is sharp and not cut off. The tooltip is shown near the mouse pointer and fits on the screen. | |
| 6 | Set the Windows scale to 125 %. | Settings shows 125 %. | |
| 7 | Start the message box. | As step 2. | |
| 8 | Start the confirmation dialog. | As step 3. | |
| 9 | Start the debug dialog with a few variables. | As step 4. | |
| 10 | Start the tooltip. | As step 5. | |
| 11 | Set the Windows scale to 150 %. | Settings shows 150 %. | |
| 12 | Start the message box. | As step 2. | |
| 13 | Start the confirmation dialog. | As step 3. | |
| 14 | Start the debug dialog with a few variables. | As step 4. | |
| 15 | Start the tooltip. | As step 5. | |
| 16 | Optional: with a second monitor at another scale, start the message box and the debug dialog on that monitor. | The text is sharp on that monitor too, and each window fits on the screen of its monitor. If no second monitor with another scale is available, write "not run" in the Result column. | |

**Not covered by these checks:** a screenshot comparison, the exact pixel sizes, and how a dialog reacts when it is moved between monitors while it is shown (not checked).

## Result

Record one result per run. Copy the template.

```
Date:
Tester:
Stub (section 1): steps 1 to 7 pass / fail (list failed steps)
Debug window (section 2): steps 1 to 9 pass / fail (list failed steps)
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
