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
| 1 | Start the application (see above). | The stub window opens. No dialog. | |
| 2 | Check the window. | The list shows `skeleton`. The status line shows connection `ready`, `epoch` and `seq`. | |
| 3 | Click `skeleton`, then click Start. | The element list shows the states `running` and `finished` for three elements. The status line shows a command latency. | |
| 4 | During a run, move the window and click Start several times. | The window stays usable. Moving and clicking do not freeze it. | |
| 5 | Quit the application (button Beenden, or close the window). | The process ends with exit code 0. | |
| 6 | Watch for dialogs during the whole check. | No dialog (window class `#32770`) appears. The dialog guard would store one under `%TEMP%\ahf_dialogs\`. | |

**Not covered by these checks** (listed as not checked in the source): the GUI clicks of steps 3 and 4 are not covered by automated tests, so these steps are the only check of them. The labels are ASCII on purpose, so the display of umlauts is not checked. An engine restart while an instance runs is not checked.

## 2. Debug window

Test on the debug window (role `debug`). The source records that the window was checked without a mouse (`PrintWindow` screenshots, `BM_CLICK` on the buttons, `WM_CLOSE` to close), but not with real mouse operation. These steps are the manual check with a real user.

**Start.** Use either:

- VS Code task "Start: product with debug window (--start=storage,engine,debug)", command line `AutoHotFlow.ahk --start=debug`, or
- on a running system, VS Code task "Start: debug window on running instance (--command=debug)", command line `AutoHotFlow.ahk --command=debug`.

### Steps

| # | Step | Expected result | Result |
|---|---|---|---|
| 1 | Start the debug window (see above). | The window "AutoHotFlow - debug" appears. A second `--command=debug` does not open a second window; it brings the existing one to the front. | |
| 2 | Processes tab: look at the table. Then stop one process by hand. | All roles are listed with state and PID. After the process is stopped, the table changes within about one second. | |
| 3 | Snapshots tab: click "Aktualisieren" (Refresh), then select a role in the list. Tick "alle 2 s" and wait. | Formatted JSON is shown. The time at the top of the text keeps running. Scroll and selection positions do not jump; the text is replaced only when it has changed. | |
| 4 | Log tab: change the level filter and the source filter. Wait for new lines. | The list changes at once when a filter changes. New lines appear at the bottom. | |
| 5 | Events tab: start a flow. Click "Pause", then "Weiter". | "Pause" stops the list and shows the text "angehalten bei Nr ... neue Ereignisse wartend". "Weiter" shows all events again. | |
| 6 | Values tab: call `Debug.Dump(Map("a", 1), "test")` in a role (the guide suggests temporarily in the engine). Or run the VS Code task "Debug: trigger Debug.Dump in test role echo:a (ahf_dump.py)". Select the new entry. | The entry appears. The selection shows the JSON. | |
| 7 | Click "Bericht exportieren" (Export report). | The status line names the folder `Reports/<time>_manual`. The folder contains `report.json`, `summary.txt` and `Log.txt`. | |
| 8 | Close the window with X. | Only the debug window process ends. The supervisor log has no "ended unexpectedly" entry. No report is created. | |
| 9 | Watch for dialogs during the whole check. | No dialog appears. The window never blocks the other roles. | |

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
