# Open Points

Status: 2026-10-12, branch `v2-port`, after the fix block WI-30 to WI-35 (acceptance run green, WI-35 cycle 1, code state `2f2e6e5`).

This document lists everything that is still open, observed, or deferred. Of the 45 finding IDs used in the work items (F-01 to F-47; F-34 and F-44 were never assigned), 27 are closed and are not carried over here. Their history is in the tag `v2-phase2-final`, table "Funde" in `v2-phase2-final:work_items/STATUS.md`. The work-item files that this document cites were removed from the working tree; they can be read with `git show v2-phase2-final:<path>`.

The open findings that are observed but not closed are F-45, F-47, F-269 to F-272 and F-273 and F-274 (renumbered on 2026-10-14, see the note below the table; 2026-10-13, from the test tiers and the manual check). F-36 is closed by the project owner (2026-10-13).

Entries marked **(phase 3)** matter for the phase 3 plan.

Closed and accepted findings are in `doc/CLOSED-ITEMS.md`.

Status words follow the sources: *verified* (read or tested), *assumed* (suspected, not proven), *not checked*. "Read in code" means the source was read but the behavior was not reproduced.

## Summary

| ID | Title | Status | Phase 3 |
|---|---|---|---|
| F-02 | Pipe not ready within 2 s under load | open, observed | |
| F-13 | Unprotected check-then-act spots in the engine | open (counts guarded in ad6ac7d; rest read and found protected) | |
| F-14 | `Ids.Next` and `ExecContext.Finish` not atomic | open, low | yes |
| F-20 | Supervisor messages after `storage` is gone go only to stderr | open, low | |
| F-23 | Flow file parsed twice in the engine | open, not implemented | yes |
| F-35 | Hub connection deadlines ignore supervisor stalls | open, low | |
| F-45 | `refreshed` 2 instead of 3 in the debug role test | observed, open | |
| F-47 | `cmd.worker.cancel` unanswered in the hang test | observed, open | |
| F-269 | `cmd.worker.run` unanswered for 5 s in `test_worker_busy.py` | observed once, open | |
| F-270 | `flow 'wecho' is not loaded` after an engine restart during a worker job | test problem (wait missing), test fixed; product contract note below | yes |
| F-271 | `storage` not ready within 45 s after a freeze in the hang test | observed once under load, open | |
| F-272 | Log line lost while other processes hold the files (`readers-allow-read`) | observed once at `-n 12`, open (stall hypothesis fixed in 2675105, not proven) | |
| F-273 | Closing the debug window is reported as a crash; the supervisor stays up | observed by manual check, open; window-close path works in the test, cause is probably an external close of the role (tray or main window), decision needed on the tray icon | |
| F-274 | Manual-check guide and start tasks do not match | verified, open (owner's agent) | |
| F-276 | The F-17 xfail test passes (strict XPASS) in the slow tier | strict mark dropped after a second XPASS (F-278); watch | |
| F-277 | A comparison with an empty or missing variable is true in v1 and false in v2 | verified in the golden data; decided 2026-10-14 (E34): per-flow option `strictTypes`, to implement in WI-42 | yes |
| F-278 | The F-17 xfail test passes again (strict XPASS) in the slow tier, after the F-276 fix | fixed by dropping strict on the F-17 test; watch | |
| F-280 | `test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted[0]` got no `evt.process.crashed` for `worker:1` in the slow tier | observed once, not reproducible in 8 runs, diagnostics added, open | |
| F-281 | `#Warn` dialog for `Engine` in `VarLoader.ahk:101` seen in a manual unit test run | cause established: `VarLoader.ahk` needs `Engine.ahk` in the same script; not reproduced in product or unit test; decision needed | |
| F-282 | The stress test with 200 big flows fails its snapshot budget (largest snapshot answer during loading 2326 ms, budget 1000 ms) | observed once at the S1 acceptance (WI-43); measured in WI-46: the conversion is not the cause (worst case 8 % of the load time), largest snapshot answer 0.56 to 0.79 s in 6 of 7 runs, once 1.5 s; guarded by a stress run at the end of every S2 package on the load path | yes |
| F-284 | A numeric text outside the range of Float (`1e-3001`) is true in a boolean test of AutoHotkey when it is a concatenation result, and false in the evaluator | verified by the expression oracle (one case in 40,000 random cases), open, low, AutoHotkey quirk | |
| F-364 | `cmd.flow.get` returns `flowSettings.strictTypes` as `1`/`0` instead of JSON `true`/`false` | verified (WI-49 test, a file with `true` came back as `1`), open, low | |
| F-374 | `test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms` did not see the job in the snapshot of the worker | observed once in a slow-tier run next to another suite run, 5 of 5 green alone, open | |

* Provisional IDs (with `*`) were renumbered to final IDs on 2026-10-14, at the owner's request. Mapping, old to new: F-48 to F-269, F-49 to F-270, F-50 to F-271, F-51 to F-272, F-73 to F-273, F-74 to F-274, F-85 to F-275, F-125 to F-276, F-105 to F-277, F-165 to F-278, F-235 to F-279, F-236 to F-280, F-255 to F-281, F-268 to F-282, F-72 to F-283 (closed). From now on the orchestrator assigns the final ID before the commit.

## Findings

### F-02: Pipe not ready within 2 s under load (watch list)

**What:** In the first full test run of phase 2, two supervisor tests failed with "pipe not available after 2.0 s". The cause is assumed to be the load on the test machine.
**Status:** Observed once, open. Cause assumed, not proven. Not reported again in later full runs; the WI-18 final state had 5 parallel full runs with 8 workers and no case.
**Why deferred:** Without a reproduction there is no reliable cause. The item was deliberately left open (E7).
**Sign that it matters:** The message "Pipe nicht verfügbar nach 2,0 s" in a full run, especially in parallel runs.
**Action:** Repeat the run and read the supervisor log of the test (`AHF_TEST_KEEP=1`, see WI-18). Record the cause, then fix it or close the item here.
**Evidence:** `v2-phase2-final:work_items/phase2/WI-13-ui-stub.md`; `v2-phase2-final:work_items/STATUS.md`, table "Funde" and "Beobachtungsliste (E7)".

### F-13: Unprotected check-then-act spots in the engine

**What:** Further spots that check and then change state without protection: `Executor._OnFinish`/`_StopRun`, `_ElementStarted`/`_ElementStopped`, and `WorkerBridge`.
**Status:** Open, observed. Read in code, not reproduced.
**Update 2026-10-13 (bug hunter):** Re-read `Executor` and `WorkerBridge` (verified by reading, nothing reproduced). Already protected: `_Advance`, `_DispatchWorker` (register, run, note execId), `_EndRun`, the tick flag, `ThreadState.Dispatch/Finish` (`Critical`). `_OnFinish` and `_StopRun` are safe against a late finish: `_StopRun` puts the threads into `stopping` first, and a `Finish` on such a thread answers `late`, so `_ElementStopped` is not called twice. `WorkerBridge` has no `Critical`, but its callbacks change only the slot list and the job map in short sequences with no sends between the check and the change; `Run` sets slot and job before it sends. One real spot found: `_ElementStarted` and `_ElementStopped` read, changed and stored `_counts` in separate lines; an interrupting dispatch tick for the same element could lose an update, so the count (and the `running` state shown to the UI) would be wrong for ever. Guarded with `Critical` in ad6ac7d. No test: the interruption cannot be forced. `WorkerBridge` stays unprotected on purpose; not proven to be needed. Not checked: stress runs.
**Why deferred:** No failure seen; the source says "beobachten".
**Sign that it matters:** Inconsistent engine state after parallel start and stop of instances.
**Action:** Watch the stress runs. If a case is reproduced, protect the spot (the source suggests `Critical` in phase 3, see F-14).
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-21-engine-korrektheit.md`.

### F-14: `Ids.Next` and `ExecContext.Finish` not atomic (phase 3)

**What:** `Ids.Next` increments and reads the counter in separate lines. `ExecContext.Finish` checks and sets its state in separate steps.
**Status:** Open, low priority. Read in code (`src/core/` and `src/elements/`), not changed.
**Why deferred:** Low risk so far. A change in `src/core/` needs the project owner's agreement.
**Sign that it matters:** Duplicate IDs, or an element that finishes twice.
**Action:** In phase 3, guard both spots with `Critical`, with the agreement of the project owner.
**Update 2026-10-13 (bug hunter):** Re-read, both races are real in principle: AHK v2 may interrupt a thread between lines (timer or message handler), so `Ids.Next` (`src/core/Ids.ahk:22-24`: increment, then read `this.counter`) can return the same number twice if an interrupting call runs in between, and `ExecContext.Finish` (`src/elements/base/ExecContext.ahk:36-40`) can run `onFinish` twice. `Executor._Advance` already uses `Critical` for the same reason (WI-16 seen 2 of about 50 runs). Not reproduced. Smallest fix for `Ids.Next`: read into a local and use `Critical "On"`/restore, or compute `n := ++this.counter` in one expression (still not formally atomic). Not done because it changes `src/core/`; waiting for the owner's agreement.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-21-engine-korrektheit.md`.

### F-20: Supervisor messages after `storage` is gone go only to stderr

**What:** Supervisor messages after `storage` has left (and messages during a supervisor crash) do not go to the log, only to stderr.
**Status:** Open, low priority. Partly covered by the crash report (WI-28).
**Why deferred:** Partly covered already.
**Sign that it matters:** A gap in the log after `storage` has exited.
**Action:** Route these messages to a fallback log, or accept the gap.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-23-diagnose-logpfade.md`.

### F-23: Flow file parsed twice in the engine (phase 3)

**What:** The engine pays twice for each flow file: once for the frame and once for the flow text. The source gives about 0.23 s per flow and 45 s for 200 flows.
**Status:** Open, not implemented. Figures as given in WI-24.
**Why deferred:** The alternatives belong to phase 3: send the flow as an object, chunking, or a native parser.
**Sign that it matters:** Slow start with many flows (for example 200 flows).
**Action:** Choose one alternative in the phase 3 plan.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-24-hub-routing-laden.md`.

### F-35: Hub connection deadlines ignore supervisor stalls

**What:** Two time-bound spots in the hub connection do not know about a supervisor stall: `PipeConnection.WRITE_GONE_MAX_MS` and the drain deadline of `CloseWhenFlushed`. Both run on the wall clock.
**Status:** Read in code (`src/core/ipc/`), not changed, not observed.
**Why deferred:** Low priority. The effect would be that the connection of a process that is already gone is closed after a resume without the rest of its data (`peer_closed`).
**Sign that it matters:** A connection closed with `peer_closed` after a stall, with data missing.
**Action:** Apply the same stall handling as in WI-33 (`Shift` of the deadline) to these two spots. The change is in `src/core/ipc/` and needs the project owner's agreement.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-33-worker-und-stillstand.md`.

### F-45: `refreshed` 2 instead of 3 in the debug role test

**What:** `test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out` failed once in 10 parallel runs (WI-34 acceptance) with `assert 2 == 3`.
**Status:** Observed, open. Not reproduced in the WI-35 cycle 1 (10 parallel runs, 1 serial run, 505 fault runs, 14 stress runs). Cause not verified. The targeted repetition for F-45 is not documented.
**Why deferred:** Not reproduced. The source suspects (assumed) that `DebugView.RefreshSnapshots` asks only the processes the window already sees as `ready`, the same pattern as F-38. The other possibility is that an answer missed `DebugView.SNAPSHOT_MS`.
**Sign that it matters:** `assert 2 == 3` in the test under parallel load.
**Update 2026-10-13:** It failed again in 1 of about 10 `--all` runs (8 workers). The report fetched at the moment of the failure shows supervisor, `storage` and `debug` as `ready` with the late child `starting`, so the process side was in the expected state. Assumed (not proven) cause: the window's own table still showed `storage` or `debug` as not ready, the same lag as in `test_refresh_stores_the_snapshot_of_every_role_and_the_supervisor` (2 of 4 runs, `4 >= 6`). Both tests now wait until the window's table shows the roles as `ready`; 12 further `--all` runs did not show it again. Status: mitigated in the test, cause not proven. If it returns, the lag is in `DebugView` and not in the test.
**Action:** On the next failure, read the run log (`doc/TEST-STRATEGY.md` section 6): `diagnosis/`, `Reports/`, `Log/`.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-35-bugfix-schleife.md` (section "Analyse Zyklus 1"); `v2-phase2-final:work_items/STATUS.md`, "Abnahmelauf WI-34 (2026-10-12, zweiter)" and "Abnahmelauf WI-35, Zyklus 1".

### F-47: `cmd.worker.cancel` unanswered in the hang test

**What:** `test_cancel_of_the_hang_element_reports_stopped_within_500_ms`: `cmd.worker.cancel` was unanswered for 5 s (`AhfTimeout: no answer to engine#3 within 5.0 s`). It happened once in the serial run of WI-34.
**Status:** Observed, open. Not reproduced in 10 single runs (WI-35 cycle 0), in WI-35 cycle 1 (10 parallel, serial, fault 20x, stress). Cause not verified.
**Why deferred:** Not reproduced. It may be the same family as F-37 (which was fixed as a test correction), but this is not proven. The source suspects that an abort is not answered when it hits a hanging element.
**Sign that it matters:** `AhfTimeout: no answer to engine#3 within 5.0 s` at the cancel call.
**Action:** On the next failure, take the snapshot of the worker (`cmd.diag.snapshot`) and run with `AHF_TEST_KEEP=1`.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-35-bugfix-schleife.md`; `v2-phase2-final:work_items/STATUS.md`, "Abnahmelauf WI-34 (2026-10-12, zweiter)" and "Schleife WI-35, Zyklus 0".

### F-269: `cmd.worker.run` unanswered for 5 s in `test_worker_busy.py`

**What:** `test_worker_that_blocks_longer_than_the_pong_timeout_is_not_hung_while_it_has_a_job`: the worker was `ready`, `cmd.worker.run` got no answer within 5 s (`AhfTimeout: no answer to engine#4`).
**Status:** Observed once in about 10 `--all` runs (8 workers), 2026-10-13. Not reproduced in 10 single runs under background load. Supervisor log was empty (no `storage` in that test), so there is no evidence for a cause. Possibly the same family as F-47 (an unanswered request to a worker); not proven. The 5 s default of `ask()` in `test_worker_pool.py` does not go through `scaled()`; that is a suspicion, not a finding.
**Sign that it matters:** the same `AhfTimeout` on `cmd.worker.run`.
**Action:** On the next failure read `diagnosis/snapshot_supervisor.json` (children output, log ring) in the run log. Compare with F-47.
**Evidence:** saved run log `%TEMP%/ahf_testruns_keep/20261013-145541-19344` (failure text only, no diagnosis yet).

### F-270: `flow 'wecho' is not loaded` after an engine restart during a worker job (phase 3)

**What:** `test_engine_restart_during_a_worker_job_leaves_no_orphan_and_the_next_job_runs` (`tests/fault/test_worker_lifecycle.py`): after the engine restart, starting the flow was answered with `not_found`, "flow 'wecho' is not loaded".
**Status:** Analysed 2026-10-13 (bug hunter). **Test problem, verified by code and a deterministic test; product race ruled out as far as read.** The supervisor sets a child to `ready` at its `sys.hello` (`src/supervisor/Children.ahk:299-308`), which the engine sends at the handshake, before `Role.OnReady` -> `Engine.OnReady` (`src/engine/Engine.ahk:89-94`) starts to wait for storage and load the flows. `evt.engine.ready` is emitted only in `Engine._Loaded` after every file has a result (`src/engine/Engine.ahk:319-334`; PROTOCOL 4.3 line "only after loading the flow list"). Until then `cmd.flow.start` goes to `FlowTable.Require` and is answered `not_found`, "flow 'x' is not loaded" (`src/engine/FlowTable.ahk:23-27`). The test waits for the restart with `chain.wait_restarted_ready` (`tests/fault/faultkit.py:315-323`), which only checks the supervisor state `ready`, then for orphan and warm worker, then starts the flow. The warm worker is started in `OnReady` in parallel with the flow load, so under load the worker can be ready before the flows are loaded. The missing wait is `chain.wait_flows(["wecho"])` (`faultkit.py:325`, snapshot based) after the restart. Not reproduced in 17 serial runs of the test on `702ad61` (0 of 17, machine loaded by other agents), so the original failure itself is not observed again; the window is shown deterministically by `test_f49_restarted_engine_is_ready_for_the_supervisor_before_it_has_loaded_its_flows` (storage frozen, 3 of 3). Test fix: `wait_flows` added in the test and in its sibling `test_engine_killed_during_a_hanging_job...`. Not checked: the saved run log of the original failure (`ahf_testruns_keep` is gone), so that the failure was in fact this window is assumed, not proven.
**Contract note (not a bug):** a client that starts a flow right after an engine restart must wait for `evt.engine.ready` or poll `cmd.engine.snapshot`; the supervisor state `ready` of the engine does not mean "flows loaded". The manager of phase 3 must follow the resync rule in PROTOCOL 4.8 (snapshot after `evt.engine.ready` / `evt.process.restarted`). Open design point: `not_found` during loading is not distinguishable from a real unknown flow; a distinct code (for example `not_ready`) would be clearer. Not decided.
**Sign that it matters:** `not_found` for a flow right after an engine restart in a real session.
**Action:** Read the saved run log (`Log/`, `Reports/`, supervisor snapshot) and the engine start sequence in `Engine.ahk`; decide test or product. Do this before phase 3 builds on the restart behavior.
**Evidence:** saved run log `%TEMP%/ahf_testruns_keep/20261013-151836-20516`.

### F-271: `storage` not ready within 45 s after a freeze in the hang test

**What:** `test_frozen_storage_is_hung_ended_and_restarted_and_answers_again[0]`: "storage not ready again within 45.0 s".
**Status:** Observed once in about 10 `--all` runs, 2026-10-13, under full load (8 workers, many AHK processes). Not analysed; load is assumed, not proven. The limit already goes through `scaled()`.
**Sign that it matters:** the same message, especially at low load.
**Action:** Read the saved run log (`Reports/`, supervisor log): was `storage` started late, or did it hang a second time?
**Evidence:** saved run log `%TEMP%/ahf_testruns_keep/20261013-152128-3060` (includes the report written at the moment of the failure).

### F-272: Log line lost while other processes hold the files (`readers-allow-read`)

**What:** `test_no_log_line_is_lost_while_other_processes_hold_the_files[readers-allow-read]` failed once at `-n 12` (more workers than the 8 cores, run took 51 s). The test serial and in 8 more runs passed.
**Status:** Observed once, 2026-10-13. Run log did not exist yet, no evidence kept. Related to F-25 (permanently locked log file loses a batch), not proven.
**Update 2026-10-13 (bug hunter):** Not reproduced: the test passes serially (2 of 2) and I did not create artificial load. The holder keeps the file for about 4 ms out of every 5 ms with `FILE_SHARE_READ` only, so a write attempt finds it free only occasionally; with 100 or more attempts in 3 s a loss needs a long gap between attempts, which is the stall case fixed for F-25 in 2675105 (assumed cause, not proven; no evidence of the original failure exists). If it fails again at normal worker counts after 2675105, the cause is something else: read `Log_storage.txt` in the run log for `log line lost` and its message.
**Sign that it matters:** the failure at normal worker counts, or "lines lost" in a real session.
**Action:** On the next failure read the failure text and `Log/` in the run log.
**Evidence:** none kept.

### F-273: Closing the debug window is reported as a crash, and the supervisor stays up

**What:** After the manager and the debug window were closed (2 s after start, no quit command sent), the supervisor kept running. Both children were logged as `ended unexpectedly (exited, exit 0)` and a crash report was written, although they exited normally. The manual check step 8 of the debug window expects only the debug process to end, with no "ended unexpectedly" entry and no report.
**Status:** Observed once by the project owner's manual check (2026-10-13). Verified by the logs. The manager part is decided: closing the manager window only hides it, the application keeps running, and only its Exit button or the tray entry ends it (E14, `work_items/phase3/README.md`, S4). So the manager does not count as a defect. The debug part is a defect. Cause in code not analysed.
**Update 2026-10-14 (bug hunter):** Analysed the log of the manual session (`Log/` and `Reports/` of the default data folder, 2026-10-13 19:12:49 to 19:12:51). Verified facts: the supervisor logged no `exit requested` at 19:12:51 (the stub manager's own window close would send `cmd.app.exit` and be logged by `Shutdown`), `debug` and `manager` were `gone (peer_closed)` in the same second, both with exit 0, and both were classified `crashed` (`Children._OnGone`, `voluntary` needs `sys.bye` with `clean`, `src/supervisor/Children.ahk:582`). So the two processes did not end through their own window-close paths: the debug window's close (`DebugGui._OnClose` -> `DebugView.CloseWindow` -> `sys.bye`) is covered by `test_closing_the_window_ends_only_that_role_without_a_crash_and_it_can_be_opened_again` (read, not run by me) and the manager's close would have been logged. What produces exactly this signature was reproduced (verified): a WM_CLOSE to the hidden main window of an AHK script (the same effect has the default tray menu entry "Exit") ends the script with exit 0, no `sys.bye`. Children set no `#NoTrayIcon` and no `A_IconHidden` (grep in `src/`), so every role has a tray icon and a main window that the user, the taskbar group menu or a tool can close. That the owner's windows were closed this way is assumed, not proven (no log of how they were closed). Not reproduced: the owner's exact steps. The earlier text "a defect of the debug part" is therefore not confirmed: the window close of the debug role works as designed in the test.
**Options (nobody decided):** (a) hide the tray icon of all roles (`A_IconHidden := true` in `Role.Start`, or `#NoTrayIcon` in `AhfBoot.ahk`) so the "Exit" entry and the main-window close are not offered; the manager's own tray entry (E14) is added later by the manager. Small, outside `src/core/ipc/`, but `Role` is `src/core/` and needs the owner's agreement. (b) `OnExit` in `Role`: an exit with reason `Close` or `Menu` sends `sys.bye {clean}` first, so the supervisor reports a normal exit; the user then ends single roles by tray, and the supervisor restarts nothing. Not recommended: a role disappearing silently is hard to diagnose. (c) accept: an external close of a role is an unexpected end and the report is correct.
**Sign that it matters:** false crash reports after a normal close of a window.
**Action (revised):** Ask the owner how the two windows were closed in step 8 (X button, taskbar, tray?) and decide (a) to (c). The original action: Fix the exit classification of a normal window close (debug window, and the manager window in S4), and check the quit path. The manual check guide must follow E14 (see F-274).
**Evidence:** `Log_children` of the last manual session (the entries at 19:12:51).

### F-274: Manual-check guide and start tasks do not match

**What:** The guide `doc/MANUAL-CHECKS.md` (section 1) asks for an empty data folder with `skeleton_flow.json` copied to `Flows\skeleton.json`. The VS Code start task passes no `--data` and no `--session`, so the product uses the default folder `%APPDATA%\AutoHotFlow v2`, which has no skeleton flow. Also, the process tasks print nothing when the application ends, so the end cannot be seen in the task.
**Status:** Verified by reading `doc/MANUAL-CHECKS.md:13-21` and `.vscode/tasks.json` (the manager stub task, lines 533-546). Not checked: the VS Code UI behaviour.
**Action:** The project owner has another agent fix the task and the guide.
**Evidence:** manual check of the project owner, step 2 and step 5.

### F-276: The F-17 xfail test passes (strict XPASS) in the slow tier

**What:** `tests/fault/test_log_burst.py::test_a_chatty_role_survives_a_long_stand_still_of_the_supervisor` is marked `xfail(strict=True)` (F-17). In the verification run it passed, so the strict mark turned the result into `FAILED` with `[XPASS(strict)] F-17: a chatty role gives up during a long stand-still of the supervisor`. The other test of the file (F-275) was `xfailed` as expected.
**Status:** Fixed in the test (commit `e6bcfdd`), to be watched. The strict XPASS appeared again (F-278), so the strict mark was dropped (commit of this change). The XPASS was seen once and could not be reproduced (verified: 0 XPASS in 12 serial runs and 6 parallel slow-tier runs before the fix, 0 in the runs after it). The cause is assumed.
**Evidence:** run ID `20261014-061730-0506198e`, commit `0506198`, command `python tools/run_suite.py --ref HEAD -- tests -q --all -m slow` (4 workers), exit code 1, `1 failed, 86 passed, 1 xfailed in 144.71s`, no INTERNALERROR. The test took about 22 s. The fast tier of the same commit is green (run ID `20261014-061637-0506198e`, 482 passed).
**Suspicion (assumed):** The test depends on timing: it suspends the supervisor for 6 s while the role logs 100000 lines in a tight loop, and the failure needs the role's send queue to reach 1000 frames before the suspension ends. With 4 parallel workers the role may have finished or be slower than in the serial runs in which the bug hunter reproduced F-17, so the defect does not show. The change under verification (`src/expr/`, `tests/ahk/expr_*`) does not touch `src/core/` or `src/supervisor/`, so it is probably not the cause; the test file itself (commit `28f131a`) is the more likely origin.
**Measurement (bug hunter, base commit `77c38b7`, test file as of `28f131a`):** serial `-n 0 --all -m slow -k stand_still`, 6 runs, all `xfailed`, exit 0 (12 to 21 s each; the last five 12 to 13 s). Slow tier in parallel: 2 runs from the working tree (run logs `20261014-062325-14528`, `20261014-062430-8272`) and 3 frozen runs with `run_suite --with-changes` (`20261014-062546-77c38b72-wc`, `20261014-062748-77c38b72-wc`, `20261014-062946-77c38b72-wc`): all exit 0, `86 passed, 2 xfailed`. So 0 XPASS in 11 runs; the rate is below about 1 in 10, one observation in 12.
**Cause (assumed, not reproduced):** The test waited a fixed 0.2 s after sending the request and assumed the role was inside its loop. If the request reaches the role late (loaded machine, hub busy), the supervisor is suspended before the loop starts; the role then stays quiet during the 6 s, behaves like the healthy children of the existing stand-still test and survives. The product side is consistent with this: `Role._Enqueue` sends each line at once, and `PipeConnection.SendFrame` closes the connection at 1000 queued frames or 8 MB, so once the loop runs against a stopped hub the overflow is certain within milliseconds (verified for the failing case by the F-17 runs, assumed for the timing).
**Fix:** The test waits until the first lines of the burst are in the log file (proof that the loop runs) before it suspends the supervisor, and skips if they do not appear within `scaled(20)` s (no `assert`: xfail would swallow it and hide the missing precondition). After the fix: 6 serial runs `xfailed` (exit 0), slow tier in parallel `86 passed, 2 xfailed` exit 0 (run log `20261014-063319-444`, commit `e6bcfdd`), fast tier `482 passed` exit 0 (`20261014-063423-24212`).
**Action:** Watch. If a strict XPASS appears again, drop `strict` for this test and note the rate in F-17.
### F-277: A comparison with an empty or missing variable is true in v1 and false in v2 (phase 3)

**What:** In v1 `<`, `>`, `<=` and `>=` compare two texts alphabetically when they are not both numbers. An empty text is smaller than every number, so `count < 3` is **true** in v1 while `count` does not exist or is empty. In v2 (E30, AutoHotkey rule) the comparison with a text that is not a number is a type error; by E25 the result is the empty text (false) and a warning. A condition that was true because a counter variable was not set yet is therefore false.
**Status:** Verified in the golden data (`python tools/golden_compare.py --list "text comparison"`): the cases `corpus.expression.1534a539.missing` (`countShuffleTries < 3`, `Condition_Expression`, flow 1210127300, element 54) and `corpus.expression.d4c51cf2.missing` (`myIndex <= 5`, flow 634320780, element 51) give 1 in v1 and the empty text in v2. These are two of 227 distinct expressions of the 22 example flows, both conditions on a counter variable. Not checked: whether the counter is set before the condition in these flows (the golden variants set no variable or a text).
**Why it matters:** E30 accepted the deviation "because it is unlikely in real flows". It does occur in the example flows, in the form "variable not set yet".
**Options:** (a) keep E30: a flow that relies on it must initialise its counters (MIGRATION M-25 says so); (b) the evaluator treats the empty text as 0 in a comparison with a number (a small deviation from AutoHotkey, in `ExprEvaluator`), which gives the v1 result for the empty and the missing variable, though not for a non-numeric text such as `"abc"`.
**Decision (project owner, 2026-10-14, E34):** a per-flow option `strictTypes`. Migrated flows (formatVersion and v1Text marker) get `false`: v1 behaviour, E25 unchanged. New flows get `true`: a type error in a comparison or a calculation becomes an element error (`exception`). The `f1` warnings are shown in the editor in both modes. **Action:** implement in WI-42 (task 7) and in the editor (S4/S5). WI-39 does not change the evaluator.
**Evidence:** the two case IDs above; deviation catalog in `doc/EXPRESSION-LANGUAGE.md` section 15.1 (class "text comparison").

### F-278: The F-17 xfail test passes again (strict XPASS) in the slow tier, after the F-276 fix

**What:** `tests/fault/test_log_burst.py::test_a_chatty_role_survives_a_long_stand_still_of_the_supervisor` is marked `xfail(strict=True)` (F-17). In the slow tier it passed, so the strict mark turned the result into `FAILED` with `[XPASS(strict)] F-17: a chatty role gives up during a long stand-still of the supervisor`. The other test of the file (F-275) was `xfailed` as expected.
**Status:** Fixed by dropping strict on the F-17 test; watch. The same symptom as F-276. The commit under verification already contains the F-276 fix (the test waits for the first lines of the burst, commit `d354ff5`), so that fix did not remove the XPASS, or this is the same rare timing outcome. Not reproduced again, not investigated.
**Evidence:** run ID `20261014-064633-1e444c2d`, commit `1e444c2`, command `python tools/run_suite.py --ref HEAD -- tests -q --all -m slow` (4 workers), exit code 1, `1 failed, 86 passed, 1 xfailed in 130.43s`, no INTERNALERROR. The fast tier (run ID `20261014-064547-1e444c2d`, 514 passed, exit 0) and the foundation tier (run ID `20261014-064848-1e444c2d`, 439 passed, 1 skipped, exit 0) of the same commit are green. The architecture check reports 0 violations.
**Suspicion (assumed):** The change under verification (WI-39: `src/engine/`, `src/expr/`, `src/elements/skeleton/`) does not touch `src/core/` or `src/supervisor/`, so it is probably not the cause. Either the F-276 fix is not enough (the loop runs, but the role's queue still does not reach the limit during the 6 s suspension, for example because the machine is fast), or the F-17 defect depends on timing in a way the test does not control. No second sample, so the rate is unknown.
**Action:** Done: `strict` is dropped for this test (see F-276 and F-17). Watch the result; an XPASS is now reported, not an error. Note the rate in F-17.

### F-280: Killed worker: no `evt.process.crashed` within the budget (slow tier)

**What:** `tests/fault/test_process_crash.py::test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted[0]` failed in the slow tier: after `kill_role(chain, "worker:1")` no `evt.process.crashed` for `worker:1` arrived within `CRASH_BUDGET_S + 5` (`tests/fault/test_process_crash.py:37`). The supervisor text in the assertion message was empty.
**Status:** observed once, **not reproducible** (0 failures in 8 runs on commit `505aceb`, see below). Cause unknown, open (watch list). Test diagnostics improved so the next occurrence can be read.
**Evidence:** commit `2d57395`, command `python tools/run_suite.py --ref HEAD -- tests -q --all -m slow` (4 workers), exit code 1, `1 failed, 85 passed, 2 xfailed in 121.75s`, no INTERNALERROR. The fast tier (`tests -q`) was green, 568 passed.
**Reproduction (verified):** the test is marked `slow`, so it needs `--all -m slow`. 5 serial runs (`run_suite.py --ref 505aceb -- tests/fault/test_process_crash.py -q -n 0 --all -m slow -k killed_worker`): 5 of 5 passed (2.4 to 4.1 s each). 3 runs of the complete slow tier with 4 workers (`run_suite.py --ref 505aceb --workers 4 -- tests -q --all -m slow`): 3 of 3 green (86 passed, 2 xfailed, 111 to 118 s). Failure rate 0 of 8; too few to measure a rare flake.
**Where the chain stops (not known):** the log of the original run is not available, and the assertion text held only the supervisor stderr, which is empty in every healthy run too. So it is not known whether the kill worked, whether the supervisor saw the death, or whether the report was lost.
**Budget (verified by reading):** the wait is `scaled(1.0) + 5` s, i.e. 8 s in a parallel run. The supervisor finds a dead child in its 200 ms tick (`Supervisor.TICK_MS`) and judges the exit at once or after at most `Children.EXIT_GRACE_MS` = 500 ms, so the report is expected within 1 s. A miss of 8 s needs a stall of the supervisor or of the test process of more than 7 s, so "budget too small" alone is unlikely (assumed, not proven). Still open: a tick stall under load (F-271/F-272 class), a lost report, or a test-helper problem (the recorder `chain.rec` missing the event). Not distinguishable without a second occurrence.
**Change:** `kill_role` in `tests/fault/test_process_crash.py` now puts the supervisor view of all roles (`chain.states()`), the last 30 event types and whether the death watcher saw the death into the failure message. On the next failure read that text first: role state `crashed` without the event points to the report path or the recorder; state `ready` points to a missed death (tick stall).
**Original suspicion (assumed):** The changes under verification (`VarAccess.ahk`, `Engine.OnShutdown`, unit tests) do not touch the supervisor, the worker pool start or the crash report, so they are probably not the cause. More likely a timing or load problem in the chain (worker killed while the engine was just starting the element; the supervisor text being empty suggests the log was not yet flushed) or an earlier hint of F-271/F-272 class flakiness. Not checked.

### F-281: `#Warn` warning dialog from the variable loader (manual run)

**What:** During a manual run of a unit test script, the dialog guard caught a `#Warn` warning: "This local variable appears to never be assigned a value. Specifically: Engine", at `src/engine/vars/VarLoader.ahk:101` (`Engine._StorageGone(res)` in the error branch of the load continuation, and the same kind of reference at lines 104 and 106). The dialog report is in the dialog folder of the run (not in the repository).
**Status:** cause established (2026-10-14, bug hunter), no defect in the product or in the test include list; the original dialog is not reproduced. Open, decision needed: close as "not reproducible, by design", or make the file self-contained (options below).
**Evidence (verified by runs through `tools/ahkrun.py`, commit `6589718`):** (1) `tests/ahk/engine_var_files.test.ahk` includes `src/engine/Engine.ahk`, which includes `vars/VarLoader.ahk` and defines `class Engine`; run with a result-file argument it gives 16 passed, 0 failed, no dialog. The include list at the commit of the report (`2c20eff`) is the same. (2) A probe script that includes only `src/engine/vars/VarLoader.ahk` shows exactly the reported `#Warn` dialog (the name `Engine` is not a known global, so AutoHotkey takes it for an unset local). So `VarLoader.ahk` is not self-contained: it uses the class `Engine` (`Engine._StorageGone`, `Engine._ErrorText`, lines 101 to 106) and works only in a script that also includes `Engine.ahk`; that holds for the product and for the unit test. (3) Started without the result-file argument, the unit test opens a different dialog (`TestRun.Init: missing result file argument`), not the `#Warn` one.
**Assumed (not checked):** the manual run of the report used a script or a working-tree state that loaded `VarLoader.ahk` without `Engine.ahk`; the dialog report is gone from the repository, so this cannot be confirmed.
**Options:** (a) close without a change, since no shipped script is affected; (b) add `#Include ..\Engine.ahk` to `VarLoader.ahk` (circular include is harmless, `#Include` is include-once, but the dependency then points from the helper to the class that owns it); (c) move the two static helpers that `VarLoader` uses into a small file both files include. Recommendation: (a).
**Next step:** the owner or orchestrator picks an option.

### F-282: Stress test with 200 big flows: a snapshot answer during the load takes 2.3 s (budget 1 s)

**What:** `tests/stress/test_big_flows.py::test_many_big_flows_load_without_hung_and_with_a_responsive_engine[200]` failed in the stress run of the S1 acceptance (WI-43). Everything else in the test held (all 200 flows loaded, no `hung`, `crashed` or `restarted`, no storage error, no snapshot timeout); only the latency check failed: `n=251 median=148.45 p95=543.45 p99=1351.00 max=2325.93` ms against the budget of 1000 ms (`SNAPSHOT_BUDGET_S`, serial run, no scaling). The time until `evt.engine.ready` was 59.35 s.
**Status:** measured in WI-46 (`doc/MEASUREMENTS.md` M-30), open. On a machine with the normal load the budget held in 3 of 4 runs of the plain case (3 runs with hooks and one unhooked run through `run_suite.py`: ready after 52 to 55 s, largest snapshot answer 576, 588 and 668 ms); one run broke it (1511 ms, not explained). Scheduled in S2 (decision of the project owner, 2026-10-14): S2 registers classes and so lets the conversion at load grow; WI-45, WI-47 and WI-52 to WI-56 run this stress test at their end and stop if the budget is broken (`work_items/phase3/README.md`, S2, "Load path of the engine").
**Evidence:** stress run on the code of WI-36 to WI-42 plus the WI-43 test (commit of the test `1783e67`); 14 other stress tests passed. Earlier measurement of the same test (MEASUREMENTS M-19, WI-24, before phase 3): ready after 45.3 s, largest snapshot answer 506 ms (p99 495 ms, median 194 ms, n=199). So the median is about the same, the tail and the time to ready are worse (+14 s, max about 4.6 times).
**Cause (WI-46, verified by hooks in the engine, 3 runs per variant):** the conversion is not the cause. With the product classes it costs 0.65 ms per flow (0.13 s of 54 s; 14,925 elements wait for their class). In the worst case after S2 and S8 (a stub for every class of the 8 flows, every parameter an expression) it costs 21 to 24 ms per flow on average, 4.3 s in total (about 8 % of the load time), 69 ms at most for one flow; time to ready and the largest snapshot answer stay the same within the spread (53.4 s, 555 to 791 ms). The variable phase is 1.9 s in total (answer handlers 40 ms). The load time is dominated by two parses of the same text: `Message.Parse` of the frame in the engine (about 160 ms per flow, about 32 s of the 52 s, assumed from M-20 and the difference to the handler time) and `FlowDefinition.FromText` (91 to 98 ms per flow, 19 s). They run with `LOAD_PARALLEL` = 2, so a ping waits behind up to two answers of about 160 + 100 to 300 ms each; the observed maxima of 0.56 to 0.79 s fit that, the 1.5 s run and the 2.3 s of the S1 acceptance do not (assumed: load of the machine, not checked). Compared to M-19 (45.3 s, 506 ms) the time to ready is 15 to 20 % longer, the maximum about 1.2 times; the cause of this difference is not investigated (S1 changed the loader and the evaluator; not checked).
**Decision (owner, 2026-10-15, E42):** the budget is raised to 3 s; the finding stays open as an optimization after the port. The tail is a latency during the start, not a product requirement. Candidate: a conservative pre-filter for "has an enabled trigger" (`"enabled": "1"`, any doubt means parse) run by storage on the raw file text, so inactive flows are parsed on first use only. That saves both parses (frame and `FromText`) for inactive flows. Not checked: where the name for the snapshot would come from without a parse; whether files written by v2 use `true` instead of `"1"`.
**Options if the budget breaks again (for the project owner, none needed for the conversion):** the conversion needs no change (stagger, convert on first use and save converted flows would save at most 4.3 s of 53 s). What would help: a parse of the frame that does not escape the flow text twice (the flow text travels inside a JSON frame), reading flows lazily (the engine is ready before all 200 flows are parsed), or `LOAD_PARALLEL` = 1.

### F-284: A temporary text such as `1e-3001` is true in AutoHotkey's `||`, `&&` and `!`, false in the evaluator

**What:** The expression oracle (WI-44) found it with `ftiny . m["k"] || 2147483648 && i1` (`ftiny` is the Float `1e-300`, `m["k"]` is `1`). The concatenation gives the text `1e-3001`, a pure number whose value is outside the range of Float (it underflows to 0). Native AutoHotkey v2 takes this temporary text as true (`||` returns it, `!` gives `0`); the evaluator holds the value in a variable (`left := ...`) and there AutoHotkey takes the same text as false (`||` goes on to the right operand). Checked by hand: a variable that holds the text `1e-3001` is false in `if`, `?:`, `||` and `!`; texts such as `0.0`, `00`, `1e-300` agree on both sides. Only the text out of range differs.
**Status:** verified (run of `python tools/expr_oracle.py --seed 100 --count 40000`, the only deviation without an entry in 40,207 cases; the three probes above). Open, low: it needs a number text with an exponent beyond about 308, which only a concatenation of a tiny or huge Float with more digits makes. Not fixable inside the evaluator without keeping the temporary value out of a variable, which AutoHotkey code cannot do for a value that comes from a recursive call.
**Handling:** the generator of the oracle does not use the Floats `1e-300` and `1e300` as an operand of the concatenation or of a boolean operator, so a random run does not stop at it (`tools/expr_oracle.py`, `pick_var`). A deviation class is not made for it.
**Action:** none unless a real flow shows it. If the evaluator is ever made to follow AutoHotkey for it, the oracle starts to see it again with `ftiny` or `fhuge` in the pool of every operand.

### F-364: `cmd.flow.get` returns `strictTypes` as a number

**What:** A flow file with `"strictTypes": true` is loaded, and `cmd.flow.get` answers with `"strictTypes": 1` (the parser maps `true` to the AutoHotkey number 1 and the definition is sent as it is in `Raw`). The file written by `cmd.flow.save` has `true`/`false` (`ToFileText`), and the protocol rule for truth values (E8) says real JSON booleans on the wire. Other keys of the flow, such as `enabled` of a trigger, are strings in v1 files, so only this key is affected as far as read.
**Status:** verified by the test `tests/integration/test_flowrun.py` (WI-49), which compares the definition with the file it wrote. Open, low: no client reads the key yet. Not checked: whether the wire check of booleans (WI-26) knows this field.
**Action:** decide whether `cmd.flow.get` converts the key back to a boolean (like `ToFileText`), then tighten the test (it accepts `1` now).

### F-374: the cancel test of the worker did not see the job in the snapshot

**What:** In a slow-tier run (`--all -m slow`, 4 workers, a foundation run of the same commit at the same time) `tests/integration/test_worker.py::test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms` failed: "the worker never showed the job in its snapshot", with a snapshot whose `info.job` was empty at an uptime of the worker of 5088 ms. The element (`Action_TestBlockWorker`, 3000 ms) runs for 3 s, so the polling (deadline 5 s, a request every 50 ms) either saw no answer while the job ran, or the job was over before the first answer came. Seen on the commit that added the variable requests of WI-50; that change does not touch this path (the test speaks to the worker directly, the element uses no variable).
**Status:** observed once; 5 of 5 runs of the test alone (serial) green. Cause not investigated (assumed: load, the snapshot answers came late).
**Action:** if it comes back, record the times of the snapshot answers in the failure message (a request takes up to `ROOT_TIMEOUT_S`, which is longer than the element runs).

## Watch list (E7)

These items were deliberately not fixed in phase 2b. Closed items (F-05, F-07, F-11, F-16, F-19 and others) are not listed. The findings above are not repeated here.

- **`deadlineMs` of `sys.shutdown` is not used everywhere.** `Storage.OnShutdown` uses it, and since WI-41 `Engine.OnShutdown` does for the variable writes (the rest of the deadline is the limit of each request); the instances still stop with a fixed 2 s each. `StubManager.OnShutdown` does not. The hard deadline is enforced by the supervisor, which is enough for now. *Sign:* a role needs more cleanup time than the deadline allows, and the supervisor kills it (for example the engine when many instances stop). *Action:* derive a partial deadline per instance (2 s, see `doc/ARCHITECTURE.md` 6.3) in `Engine.OnShutdown`. *Evidence:* `src/engine/Engine.ahk:76`, `src/manager/StubManager.ahk:99`, `src/storage/Storage.ahk:62` (as cited in `v2-phase2-final:work_items/STATUS.md`).
- **`tests/support/pyhub.py` sends no wake-up.** `PyHub` answers only by polling (fallback timer, latency about 250 ms). Only `tests/support/test_client_hub.py` uses it; all other tests use `WakingHub`. *Sign:* a new time-critical test uses `PyHub` and misses a deadline. *Action:* switch to `WakingHub`, or add the wake-up to `PyHub` (see `doc/ARCHITECTURE.md` 2.2).
- **Idle CPU.** The target is met: 0.23 % of the total system (E5). The reading "sum in percent of one core" gives 1.8 %, which misses the target; the reading is still open. A possible improvement is to keep the engine's safety timer (`SAFETY_MS = 100`, `src/engine/Engine.ahk:33`) active only while instances run. *Sign:* idle CPU above 1 % in a measurement with an editor (phase 3). *Action:* re-measure with the WI-16 method after the change.
- **Sporadic dialog test `test_msgbox_is_captured_and_closed`.** One timeout in phase 2 (the ctypes argtypes cause was fixed). In WI-18 two dialog-watcher tests failed under parallel load. The cause is assumed (reused process IDs in the watcher), fixed in `tools/ahf_dialogwatch.py`, and not reproduced. *Sign:* a test exits with 0 instead of 97, or times out. *Action:* read the dialog report in `%TEMP%\ahf_dialogs\` (the file name contains the test PID since WI-18).
- **Deadlines of a role after standby (WI-33).** `Peer.Request` sets each deadline with `SetTimer`. After a standby, all due deadlines of one role fire at once (answer `timeout`, the caller retries). *Status:* not checked; only a freeze of the supervisor was tested (with `psutil`), not a real standby. *Sign:* many `timeout` answers or retries at the same time after wake-up. *Action:* use a deadline list per role, as in `Hub.Tick`/`Hub.Shift`, and measure the stall per role.
- **Empty `--data=` writes to `C:\Log` (E15).** The owner decided that this is acceptable for now. *Sign:* unexpected files in `C:\Log`, or logs missing from the data folder. *Action:* reject an empty value at start (exit 2 with a message). Not rechecked in WI-32; the item comes from the review.
- **Factor 3 of `scaled()` (E17).** The owner decided to keep the factor 3 for parallel runs. Cycle 1 of the WI-35 acceptance neither confirmed nor refuted it: no run showed that it is needed or too loose. *Sign:* a scaled limit fails in parallel runs. *Action:* observe; the decision (E17) stays as it is.

## Known problems still open

- **Test runtime grows.** At the end of phase 2b the run took 113 s in parallel and 596 s serially (706 tests). In WI-35 cycle 1 the parallel runs took 137 to 164 s, the serial run 728 s (752 tests). Each package adds time. *Action:* watch it with each full run.
- **Delete command for a running flow is missing (phase 3).** `Executor.FlowDeleted` stops the instances at once, without a deadline and without an acknowledgment (E9, confirmed by the owner on 2026-10-12). In v1, `DeleteFlow` gave up after 10 s. The command itself is not built yet.
- **Dangling connections.** 154 of 1039 connections in the example flows are dangling. M-13 defines the behavior: ignore them and report them with an `f1` log entry (documented in `doc/MIGRATION.md`).
- **Parallel runs under load.** F-19 (the time limits) is closed. The remaining risk is F-36, F-45, F-47 and, since 2026-10-13, F-269 to F-272 (see above). The default run (fast tier) showed none of them in about 10 runs; the `--all` run with 8 workers showed one different test in about every second run. A gate with fewer workers (`-n 4`) is not measured yet.
- **Progress checkboxes.** In `v2-phase2-final:work_items/phase2/README.md` the phase 2 checkbox is set. WI-13 and WI-14 were deliberately not checked. WI-17 is checked only after step 7 (phase 3 plan and questions to the owner) is done.
- **Foreign process.** `AutoHotkey64.exe` (PID 29328, `/restart /script ...\src\AutoHotFlow.ahk`) was reported in earlier runs. It was gone on 2026-10-11, and the tests never started or stopped it. *Action:* none; check if it reappears.

## Not checked

- Timing under system load (parallel runs; see F-36, F-45, F-47).
- A real second Windows user connecting to the pipe (F-18 is closed on the DACL test only).
- Standby (see the watch list item on deadlines after standby).
- Screenshots with a locked desktop.
- GUI operation of the stub and of the debug window by hand. Guides: `v2-phase2-final:work_items/phase2/WI-13-ui-stub.md` and `v2-phase2-final:work_items/phase2b/WI-28-diagnose-bericht-debugfenster.md`.
- Real blocking dialog elements in a worker.
- Worker pool in a long run with more than 3 workers.
- Trigger host (not built).
- AHK client (editor) as the other side of the latency measurement.
- Idle CPU and memory with a warm worker (not measured again).
- Editor memory with 5 open editors, and redraw time (no editor role yet).

## Not built yet (phase 3 scope)

Editor, real manager, real elements, trigger host (WI-14, decision E6: built early in phase 3), expression evaluation, translations, import and export. `cmd.flow.patch` knows only the schema and the revision check. The delete command for a flow is missing (see above).

## Open actions

Work that is open but is not a finding with an entry. Rule: a finished action is deleted from this list, not marked as done; its history is in the git log.

1. **Three `uncaught/timeout` cases** in the groups `assignment` and `script` of the golden check (reported by the verifier, not investigated). Check whether they are the known hangs of the v1 parser.

## Open decisions

Decisions on entries are in the summary table (status `decision needed`, `accepted`, `closed`) and in the status book `work_items/phase3/STATUS.md`, section "Decisions of the project owner". This chapter lists only what is open without an entry:

1. **Hand check of the GUI.** The owner checks the stub and the debug window by hand, using the guides in the "Not checked" section. The phase 2 checkbox for WI-13 stays open until then.
2. **Default working directory of flows (S4).** v2 reads no `settings.json` yet. The v1 default of `FlowWorkingDir` is `A_MyDocuments\AutoHotFlow`; v2 takes it over only if decided in S4. The test profile of a data directory will carry a `settings.json` with `FlowWorkingDir` below the data directory and `UILanguage` `en`. The auxiliary files of the v1 "Automatic tests" become fixtures in `tests/data/workdir/`; WI-43 does not depend on the owner's Documents folder.
