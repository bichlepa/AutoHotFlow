# Open Points

Status: 2026-10-19, branch `v2-port`. Findings are carried in the summary table below; closed ones are in `doc/CLOSED-ITEMS.md`.

This document lists everything that is still open, observed, or deferred. History of the early findings (F-0001 to F-0043): tag `v2-phase2-final`, table "Funde" in `v2-phase2-final:work_items/STATUS.md`. The work-item files that this document cites were removed from the working tree; they can be read with `git show v2-phase2-final:<path>`.

Entries marked **(phase 3)** matter for the phase 3 plan.

Closed and accepted findings are in `doc/CLOSED-ITEMS.md`. Entries that wait for the project owner are in `NEEDS-ATTENTION.md` (repository root), not here.

Status words follow the sources: *verified* (read or tested), *assumed* (suspected, not proven), *not checked*. "Read in code" means the source was read but the behavior was not reproduced.

## Summary

Entries that only observe (not for the bug hunter) are in the chapter "Observed only (not for the bug hunter)" below the findings.

| ID | Title | Status | Phase 3 |
|---|---|---|---|
| F-0129 | A `.ahf` written by tar.exe is not read by 7-Zip or by v1 in any test (v1 writes a flat ZIP with 7-Zip, tar writes the same layout). Reading a real v1 `.ahf` is tested (`tests/data/ahf/v1_export_two_flows.ahf`) | open, WI-0081; ask the owner for a v1 file of another kind (more flows, statics) | WI-0081 |
| F-0130 | Drag and drop of an `.ahf` file onto the manager and the file dialogs of the import and export are not automated (the gui tier is not run by agents) | open, WI-0081; only MANUAL-CHECKS part D checks them by hand | WI-0081 |
| F-0131 | A name outside the ANSI code page may make the listing of tar fail: the listing is read as text in the ANSI code page, and a failed listing reads as "not a ZIP archive" | open, not reproduced (WI-0081) | WI-0081 |
| F-0132 | UNC paths (`\\server\share\x.ahf`) are refused: the path must start with a drive letter | open decision for the owner | WI-0081 |
| F-0139 | The windows of the log and of the notices are relabelled on a language change (`LogWindow.Relabel`, `NoticeWindow.Relabel`), no test reads their texts; checked by hand only (MANUAL-CHECKS section 8, step 50) | open, verified in code, not checked on screen | WI-0078 |
| F-0133 | The link branch of `ArchiveUnpack._CheckTree` and the link refusal of `ArchiveEntries.CheckListing` have no test (a junction, `mklink /J`, would test the tree check) | open, WI-0081 | WI-0081 |
| F-0134 | The flow JSON of an `.ahf` file is parsed in the manager without a depth limit (the unpacked size is limited to 4 MB, nesting is not): very deep nesting could exhaust the parser | open, not checked, WI-0081 | WI-0081 |
| F-0135 | A second start without elevation cannot reach a running elevated session (WI-0079): the instance mutex of the elevated process is not accessible (access denied), the start ends with exit 1 and a log line about higher rights; the pipe DACL (`PipeListener.SDDL`: system and owner) was not checked for a not elevated client. The second start from the Explorer shows no window and no message to the user | open, found in the design, not run for real (UAC is a manual check, MANUAL-CHECKS 7 step 14); possible fix: a mutex and a pipe that a not elevated process of the user may open | WI-0079 |
| F-0137 | The second start that is denied by an elevated session (F-0135) is silent when it has no console (double click, the shortcut): no window, no notice. A MsgBox is not allowed in the supervisor (no dialog rule), so a tray notice of the elevated session cannot be sent either (it cannot be reached). Possible follow-up: a small message from the failing start through a mechanism outside the supervisor role | open, WI-0079 review | WI-0079 |
| F-0138 | UAC over the shoulder (the administrator account differs from the user) and the working directory of the elevated start are not checked: the elevated process may see another `A_AppData` and `A_Startup`, so the default data folder and the shortcut may differ from the user's. `Run` passes `A_WorkingDir`, relative paths are not tested for real | open, not checked, manual check 7 step 11 | WI-0079 |
| F-0136 | The shortcut of Start with Windows has the icon of the interpreter (no own icon file exists in `assets/`), and the working directory is the folder of the script | open, minor, WI-0079 | WI-0079 |
| F-0141 | The storage and import commands of S0004 have no test that sends them directly | open, low, found in WI-0082 | WI-0082 |
| F-0073 | The stress test with 200 big flows fails its snapshot budget (largest snapshot answer during loading 2326 ms, budget 1000 ms); every flow file is parsed twice in the engine (F-0020 merged in) | budget raised to 3 s (E0042, owner 2026-10-15); stays open as an optimization after the port (pre-filter for inactive flows, one parse instead of two); measurements in WI-0046 | yes |
| F-0111 | Fast tier: `tests/integration/test_worker.py::test_worker_reports_busy_when_a_job_begins_and_ends` saw `[False, True, False]` as the `sys.busy` values instead of `[True, False]` | observed once (run 20261016-225151-4328, commit a3c0dad plus WI-0063 changes that do not touch workers); not reproduced; open, watch the history | |
| F-0126 | Import from v1 (WI-0076): the manager's choice "Import from v1" (button "Import and export"), its folder dialog, the report window and the two questions are not tested by any automated test (the window module is gui tier, not run by agents); the e2e tests drive the same chain through cmd.test.op | not checked; owner's manual check 1 (`doc/MANUAL-CHECKS.md`, part B) covers them | WI-0076 |
| F-0127 | Import from v1: a v1 shortcut counts as v1 when the target is named `AutoHotFlow.exe` or `AutoHotFlow.ahk` and lies in the imported folder or in a folder with the v1 layout (`Saved Flows` or `Variables`), and is not the running v2 product. An installed v1 whose install folder is neither the imported folder nor has that layout is kept, not removed | assumed: the portable layout is what the rule is made for; the installed case is not checked by hand | WI-0076 |
| F-0123 | A trigger that is not available after the user enabled its flow is shown as a dialog (`ManagerWindow._NoticeTrigger`, `UiDialogs.Confirm`), not as a notice; REQ-USE-030 asks for notices (tray or list) for messages without a window of their own | open; the flow is not blocked, but the window waits for a click; the change needs the trigger message routed through the notice path (WI-0075 built it) | WI-0075 |
| F-0124 | `ManagerModel.unseenIds` keeps an entry for a flow that is deleted before the user looks at its error (a tiny leak; the mark is never shown again) | open, found in WI-0075; the entries are small and bounded by the flows deleted in one session | WI-0075 |
| F-0125 | No test provokes a storage-error notice (`Notice_storage`, `Engine._StorageError`) | open, found in WI-0075; the path is built but not checked | WI-0075 |
| F-0114 | Load warnings in the trigger host and in `Trigger_Start_up`: a local `message` (`TriggerHost._CmdArm`, `ReportCallbackError`) and a local `type` (`Trigger_Start_up.Enable`) are reported as the same name as a global variable on every start of the trigger host (seen in the engine and triggerhost logs, WI-0064); the same trap as in `doc/howto/gui-and-hotkeys.md` (case-insensitive names) | observed, not checked whether it changes behaviour; a rename of the locals removes the warnings | |
| F-0118 | The question for an unknown state recognises the refusal by its text ("cannot be read (") instead of an error code | open, assumed; robust option needs an owner decision (`code: state_unknown`) | WI-0074 |
| F-0119 | A multi-selection of flows is not visible in the tree (only the focused item is highlighted) | open, verified in code; the owner decides on a mark | WI-0074 |
| F-0121 | The tree label of a running flow (`ManagerWindow._FlowLabel`) has no automated test | open, verified in code | WI-0074 |
| F-0122 | A multi-selection was lost on a later rebuild of the tree (fixed; no automated test, the path is only reachable through a real tree) | open, verified in code, not checked on screen | WI-0074 |
| F-0145 | The status "planned" of the oldest MIGRATION entries (M-0001 to M-0005, M-0010, M-0012 to M-0014) was never re-checked against the code | open, found in the documentation review; M-0014 is implemented in `LoopStack.Pop` (read) | documentation review |
| F-0146 | The `README.md` in the repository root describes v1 (downloads, installer, `find modules.ahk`, screenshots of v1) while the branch is the v2 port | open, low; rewrite at the end of the port (S0009/S0010) | documentation review |
| F-0148 | A thread of a flow that was just deleted may call `Executor._ElementStopped` after `ForgetFlow` and re-create a run-state record (a small leak and a stale `finished` event) | open, found in the review of WI-0086; read in code, not reproduced; a guard for a flow that is no longer in `flows` would close it | WI-0086 |
| F-0149 | WI-0087 tests: the two tests with a running editor (`test_a_second_edit_of_a_running_flow_starts_no_second_process`, `test_the_editor_limit_refuses_a_new_editor_with_busy`) depend on the manager sending its requests back to back, because the placeholder editor ends within about 200 ms; under heavy load they can fail. Also untested: `FlowIdOk` (quote, control character, trailing backslash, non-text), a clean bye as planned end, a crashed editor not restarted, the slot of a dead editor in the limit. Race: an editor that just died but is not yet judged still counts as running, so `cmd.editor.show` goes nowhere and the click shows nothing (at most 200 ms) | open, found in the review of WI-0087; WI-0088 (a long-lived editor) makes the tests deterministic and can check `ProcessExist` in `OpenEditor` | WI-0087 |
| F-0147 | The GDI leak check of `tests/ahk/gdip.test.ahk` counts only GDI handles (`GetGuiResources`): GDI+ brushes, pens, fonts and paths are not GDI handles, so a missing `GdipDelete*` would not fail it | open, found in the review of WI-0083; the deletes were verified by reading the code | WI-0083 |
| F-9000 | `SceneBuilder.Build` takes about 18 ms for 300 elements (MS-0046), more than the frame of a state change (6 ms): the window builds a new scene at every state change, so a state change costs about 25 ms before it is on the screen. A build that changes only the run states would save it | open, found in the measurement of WI-0085 (MS-0046); decision in WI-0088 | WI-0085 |
| F-9001 | The static layer of the renderer is rebuilt in 152 ms at 3840×2160 (106 ms at 1920×1080) on a change of the flow, the zoom, the DPI or a pan out of the layer, and it takes about 52 MB at 4K: above the 150 ms the owner was to hear about (E0090). Options: a smaller margin, a rebuild in parts over several frames, or a separate process (owner decision) | open, owner decision; measured in MS-0046 | WI-0085 |
| F-9002 | The word "break" in the break field of a loop is a literal in the renderer, not a language text | open, low | WI-0085 |
| F-9003 | The tint of a running element is drawn after all elements, so where a running element overlaps a later element of the scene, the tint lies over that element; v1 draws the tint with its element, so the later element covers it | open, low; the sample flows show no such overlap, not checked on a larger flow | WI-0085 |

## Findings

### F-0129: A `.ahf` written by tar.exe is not read by 7-Zip or by v1

**What:** The export writes the ZIP with `tar.exe --format zip` (WI-0081 spike, decision in the work item). v1 writes the same flat layout with 7-Zip. Nothing in the tests opens a tar archive with 7-Zip or with v1. The owner's real v1 export is read by the tests (`tests/data/ahf/v1_export_two_flows.ahf`), the other direction is not.
**Status:** open, WI-0081. Ask the owner for a v1 file with statics, or a 7-Zip check by hand.

### F-0130: Drop and file dialogs are not automated

**What:** The drop of an `.ahf` file onto the manager window, the save and the open dialog of "Import and export", and the warning and conflict dialogs as shown are checked by hand only (MANUAL-CHECKS part D). The headless tests answer the questions of the chain themselves.
**Status:** open, WI-0081.

### F-0131: Names outside the ANSI code page and the listing of tar

**What:** `ArchiveTar.Text()` reads the listing of tar as text in the default code page. A name with characters outside it may come out wrong, and the entry check then refuses the archive with a text that suggests the file is not a ZIP archive at all.
**Status:** open, not reproduced (no such archive in the tests); the message is misleading in that case.

### F-0132: UNC paths are refused

**What:** `Storage._AhfPath` accepts only paths that start with a drive letter. A file on a network share (`\\server\share\x.ahf`) is refused with a message.
**Status:** open decision for the owner (the rule is simple to relax, but it would need tests on a share).

### F-0133: The link branches have no test

**What:** The refusal of a link in `ArchiveEntries.CheckListing` and in `ArchiveUnpack._CheckTree` is not covered by any test: tar writes no links from our archives, and an archive with a link is not in the tests. A junction (`mklink /J`, no privilege needed) would test the tree check.
**Status:** open, WI-0081.

### F-0134: No depth limit for the JSON of a flow in an archive

**What:** The unpacked size is limited (4 MB, `ArchiveEntries.MAX_UNPACKED_BYTES`), the number of entries (2000) and the file size (50 MB). The JSON parser of the manager has no nesting limit: a flow that nests very deeply could exhaust the recursion of `Json.Parse`. Not measured.
**Status:** open, not checked; a depth check before the parse (a scan of the brackets) or a measurement with a deep file would settle it.

### F-0123: The trigger-not-available message is a dialog, not a notice

**What:** After the user enabled a flow, a trigger that cannot be armed (REQ-MIG-070) is shown with `UiDialogs.Confirm` (`src/manager/ManagerWindow.ahk`, `_NoticeTrigger`). REQ-USE-030 asks that messages without a window of their own reach the user as notices, and WI-0075 built that path (`evt.ui.notice`, the list of notices). The dialog does not block the flows, but it waits for a click and does not appear in the list.
**Status:** open, found in WI-0075; the change is small (send the message as a notice of the manager, or mark the flow), but it changes what the user sees for REQ-MIG-070, so it needs the owner's decision.

### F-0124: The manager's error marks outlive deleted flows

**What:** `ManagerModel.unseenIds` gets an entry for every flow with an unhandled exception that the user has not looked at. A flow that is deleted before that happens keeps its entry (the snapshot does not remove it).
**Status:** open, found in WI-0075; a tiny leak, bounded by the flows deleted in one session. Clean the entry when a flow vanishes from a snapshot.

### F-0125: No test of the storage-error notice

**What:** `Engine._StorageError` sends a notice of kind `storage` (Notice_storage) when the engine is connected. No test makes storage fail that way, so the text and the path are not checked.
**Status:** open, found in WI-0075; the notice path is built, not checked.

### F-0126: The window parts of the import from v1 are not tested automatically

**What:** The manager's choice "Import from v1" (button "Import and export"), its folder dialog, the report window and the two questions of the import (WI-0076) are not covered by an automated test (the window module is gui tier, which agents run only on request). The e2e tests drive the same chain through `cmd.test.op`.
**Status:** not checked; the owner's manual check 1 (`doc/MANUAL-CHECKS.md`, part B) covers them.

### F-0127: The v1 autostart shortcut is recognised by rule, not by the installed v1

**What:** A v1 shortcut counts as v1 when its target is named `AutoHotFlow.exe` or `AutoHotFlow.ahk`, lies in the imported folder or in a folder with the v1 layout (`Saved Flows` or `Variables`), and is not the running v2 product. An installed v1 whose install folder is neither the imported folder nor has that layout is kept, not removed.
**Status:** assumed: the portable layout is what the rule is made for; the installed case is not checked by hand.

### F-0135: A second start without elevation cannot reach an elevated session

**What:** A second start without elevation cannot reach a running elevated session (WI-0079): the instance mutex of the elevated process is not accessible (access denied), the start ends with exit 1 and a log line about higher rights; the pipe DACL (`PipeListener.SDDL`: system and owner) was not checked for a not elevated client. The second start from the Explorer shows no window and no message to the user
**Status:** open, found in the design, not run for real (UAC is a manual check, MANUAL-CHECKS 7 step 14); possible fix: a mutex and a pipe that a not elevated process of the user may open

### F-0136: The shortcut of Start with Windows has the icon of the interpreter

**What:** The shortcut of Start with Windows has the icon of the interpreter (no own icon file exists in `assets/`), and the working directory is the folder of the script
**Status:** open, minor, WI-0079

### F-0137: A denied second start is silent without a console

**What:** The second start that is denied by an elevated session (F-0135) is silent when it has no console (double click, the shortcut): no window, no notice. A MsgBox is not allowed in the supervisor (no dialog rule), so a tray notice of the elevated session cannot be sent either (it cannot be reached). Possible follow-up: a small message from the failing start through a mechanism outside the supervisor role
**Status:** open, WI-0079 review

### F-0138: UAC over the shoulder and the working directory of the elevated start are not checked

**What:** UAC over the shoulder (the administrator account differs from the user) and the working directory of the elevated start are not checked: the elevated process may see another `A_AppData` and `A_Startup`, so the default data folder and the shortcut may differ from the user's. `Run` passes `A_WorkingDir`, relative paths are not tested for real
**Status:** open, not checked, manual check 7 step 11

### F-0141: The storage and import commands of S0004 have no test that sends them directly

**What:** `cmd.storage.ahf.pack/unpack`, `cmd.storage.startup.sync`, `cmd.storage.v1.list/read`, `cmd.import.scan` and `cmd.import.v1.vars` have no test that sends them directly (error answers of bad payloads are not tested); they run only through the manager chain and the supervisor.
**Status:** open, low, found in WI-0082

### F-0114: Load warnings in the trigger host and in `Trigger_Start_up`

**What:** (F-0113 is merged here: the same warning for a local `type` in `Trigger_Start_up.Enable`, seen on stdout of every test that loads the element classes, line 46 of `src/elements/Default/Triggers/Trigger_Start_up.ahk`, outside WI-0066, not a failure.) A local `message` (`TriggerHost._CmdArm`, `ReportCallbackError`) and a local `type` (`Trigger_Start_up.Enable`) are reported as the same name as a global variable on every start of the trigger host (seen in the engine and triggerhost logs, WI-0064). It is the same trap as in `doc/howto/gui-and-hotkeys.md` (case-insensitive names).
**Status:** observed, not checked whether it changes behaviour. A rename of the locals removes the warnings.

### F-0073: Stress test with 200 big flows: a snapshot answer during the load takes 2.3 s (budget 1 s)

**What:** `tests/stress/test_big_flows.py::test_many_big_flows_load_without_hung_and_with_a_responsive_engine[200]` failed in the stress run of the S0001 acceptance (WI-0043). Everything else in the test held (all 200 flows loaded, no `hung`, `crashed` or `restarted`, no storage error, no snapshot timeout); only the latency check failed: `n=251 median=148.45 p95=543.45 p99=1351.00 max=2325.93` ms against the budget of 1000 ms (`SNAPSHOT_BUDGET_S`, serial run, no scaling). The time until `evt.engine.ready` was 59.35 s.
**Status:** measured in WI-0046 (`doc/MEASUREMENTS.md` MS-0030), open. On a machine with the normal load the budget held in 3 of 4 runs of the plain case (3 runs with hooks and one unhooked run through `run_suite.py`: ready after 52 to 55 s, largest snapshot answer 576, 588 and 668 ms); one run broke it (1511 ms, not explained). Scheduled in S0002 (decision of the project owner, 2026-10-14): S0002 registers classes and so lets the conversion at load grow; WI-0045, WI-0047 and WI-0052 to WI-0056 run this stress test at their end and stop if the budget is broken (`work_items/phase3/README.md`, S0002, "Load path of the engine").
**Evidence:** stress run on the code of WI-0036 to WI-0042 plus the WI-0043 test (commit of the test `1783e67`); 14 other stress tests passed. Earlier measurement of the same test (MEASUREMENTS MS-0019, WI-0024, before phase 3): ready after 45.3 s, largest snapshot answer 506 ms (p99 495 ms, median 194 ms, n=199). So the median is about the same, the tail and the time to ready are worse (+14 s, max about 4.6 times).
**Cause (WI-0046, verified by hooks in the engine, 3 runs per variant):** the conversion is not the cause. With the product classes it costs 0.65 ms per flow (0.13 s of 54 s; 14,925 elements wait for their class). In the worst case after S0002 and S0008 (a stub for every class of the 8 flows, every parameter an expression) it costs 21 to 24 ms per flow on average, 4.3 s in total (about 8 % of the load time), 69 ms at most for one flow; time to ready and the largest snapshot answer stay the same within the spread (53.4 s, 555 to 791 ms). The variable phase is 1.9 s in total (answer handlers 40 ms). The load time is dominated by two parses of the same text: `Message.Parse` of the frame in the engine (about 160 ms per flow, about 32 s of the 52 s, assumed from MS-0020 and the difference to the handler time) and `FlowDefinition.FromText` (91 to 98 ms per flow, 19 s). They run with `LOAD_PARALLEL` = 2, so a ping waits behind up to two answers of about 160 + 100 to 300 ms each; the observed maxima of 0.56 to 0.79 s fit that, the 1.5 s run and the 2.3 s of the S0001 acceptance do not (assumed: load of the machine, not checked). Compared to MS-0019 (45.3 s, 506 ms) the time to ready is 15 to 20 % longer, the maximum about 1.2 times; the cause of this difference is not investigated (S0001 changed the loader and the evaluator; not checked).
**Decision (owner, 2026-10-15, E0042):** the budget is raised to 3 s; the finding stays open as an optimization after the port. The tail is a latency during the start, not a product requirement. Candidate: a conservative pre-filter for "has an enabled trigger" (`"enabled": "1"`, any doubt means parse) run by storage on the raw file text, so inactive flows are parsed on first use only. That saves both parses (frame and `FromText`) for inactive flows. Not checked: where the name for the snapshot would come from without a parse; whether files written by v2 use `true` instead of `"1"`.
**Options if the budget breaks again (for the project owner, none needed for the conversion):** the conversion needs no change (stagger, convert on first use and save converted flows would save at most 4.3 s of 53 s). What would help: a parse of the frame that does not escape the flow text twice (the flow text travels inside a JSON frame), reading flows lazily (the engine is ready before all 200 flows are parsed), or `LOAD_PARALLEL` = 1.
**Merged 2026-10-16:** F-0020 ("Flow file parsed twice in the engine", WI-0024: about 0.23 s per flow, 45 s for 200 flows) has the same cause and is closed in favour of this entry. Its alternatives: send the flow as an object instead of a text inside the frame, chunking, or a native parser.

### F-0111: the worker busy test sees an extra `sys.busy false` at the start

**What:** `test_worker_reports_busy_when_a_job_begins_and_ends` expects the `sys.busy` values `[True, False]` of one job. It got `[False, True, False]`: a `false` came before the job, most likely the idle report of the worker that started with the fixture, which arrived inside the one-second window of the test.
**Status:** observed once in the fast tier (run 20261016-225151-4328); not reproduced in the next run of the file alone (not repeated on purpose). The worker role was not changed by WI-0063; whether the test or the report is wrong is not checked.
**Action:** watch the history of the test; if it recurs, decide whether the test must skip the idle report or the worker must not send it at start.
**Evidence:** run 20261016-225151-4328 (fast tier, `python -m pytest tests -q`).

### F-0118: The question for an unknown state recognises the refusal by its text

**What:** The question "write the state of this session to the file?" (E0063, `ManagerOps._AfterSwitch`) is asked when the answer of the engine is `ok: false` with the text "cannot be read (". The engine gives this refusal no error code, so the text is the only mark. A change of the text in `Engine.ahk` would silently remove the question.
**Status:** open, assumed (the test `test_a_switch_refused_for_an_unknown_state_*` in `tests/e2e/test_manager_flows.py` would fail on such a change, but it was not checked against a changed text). Robust option (review, decision needed): `code: state_unknown` in the two refusal replies of `src/engine/Engine.ahk` (`_SwitchOrRead`, `_ReplyRefused`) and documented in PROTOCOL 4.2; the manager then checks the code instead of the text.
**Evidence:** `src/engine/Engine.ahk` (`_ReplyRefused`, `_SwitchOrRead`), `tests/e2e/test_manager_flows.py`.

### F-0119: A multi-selection of flows is not visible in the tree

**What:** The Ctrl click adds flows to the selection that the operations act on (`ManagerModel.selectedSet`). The Windows tree highlights only the focused item, and nothing else marks the other flows of the selection.
**Status:** open, verified in code (no mark is drawn), not checked on screen. Action: the owner decides on a mark (for example a prefix in the text of the item), or a note in the status line with the count.
**Evidence:** `src/manager/ManagerWindow.ahk` (`_OnTreeSelect`), `src/manager/ManagerModel.ahk` (`SelectToggle`).

### F-0121: The tree label of a running flow has no automated test

**What:** The state text of a tree item ("running", "enabled", ...) is built in `ManagerWindow._FlowLabel`. No test reads the text of a tree item: the headless tests read the model, and the gui tests check the structure of the tree only (the item text read with `TVM_GETITEMW` returned 0 in one gui run and the helper was removed).
**Status:** open, verified in code, not checked on screen. Action: a headless check of `_FlowLabel` with a record, or a gui test that reads the item text once `TVM_GETITEMW` is understood.
**Evidence:** `src/manager/ManagerWindow.ahk` (`_FlowLabel`), `tests/fault/test_manager_window.py`.

### F-0122: A multi-selection was lost on a later rebuild of the tree (fixed, no automated test)

**What:** A late `ItemSelect` event of a rebuilt tree called `ManagerModel.Select` and cleared the multi-selection. The fix in `ManagerWindow._OnTreeSelect` skips the event when the focused flow is already the model's selection. The rebuild path is only reachable through a real tree, so no headless test covers the fix.
**Status:** open, verified in code, not checked on screen. Action: a gui test that selects two flows and then creates a category.
**Evidence:** `src/manager/ManagerWindow.ahk` (`_OnTreeSelect`).

### F-0139: The log and notice windows follow a language change without a test (open)

**What:** `LogWindow.Relabel` and `NoticeWindow.Relabel` set the column titles and the drop-down lists again (ManagerWindow.Refresh). No test reads their texts: the headless tests have no window, the gui test covers the settings dialog and the about window only.
**Status:** open, verified in code, not checked on screen. Action: step 50 of MANUAL-CHECKS section 8 by the owner; a gui test later.
**Evidence:** `src/manager/LogWindow.ahk`, `src/manager/NoticeWindow.ahk`, `src/manager/ManagerWindow.ahk` (`Refresh`).

### F-0145: MIGRATION entries from phase 1 still say "planned"

**What:** M-0001 (restart of the engine), M-0002 (dialogs in a worker), M-0004 (errors of elements as exceptions), M-0005 (`storage` is the only log writer), M-0010 (two-phase exit), M-0012 (deadline 2 s for policy `stop`), M-0013 (dangling connections reported) and M-0014 (empty loop stack) have the status `planned` in `doc/MIGRATION.md`. Most of them are built (read: `LoopStack.Pop` throws `AhfError` on an empty stack, `Instance.StopDeadlineMs` is 2000, `LogSink` in storage writes the log), but each needs its test named, as the newer entries have.
**Status:** open, not checked entry by entry. Action: for each entry find the test, then set the status `implemented (WI-..., test ...)` or correct the text. Rule 6 of AGENTS.md: no status without a read or a test.

### F-0146: README.md of the repository is the README of v1

**What:** `README.md` in the root describes v1: the download of the installer, the screenshots in `Documentation/`, `find modules.ahk`. On the branch `v2-port` it is wrong for a visitor.
**Status:** open, low. Write the v2 README at the end of the port (S0009 distribution); until then `AGENTS.md` and `doc/README.md` are the entry points.

### F-0147: GDI+ object leaks are not tested

**What:** the unit test `tests/ahk/gdip.test.ahk` checks that 1000 frames leave the GDI object count of the process unchanged. GDI+ brushes, pens, fonts, paths and images are objects of the GDI+ library, not GDI handles, so a missing `GdipDelete*` stays invisible.
**Status:** open, verified by reading the wrapper (every object has its delete). Option: compare the private bytes of the process over many frames, or count the objects the wrapper creates and deletes.

### F-0148: run-state record of a deleted flow may be re-created

**What:** `StopFlow` is asynchronous. A thread that ends after `ForgetFlow` (flow deleted) calls `_ElementStopped`, which creates a record through `_Elem` again. The record is small, but a stale `finished` event may reach an editor.
**Status:** open, assumed harmless (the storage round trip of a delete comes first), not reproduced. Fix: ignore `_ElementStopped` for a flow that is no longer known.

### F-0149: editor open: tests depend on timing, gaps, a short race

**What:** see the table row. The placeholder editor ends with exit 3 after about 200 ms; the supervisor judges it at its next 200 ms tick.
**Status:** open, verified in code. Next step: WI-0088 gives a long-lived editor; then make the two tests deterministic, add the missing tests, and relaunch or check `ProcessExist` when the show answer is empty.

## Observed only (not for the bug hunter)

Entries that the bug hunter does not take (`doc/ORCHESTRATOR.md` 3c): they were observed once or only under parallel load, were not reproduced when run alone, or are assumed and not checked. Each one has its sign (what to look for in a run) and its action. Hunter-eligible entries stay in the summary table and the findings above.

**Rule (owner, 2026-10-16):** the run history (`python tools/test_history.py --flaky`, `--test <id>`, WI-0059) records every recurrence of a failing test, so an entry here is not needed as a reminder. An entry whose test has passed in several runs since its fix or its observation is closed (moved to `doc/CLOSED-ITEMS.md` with the number of green runs). A recurrence is a new finding that cites the old ID.

None at the moment.

## Watch list (E0007)

These items were deliberately not fixed in phase 2b. Closed items (F-0004, F-0006, F-0010, F-0015, F-0018 and others) are not listed. The findings above are not repeated here.

- **`deadlineMs` of `sys.shutdown` is not used everywhere.** `Storage.OnShutdown` uses it, and since WI-0041 `Engine.OnShutdown` does for the variable writes (the rest of the deadline is the limit of each request); the instances still stop with a fixed 2 s each. `StubManager.OnShutdown` does not. The hard deadline is enforced by the supervisor, which is enough for now. *Sign:* a role needs more cleanup time than the deadline allows, and the supervisor kills it (for example the engine when many instances stop). *Action:* derive a partial deadline per instance (2 s, see `doc/ARCHITECTURE.md` 6.3) in `Engine.OnShutdown`. *Evidence:* `src/engine/Engine.ahk:76`, `src/manager/StubManager.ahk:99`, `src/storage/Storage.ahk:62` (as cited in `v2-phase2-final:work_items/STATUS.md`).
- **`tests/support/pyhub.py` sends no wake-up.** `PyHub` answers only by polling (fallback timer, latency about 250 ms). Only `tests/support/test_client_hub.py` uses it; all other tests use `WakingHub`. *Sign:* a new time-critical test uses `PyHub` and misses a deadline. *Action:* switch to `WakingHub`, or add the wake-up to `PyHub` (see `doc/ARCHITECTURE.md` 2.2).
- **Idle CPU.** The target is met: 0.23 % of the total system (E0005). The reading "sum in percent of one core" gives 1.8 %, which misses the target; the reading is still open. A possible improvement is to keep the engine's safety timer (`SAFETY_MS = 100`, `src/engine/Engine.ahk:33`) active only while instances run. *Sign:* idle CPU above 1 % in a measurement with an editor (phase 3). *Action:* re-measure with the WI-0016 method after the change.
- **Sporadic dialog test `test_msgbox_is_captured_and_closed`.** One timeout in phase 2 (the ctypes argtypes cause was fixed). In WI-0018 two dialog-watcher tests failed under parallel load. The cause is assumed (reused process IDs in the watcher), fixed in `tools/ahf_dialogwatch.py`, and not reproduced. *Sign:* a test exits with 0 instead of 97, or times out. *Action:* read the dialog report in `%TEMP%\ahf_dialogs\` (the file name contains the test PID since WI-0018).
- **Deadlines of a role after standby (WI-0033).** `Peer.Request` sets each deadline with `SetTimer`. After a standby, all due deadlines of one role fire at once (answer `timeout`, the caller retries). *Status:* not checked; only a freeze of the supervisor was tested (with `psutil`), not a real standby. *Sign:* many `timeout` answers or retries at the same time after wake-up. *Action:* use a deadline list per role, as in `Hub.Tick`/`Hub.Shift`, and measure the stall per role.
- **Empty `--data=` writes to `C:\Log` (E0015).** The owner decided that this is acceptable for now. *Sign:* unexpected files in `C:\Log`, or logs missing from the data folder. *Action:* reject an empty value at start (exit 2 with a message). Not rechecked in WI-0032; the item comes from the review.
- **Factor 3 of `scaled()` (E0017).** The owner decided to keep the factor 3 for parallel runs. Cycle 1 of the WI-0035 acceptance neither confirmed nor refuted it: no run showed that it is needed or too loose. *Sign:* a scaled limit fails in parallel runs. *Action:* observe; the decision (E0017) stays as it is.

## Not checked

- A real second Windows user connecting to the pipe (F-0017 is closed on the DACL test only).
- Standby (see the watch list item on deadlines after standby).
- Screenshots with a locked desktop.
- Real blocking dialog elements in a worker.
- Worker pool in a long run with more than 3 workers.
- AHK client (editor) as the other side of the latency measurement.
- Idle CPU and memory with a warm worker (not measured again).
- Editor memory with 5 open editors, and redraw time (no editor role yet).
- The report of the import from v1 as the user sees it (window, copy of the text, 225 % scaling): manual check 1, part B only (F-0126).

What is built and what is not: `doc/REQUIREMENTS-INDEX.md`.

## Open actions

Work that is open but is not a finding with an entry. Rule: a finished action is deleted from this list, not marked as done; its history is in the git log.

1. **Small test gaps of WI-0048 (verifier, `7007f78`).** (a) `Action_Do_nothing` with `executionResult` set to `Exception` has no test; the result `exception` is new behaviour. (b) `ProductRegistersElements` asserts only `Length >= 3`; a test should compare the registry with the element files of `src/elements/*/` (or check that `tools/gen_element_includes.py --check` covers it, not checked). Do it with the next element work, in one small commit.
2. **Distinct code for "flow not loaded yet".** Right after an engine restart `cmd.flow.start` is answered `not_found` while the flows are still loading (from F-0061, closed). A code such as `not_ready` would be clearer. Not decided; the manager of phase 3 follows the resync rule in PROTOCOL 4.8 meanwhile.

## Open decisions

None here. The decisions waiting for the project owner are in `NEEDS-ATTENTION.md` (repository root).

Decisions on entries are in the summary table (status `decision needed`, `accepted`, `closed`) and in the status book `work_items/phase3/STATUS.md`, section "Decisions of the project owner".
