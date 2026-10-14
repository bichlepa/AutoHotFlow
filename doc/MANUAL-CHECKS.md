# Manual checks (Handprüfung)

The automated tests do not cover the checks in this document. The project owner runs them by hand. Each step states the expected result. A step passes only if the expected result is seen. A dialog box (window class `#32770`) at any point is a failure.

The checks cover two interfaces: the manager stub (section 1) and the debug window (section 2). Use the "Result" template at the end to record a run.

Where a step starts the application, the VS Code task is named by its label in `.vscode/tasks.json`. The command line from the original guide is kept as well.

## 1. Manager stub (GUI)

Test on the stub GUI. Not automated; the stub has a headless variant that the tests use.

**Preparation.** Use an empty data folder. Copy `tests/data/skeleton_flow.json` to `<data folder>\Flows\skeleton.json`.

**Start.** Use either:

- VS Code task "Start: manager stub with debug window (--ui=stub --start=storage,engine,manager,debug)", or
- in a second terminal (not with `--headless`):
  `python tools/ahkrun.py --timeout 300 src/AutoHotFlow.ahk --session=gui1 --data=<empty folder> --start=storage,engine,manager --ui=stub`

Note: the task and the command line differ. The task also starts the debug role and starts `AutoHotkey64.exe` directly, without a timeout. The command line runs through `ahkrun.py` with a 300 s timeout.

### Steps

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the application (see above). | The stub window opens. No dialog. With the debug task, the debug window "AutoHotFlow - debug" also opens next to it. | pass |
| 2 | Check the window. | The list shows `skeleton`. The status line shows connection `ready`, `epoch` and `seq`. | pass |
| 3 | Click `skeleton`, then click Start. | The element list shows the states `running` and `finished` for three elements. The status line shows a command latency. | pass |
| 4 | During a run, move the window and click Start several times. | The window stays usable. Moving and clicking do not freeze it. | pass |
| 5 | Quit the application (button Beenden, or close the window). | The process ends with exit code 0. The exit code is read from the `ahkrun.py` log (`shutdown: finished with exit code 0`), because the VS Code task terminal does not show it. | pass (exit code 0 from the `ahkrun.py` start) |
| 6 | Watch for dialogs during the whole check. | No dialog (window class `#32770`) appears. The dialog guard would store one under `%TEMP%\ahf_dialogs\`. | pass |

**Not covered by these checks** (listed as not checked in the source): the GUI clicks of steps 3 and 4 are not covered by automated tests, so these steps are the only check of them. The labels are ASCII on purpose, so the display of umlauts is not checked. An engine restart while an instance runs is not checked.

## 2. Debug window

Test on the debug window (role `debug`). The source records that the window was checked without a mouse (`PrintWindow` screenshots, `BM_CLICK` on the buttons, `WM_CLOSE` to close), but not with real mouse operation. These steps are the manual check with a real user.

**Start.** Use either:

- VS Code task "Start: product with debug window (--start=storage,engine,debug)", command line `AutoHotFlow.ahk --start=debug`, or
- on a running system, VS Code task "Start: debug window on running instance (--command=debug)", command line `AutoHotFlow.ahk --command=debug`.

### Steps

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the debug window (see above). | The window "AutoHotFlow - debug" appears. A second `--command=debug` does not open a second window; it brings the existing one to the front. | pass |
| 2 | Processes tab: look at the table. Then stop one process by hand. | All roles are listed with state and PID. After the process is stopped, the table changes within about one second. | pass |
| 3 | Snapshots tab: click "Aktualisieren" (Refresh), then select a role in the list. Tick "alle 2 s" and wait. | Formatted JSON is shown. The time at the top of the text keeps running. Scroll and selection positions do not jump; the text is replaced only when it has changed. | fail (see notes) |
| 4 | Log tab: change the level filter and the source filter. Wait for new lines. | The list changes at once when a filter changes. New lines appear at the bottom. | pass |
| 5 | Events tab: start a flow. Click "Pause", then "Weiter". | "Pause" stops the list and shows the text "angehalten bei Nr ... neue Ereignisse wartend". "Weiter" shows all events again. | pass |
| 6 | Values tab: call `Debug.Dump(Map("a", 1), "test")` in a role (the guide suggests temporarily in the engine). Or run the VS Code task "Debug: trigger Debug.Dump in test role echo:a (ahf_dump.py)". Select the new entry. | The entry appears. The selection shows the JSON. | pass |
| 7 | Click "Bericht exportieren" (Export report). | The status line names the folder `Reports/<time>_manual`. The folder contains `report.json`, `summary.txt` and `Log.txt`. | pass |
| 8 | Close the window with X. | Only the debug window process ends. The supervisor log has no "ended unexpectedly" entry. No report is created. Note the session and the window you closed: the hub log line "debug gone" does not name the window. | pass |
| 9 | Watch for dialogs during the whole check. | No dialog appears. The window never blocks the other roles. | pass |

**Not covered by these checks** (listed as not checked in the source): real mouse operation, resizing the window, other DPI settings, and long running with "alle 2 s".

## Result

Record one result per run. Copy the template.

```
Date:
Tester:
Stub (section 1): steps 1 to 6 pass / fail (list failed steps)
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
Debug window (section 2): steps 1, 2, 4 to 9 pass; step 3 fails
Notes: Step 3 fails: the Snapshots text jumps to the top on every 2-second refresh.
  Cause (src/debugview/DebugGui.ahk, _DrawSnapshots): the text changes on every
  refresh and is replaced; setting the Edit value resets the scroll position.
  First fix attempt (commit bfda2d9): the time "Stand ..." was moved out of the
  text into its own label. This did not help, because uptimeMs and rssBytes in
  the JSON change on every refresh as well. The fields stay. Still open: F-256*
  in doc/OPEN-ITEMS.md (scroll position to be saved and restored). Step 1: the second start with --start=debug on a running
  system only shows the manager; the debug window was opened with --command=debug
  (the way the guide describes for a running system). Step 2: the table changed
  after the engine was stopped by hand (a crash report was written for each stop).
  Step 6: the dump reached the debug window of a separate test session (m6), which
  was closed afterwards. Step 8: the debug role of session main (PID 21472) ended
  with peer_closed, no "ended unexpectedly" entry. Open point: the hub log shows only
  one "debug gone" entry (17:04:13), so it is not fully clear which debug window it
  belonged to; the window of session main may have been closed earlier than step 8.
```
