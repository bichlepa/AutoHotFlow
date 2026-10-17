# Open Points

Status: 2026-10-16, branch `v2-port`. Findings are carried in the summary table below; closed ones are in `doc/CLOSED-ITEMS.md`.

This document lists everything that is still open, observed, or deferred. History of the early findings (F-0001 to F-0043): tag `v2-phase2-final`, table "Funde" in `v2-phase2-final:work_items/STATUS.md`. The work-item files that this document cites were removed from the working tree; they can be read with `git show v2-phase2-final:<path>`.

Entries marked **(phase 3)** matter for the phase 3 plan.

Closed and accepted findings are in `doc/CLOSED-ITEMS.md`. Entries that wait for the project owner are in `NEEDS-ATTENTION.md` (repository root), not here.

Status words follow the sources: *verified* (read or tested), *assumed* (suspected, not proven), *not checked*. "Read in code" means the source was read but the behavior was not reproduced.

## Summary

Entries that only observe (not for the bug hunter) are in the chapter "Observed only (not for the bug hunter)" below the findings.

| ID | Title | Status | Phase 3 |
|---|---|---|---|
| F-0073 | The stress test with 200 big flows fails its snapshot budget (largest snapshot answer during loading 2326 ms, budget 1000 ms); every flow file is parsed twice in the engine (F-0020 merged in) | budget raised to 3 s (E0042, owner 2026-10-15); stays open as an optimization after the port (pre-filter for inactive flows, one parse instead of two); measurements in WI-0046 | yes |
| F-0101 | Slow tier: `test_start_stop_storm_leaves_a_consistent_engine[smoke]` saw the engine's handle count grow by 19 (limit 5) | observed, red twice in a row and once alone, green since; the same 145 to 164 as F-0092; cause not known; open, watch the history | |
| F-0110 | Foundation tier: `test_a_child_that_says_hello_during_the_shutdown_gets_sys_shutdown_and_the_session_exits_clean[0]` found the storage process still alive after the session ended (the symptom of F-0095) | observed once under load, run 20261016-211715-c03b628b on `c03b628`; not reproduced; the engine's shutdown adds no request to storage in this scenario (the trigger state is not marked); open, watch |  |
| F-0111 | Fast tier: `tests/integration/test_worker.py::test_worker_reports_busy_when_a_job_begins_and_ends` saw `[False, True, False]` as the `sys.busy` values instead of `[True, False]` | observed once (run 20261016-225151-4328, commit a3c0dad plus WI-0063 changes that do not touch workers); not reproduced; open, watch the history | |
| F-0115 | Fast tier: 10 tests of `tests/integration/test_hotkey_input.py` (`@input`) failed in run 20261017-105241-27428 (commit 237441d plus uncommitted test changes, WI-0070 branch): "the probe key vk88 did not arrive although the input desktop is usable and no modifier is held: hotkey path, not the desktop" | cause found: the input desktop was locked (LogonUI.exe) and the `tasklist` output of the LogonUI check could not be decoded (OEM code page); both fixed (91b08a7, cb7bee9, WI-0064); the skip on a real lock screen is not yet seen, see NEEDS-ATTENTION | |
| F-0126 | Import from v1 (WI-0076): the manager's button, its folder dialog, the report window and the two questions are not tested by any automated test (the window module is gui tier, not run by agents); the e2e tests drive the same chain through cmd.test.op | not checked; owner's manual check 6 (`doc/MANUAL-CHECKS.md`, part B) covers them | WI-0076 |
| F-0127 | Import from v1: a v1 shortcut counts as v1 when the target is named `AutoHotFlow.exe` or `AutoHotFlow.ahk` and lies in the imported folder or in a folder with the v1 layout (`Saved Flows` or `Variables`), and is not the running v2 product (F-9103). An installed v1 whose install folder is neither the imported folder nor has that layout is kept, not removed | assumed: the portable layout is what the rule is made for; the installed case is not checked by hand | WI-0076 |
| F-0123 | A trigger that is not available after the user enabled its flow is shown as a dialog (`ManagerWindow._NoticeTrigger`, `UiDialogs.Confirm`), not as a notice; REQ-USE-030 asks for notices (tray or list) for messages without a window of their own | open; the flow is not blocked, but the window waits for a click; the change needs the trigger message routed through the notice path (WI-0075 built it) | WI-0075 |
| F-0124 | `ManagerModel.unseenIds` keeps an entry for a flow that is deleted before the user looks at its error (a tiny leak; the mark is never shown again) | open, found in WI-0075; the entries are small and bounded by the flows deleted in one session | WI-0075 |
| F-0125 | No test provokes a storage-error notice (`Notice_storage`, `Engine._StorageError`) | open, found in WI-0075; the path is built but not checked | WI-0075 |
| F-0114 | Load warnings in the trigger host and in `Trigger_Start_up`: a local `message` (`TriggerHost._CmdArm`, `ReportCallbackError`) and a local `type` (`Trigger_Start_up.Enable`) are reported as the same name as a global variable on every start of the trigger host (seen in the engine and triggerhost logs, WI-0064); the same trap as in `doc/howto/gui-and-hotkeys.md` (case-insensitive names) | observed, not checked whether it changes behaviour; a rename of the locals removes the warnings | |

## Findings

### F-0123: The trigger-not-available message is a dialog, not a notice

**What:** After the user enabled a flow, a trigger that cannot be armed (REQ-MIG-070) is shown with `UiDialogs.Confirm` (`src/manager/ManagerWindow.ahk`, `_NoticeTrigger`). REQ-USE-030 asks that messages without a window of their own reach the user as notices, and WI-0075 built that path (`evt.ui.notice`, the list of notices). The dialog does not block the flows, but it waits for a click and does not appear in the list.
**Status:** open, found in WI-0075; the change is small (send the message as a notice of the manager, or mark the flow), but it changes what the user sees for REQ-MIG-070, so it needs the owner's decision.

### F-0124: The manager's error marks outlive deleted flows

**What:** `ManagerModel.unseenIds` gets an entry for every flow with an unhandled exception that the user has not looked at. A flow that is deleted before that happens keeps its entry (the snapshot does not remove it).
**Status:** open, found in WI-0075; a tiny leak, bounded by the flows deleted in one session. Clean the entry when a flow vanishes from a snapshot.

### F-0125: No test of the storage-error notice

**What:** `Engine._StorageError` sends a notice of kind `storage` (Notice_storage) when the engine is connected. No test makes storage fail that way, so the text and the path are not checked.
**Status:** open, found in WI-0075; the notice path is built, not checked.

### F-0115: Fast tier: hotkey input tests fail when the input desktop is locked

**What:** 10 tests of `tests/integration/test_hotkey_input.py` (`@input`) failed in run 20261017-105241-27428 (commit 237441d plus uncommitted test changes): "the probe key vk88 did not arrive although the input desktop is usable and no modifier is held: hotkey path, not the desktop". A serial rerun at 11:01 skipped all of them ("no input desktop": the desktop was locked or secure).
**Status:** observed once; not reproduced; not checked against a base commit; cause not known. The change of WI-0070 touches the engine trigger path only in a guard (`IsDeleting`). Watch the next fast runs. A locked PC explains the skips (LogonUI was running during the session, verified).

### F-0114: Load warnings in the trigger host and in `Trigger_Start_up`

**What:** A local `message` (`TriggerHost._CmdArm`, `ReportCallbackError`) and a local `type` (`Trigger_Start_up.Enable`) are reported as the same name as a global variable on every start of the trigger host (seen in the engine and triggerhost logs, WI-0064). It is the same trap as in `doc/howto/gui-and-hotkeys.md` (case-insensitive names).
**Status:** observed, not checked whether it changes behaviour. A rename of the locals removes the warnings.

### F-0073: Stress test with 200 big flows: a snapshot answer during the load takes 2.3 s (budget 1 s)

**What:** `tests/stress/test_big_flows.py::test_many_big_flows_load_without_hung_and_with_a_responsive_engine[200]` failed in the stress run of the S0001 acceptance (WI-0043). Everything else in the test held (all 200 flows loaded, no `hung`, `crashed` or `restarted`, no storage error, no snapshot timeout); only the latency check failed: `n=251 median=148.45 p95=543.45 p99=1351.00 max=2325.93` ms against the budget of 1000 ms (`SNAPSHOT_BUDGET_S`, serial run, no scaling). The time until `evt.engine.ready` was 59.35 s.
**Status:** measured in WI-0046 (`doc/MEASUREMENTS.md` MS-0030), open. On a machine with the normal load the budget held in 3 of 4 runs of the plain case (3 runs with hooks and one unhooked run through `run_suite.py`: ready after 52 to 55 s, largest snapshot answer 576, 588 and 668 ms); one run broke it (1511 ms, not explained). Scheduled in S0002 (decision of the project owner, 2026-10-14): S0002 registers classes and so lets the conversion at load grow; WI-0045, WI-0047 and WI-0052 to WI-0056 run this stress test at their end and stop if the budget is broken (`work_items/phase3/README.md`, S0002, "Load path of the engine").
**Evidence:** stress run on the code of WI-0036 to WI-0042 plus the WI-0043 test (commit of the test `1783e67`); 14 other stress tests passed. Earlier measurement of the same test (MEASUREMENTS MS-0019, WI-0024, before phase 3): ready after 45.3 s, largest snapshot answer 506 ms (p99 495 ms, median 194 ms, n=199). So the median is about the same, the tail and the time to ready are worse (+14 s, max about 4.6 times).
**Cause (WI-0046, verified by hooks in the engine, 3 runs per variant):** the conversion is not the cause. With the product classes it costs 0.65 ms per flow (0.13 s of 54 s; 14,925 elements wait for their class). In the worst case after S0002 and S0008 (a stub for every class of the 8 flows, every parameter an expression) it costs 21 to 24 ms per flow on average, 4.3 s in total (about 8 % of the load time), 69 ms at most for one flow; time to ready and the largest snapshot answer stay the same within the spread (53.4 s, 555 to 791 ms). The variable phase is 1.9 s in total (answer handlers 40 ms). The load time is dominated by two parses of the same text: `Message.Parse` of the frame in the engine (about 160 ms per flow, about 32 s of the 52 s, assumed from MS-0020 and the difference to the handler time) and `FlowDefinition.FromText` (91 to 98 ms per flow, 19 s). They run with `LOAD_PARALLEL` = 2, so a ping waits behind up to two answers of about 160 + 100 to 300 ms each; the observed maxima of 0.56 to 0.79 s fit that, the 1.5 s run and the 2.3 s of the S0001 acceptance do not (assumed: load of the machine, not checked). Compared to MS-0019 (45.3 s, 506 ms) the time to ready is 15 to 20 % longer, the maximum about 1.2 times; the cause of this difference is not investigated (S0001 changed the loader and the evaluator; not checked).
**Decision (owner, 2026-10-15, E0042):** the budget is raised to 3 s; the finding stays open as an optimization after the port. The tail is a latency during the start, not a product requirement. Candidate: a conservative pre-filter for "has an enabled trigger" (`"enabled": "1"`, any doubt means parse) run by storage on the raw file text, so inactive flows are parsed on first use only. That saves both parses (frame and `FromText`) for inactive flows. Not checked: where the name for the snapshot would come from without a parse; whether files written by v2 use `true` instead of `"1"`.
**Options if the budget breaks again (for the project owner, none needed for the conversion):** the conversion needs no change (stagger, convert on first use and save converted flows would save at most 4.3 s of 53 s). What would help: a parse of the frame that does not escape the flow text twice (the flow text travels inside a JSON frame), reading flows lazily (the engine is ready before all 200 flows are parsed), or `LOAD_PARALLEL` = 1.
**Merged 2026-10-16:** F-0020 ("Flow file parsed twice in the engine", WI-0024: about 0.23 s per flow, 45 s for 200 flows) has the same cause and is closed in favour of this entry. Its alternatives: send the flow as an object instead of a text inside the frame, chunking, or a native parser.

### F-0101: the storm smoke test sees the engine's handle count grow now and then

**What:** `tests/stress/test_start_stop_storm.py::test_start_stop_storm_leaves_a_consistent_engine[smoke]` failed in the slow tier with the engine's handle count rising from 145 to 164 (limit +5). It failed twice in a row, and once alone; then it was green three times on `9f1d403` and `c27ff8f`, whose code changes do not touch the engine.
**Status:** observed, not reproduced in the green runs; cause not known (assumed: a handle that is released late, not a leak by a code change). Open.
**Action:** watch the history of the test (`python tools/test_history.py --test "tests/stress/test_start_stop_storm.py::test_start_stop_storm_leaves_a_consistent_engine[smoke]"`). If it fails again alone, read the handle types of the engine process in the run log and open a work package; if it fails only under load, add it to the load flakes.
**Evidence:** runs 20261016-172834-c27ff8f4-3 (red) and its recheck at 17:36 (red alone), in the run history of the main checkout.
**Update 2026-10-16 (cleanup of the open items):** green in every run since (6 runs from 17:36 on, run history). The numbers are exactly those of F-0092 (closed): 145 handles before, 164 after, the 19 handles that the first instance of a flow opens once. The churn test was fixed there by a warm-up instance before the baseline; the storm test already has a warm-up of 20 cycles (`WARMUP_CYCLES`) and still saw 145 in the two red runs, so the 19 handles do not always come with the first instance (assumed: something opened lazily, later than the warm-up; not checked). Next step if it fails again: answer the open question of F-0092, which 19 handles these are (handle types of the engine before and after).


### F-0110: storage still alive after a session with a child that says hello during the shutdown

**What:** `tests/fault/test_shutdown.py::test_a_child_that_says_hello_during_the_shutdown_gets_sys_shutdown_and_the_session_exits_clean[0]` failed in the foundation tier: the storage process (started 21:18:10) was still running when the check ran after the session had exited with the expected code. It is the same symptom as F-0095 (storage alive after the end of a session, under load), in a sibling test.
**Status:** observed once (run 20261016-211715-c03b628b, commit `c03b628`, 1 failed of 461). Not reproduced in the same run's other foundation tests. Not caused by WI-0060 as far as the code shows: the engine writes FlowState.json at shutdown only when a switch is pending, which this scenario does not do.
**Action:** watch the history of the test. If it recurs, treat it together with F-0095 (the end of storage after `sys.bye`).
**Evidence:** run 20261016-211715-c03b628b (output of the run, line 43).

### F-0111: the worker busy test sees an extra `sys.busy false` at the start

**What:** `test_worker_reports_busy_when_a_job_begins_and_ends` expects the `sys.busy` values `[True, False]` of one job. It got `[False, True, False]`: a `false` came before the job, most likely the idle report of the worker that started with the fixture, which arrived inside the one-second window of the test.
**Status:** observed once in the fast tier (run 20261016-225151-4328); not reproduced in the next run of the file alone (not repeated on purpose). The worker role was not changed by WI-0063; whether the test or the report is wrong is not checked.
**Action:** watch the history of the test; if it recurs, decide whether the test must skip the idle report or the worker must not send it at start.
**Evidence:** run 20261016-225151-4328 (fast tier, `python -m pytest tests -q`).

### F-0113: Warning of AutoHotkey on stdout from Trigger_Start_up (local `type`) at every load

**What:** AutoHotkey prints `Warning: This local variable has the same name as a global variable. Specifically: type (in function Default.Trigger_Start_up.Enable)` (`src/elements/Default/Triggers/Trigger_Start_up.ahk` line 46) on the output of every test that loads the element classes. It is outside WI-0066 and not a failure.
**Status:** open, not checked whether the engine output shows it in the product (it goes to stdout, not a dialog). The fix is to rename the local (the rule `#Warn` with `StdOut` is in CONVENTIONS section 3).
**Evidence:** the output of `tests/ahk/helpers/element_rate_bench.ahk` and `tests/ahk/engine_runaway.test.ahk` runs.

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
- The report of the import from v1 as the user sees it (window, copy of the text, 225 % scaling): manual check 6 only (F-0126).

What is built and what is not: `doc/REQUIREMENTS-INDEX.md`.

## Open actions

Work that is open but is not a finding with an entry. Rule: a finished action is deleted from this list, not marked as done; its history is in the git log.

1. **Small test gaps of WI-0048 (verifier, `7007f78`).** (a) `Action_Do_nothing` with `executionResult` set to `Exception` has no test; the result `exception` is new behaviour. (b) `ProductRegistersElements` asserts only `Length >= 3`; a test should compare the registry with the element files of `src/elements/*/` (or check that `tools/gen_element_includes.py --check` covers it, not checked). Do it with the next element work, in one small commit.
2. **Distinct code for "flow not loaded yet".** Right after an engine restart `cmd.flow.start` is answered `not_found` while the flows are still loading (from F-0061, closed). A code such as `not_ready` would be clearer. Not decided; the manager of phase 3 follows the resync rule in PROTOCOL 4.8 meanwhile.

## Open decisions

None here. The decisions waiting for the project owner are in `NEEDS-ATTENTION.md` (repository root).

Decisions on entries are in the summary table (status `decision needed`, `accepted`, `closed`) and in the status book `work_items/phase3/STATUS.md`, section "Decisions of the project owner".
