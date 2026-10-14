# Open Points

Status: 2026-10-12, branch `v2-port`, after the fix block WI-30 to WI-35 (acceptance run green, WI-35 cycle 1, code state `2f2e6e5`).

This document lists everything that is still open, observed, or deferred. Of the 45 finding IDs used in the work items (F-01 to F-47; F-34 and F-44 were never assigned), 27 are closed and are not carried over here. Their history is in the tag `v2-phase2-final`, table "Funde" in `v2-phase2-final:work_items/STATUS.md`. The work-item files that this document cites were removed from the working tree; they can be read with `git show v2-phase2-final:<path>`.

The open findings that are observed but not closed are F-45, F-47, the provisional F-48 to F-51 and F-73 and F-74 (2026-10-13, from the test tiers and the manual check). F-36 is closed by the project owner (2026-10-13).

Entries marked **(phase 3)** matter for the phase 3 plan.

Closed and accepted findings are in `doc/CLOSED-ITEMS.md`.

Status words follow the sources: *verified* (read or tested), *assumed* (suspected, not proven), *not checked*. "Read in code" means the source was read but the behavior was not reproduced.

## Summary

| ID | Title | Status | Phase 3 |
|---|---|---|---|
| F-02 | Pipe not ready within 2 s under load | open, observed | |
| F-13 | Unprotected check-then-act spots in the engine | open (counts guarded in ad6ac7d; rest read and found protected) | |
| F-14 | `Ids.Next` and `ExecContext.Finish` not atomic | open, low | yes |
| F-17 | Chatty child gives up during a long supervisor stall | open, reproduced, decision needed (`src/core/`) | |
| F-18 | Hub pipe not restricted to the user | open, low | |
| F-20 | Supervisor messages after `storage` is gone go only to stderr | open, low | |
| F-23 | Flow file parsed twice in the engine | open, not implemented | yes |
| F-35 | Hub connection deadlines ignore supervisor stalls | open, low | |
| F-45 | `refreshed` 2 instead of 3 in the debug role test | observed, open | |
| F-47 | `cmd.worker.cancel` unanswered in the hang test | observed, open | |
| F-48* | `cmd.worker.run` unanswered for 5 s in `test_worker_busy.py` | observed once, open | |
| F-49* | `flow 'wecho' is not loaded` after an engine restart during a worker job | test problem (wait missing), test fixed; product contract note below | yes |
| F-50* | `storage` not ready within 45 s after a freeze in the hang test | observed once under load, open | |
| F-51* | Log line lost while other processes hold the files (`readers-allow-read`) | observed once at `-n 12`, open (stall hypothesis fixed in 2675105, not proven) | |
| F-73* | Closing the debug window is reported as a crash; the supervisor stays up | observed by manual check, open; window-close path works in the test, cause is probably an external close of the role (tray or main window), decision needed on the tray icon | |
| F-74* | Manual-check guide and start tasks do not match | verified, open (owner's agent) | |
| F-85* | A burst of log lines closes the hub's link to `storage` and loses the lines | reproduced, open, decision needed (same fix as F-17) | yes |

* provisional IDs, assigned by the agent on 2026-10-13; the project owner assigns the final ones.

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

### F-17: Chatty child gives up during a long supervisor stall

**What:** A child with high log load can give up during a long stall of the supervisor. The limits are the pipe queue (1000 frames) and the orphan deadline.
**Status:** Open, reproduced, `decision needed` (the fix is in `src/core/`). Priority raised: not only a stall causes it (see F-85).
**Update 2026-10-14 (bug hunter):** Reproduced (verified). Test role `echo`, `cmd.test.log` with 100000 lines in a tight loop, the supervisor suspended with `psutil` 0.2 s after the start of the loop. The role's send queue to the hub reaches 1000 frames, `PipeConnection.SendFrame` closes the connection with `queue_overflow` (`src/core/ipc/PipeConnection.ahk:146-149`), the `Peer` goes to `reconnecting` and cannot reconnect while the hub stands still. Result by the length of the stand-still: 1.5 s: the role reconnects by itself, but its pending request is answered `peer_gone` and most lines are lost (1511 of 100000 logged); 6 s: the guard ends the role after `Role.ORPHAN_MS` (exit 4, "hub not reachable for 3000 ms"), the supervisor logs "ended unexpectedly", writes a crash report and restarts it. A quiet role survives the same 6 s (the existing test `test_supervisor_stand_still_does_not_make_healthy_children_hung`). The cause is that log entries are sent one frame each with no limit in `Role._Enqueue` (`src/core/Role.ahk:213-227`) and an overflow of the queue is fatal for the whole connection, not only for the log line.
**Why it needs a decision:** Options: (a) log entries are droppable: `Role._Enqueue` drops (and counts, as it already does for the offline queue) when the connection's queue is above a soft limit, for example 500 frames, so the queue never reaches the hard limit because of logging; (b) the entries of a burst travel in one frame (`evt.log.append` with a list, a protocol change); (c) a larger `maxQueueFrames` (moves the limit only). Recommended: (a), the smallest change; it needs the owner's agreement because it is in `src/core/`. (a) must also count the loss and write one line "n log lines dropped" when there is room again, as storage does.
**Sign that it matters:** A child exits or restarts after a long freeze of the supervisor while it logs a lot.
**Action:** Decision on (a) to (c). The test `tests/fault/test_log_burst.py::test_a_chatty_role_survives_a_long_stand_still_of_the_supervisor` (slow tier) is `xfail(strict=True)` and fails as expected in 3 of 3 runs on the base commit f0793ce plus the test file (run IDs `20261014-060840-21784`, `20261014-060923-1844`, `20261014-061005-6576`, `-n 0`, machine loaded by other agents). Remove the mark with the fix.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-22-supervisor-robustheit.md`.

### F-18: Hub pipe not restricted to the user

**What:** The hub pipe is not restricted to the Windows user. The option in point 5 of WI-22 was not implemented. The pipe name contains the session and the user.
**Status:** Open, low priority.
**Why deferred:** Low priority. The name contains session and user, but that is not an access control.
**Sign that it matters:** A second Windows user on the same machine can connect. This is not checked (see "Not checked").
**Action:** Implement point 5 of WI-22 if multi-user use matters.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-22-supervisor-robustheit.md`.

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

### F-48*: `cmd.worker.run` unanswered for 5 s in `test_worker_busy.py`

**What:** `test_worker_that_blocks_longer_than_the_pong_timeout_is_not_hung_while_it_has_a_job`: the worker was `ready`, `cmd.worker.run` got no answer within 5 s (`AhfTimeout: no answer to engine#4`).
**Status:** Observed once in about 10 `--all` runs (8 workers), 2026-10-13. Not reproduced in 10 single runs under background load. Supervisor log was empty (no `storage` in that test), so there is no evidence for a cause. Possibly the same family as F-47 (an unanswered request to a worker); not proven. The 5 s default of `ask()` in `test_worker_pool.py` does not go through `scaled()`; that is a suspicion, not a finding.
**Sign that it matters:** the same `AhfTimeout` on `cmd.worker.run`.
**Action:** On the next failure read `diagnosis/snapshot_supervisor.json` (children output, log ring) in the run log. Compare with F-47.
**Evidence:** saved run log `%TEMP%/ahf_testruns_keep/20261013-145541-19344` (failure text only, no diagnosis yet).

### F-49*: `flow 'wecho' is not loaded` after an engine restart during a worker job (phase 3)

**What:** `test_engine_restart_during_a_worker_job_leaves_no_orphan_and_the_next_job_runs` (`tests/fault/test_worker_lifecycle.py`): after the engine restart, starting the flow was answered with `not_found`, "flow 'wecho' is not loaded".
**Status:** Analysed 2026-10-13 (bug hunter). **Test problem, verified by code and a deterministic test; product race ruled out as far as read.** The supervisor sets a child to `ready` at its `sys.hello` (`src/supervisor/Children.ahk:299-308`), which the engine sends at the handshake, before `Role.OnReady` -> `Engine.OnReady` (`src/engine/Engine.ahk:89-94`) starts to wait for storage and load the flows. `evt.engine.ready` is emitted only in `Engine._Loaded` after every file has a result (`src/engine/Engine.ahk:319-334`; PROTOCOL 4.3 line "only after loading the flow list"). Until then `cmd.flow.start` goes to `FlowTable.Require` and is answered `not_found`, "flow 'x' is not loaded" (`src/engine/FlowTable.ahk:23-27`). The test waits for the restart with `chain.wait_restarted_ready` (`tests/fault/faultkit.py:315-323`), which only checks the supervisor state `ready`, then for orphan and warm worker, then starts the flow. The warm worker is started in `OnReady` in parallel with the flow load, so under load the worker can be ready before the flows are loaded. The missing wait is `chain.wait_flows(["wecho"])` (`faultkit.py:325`, snapshot based) after the restart. Not reproduced in 17 serial runs of the test on `702ad61` (0 of 17, machine loaded by other agents), so the original failure itself is not observed again; the window is shown deterministically by `test_f49_restarted_engine_is_ready_for_the_supervisor_before_it_has_loaded_its_flows` (storage frozen, 3 of 3). Test fix: `wait_flows` added in the test and in its sibling `test_engine_killed_during_a_hanging_job...`. Not checked: the saved run log of the original failure (`ahf_testruns_keep` is gone), so that the failure was in fact this window is assumed, not proven.
**Contract note (not a bug):** a client that starts a flow right after an engine restart must wait for `evt.engine.ready` or poll `cmd.engine.snapshot`; the supervisor state `ready` of the engine does not mean "flows loaded". The manager of phase 3 must follow the resync rule in PROTOCOL 4.8 (snapshot after `evt.engine.ready` / `evt.process.restarted`). Open design point: `not_found` during loading is not distinguishable from a real unknown flow; a distinct code (for example `not_ready`) would be clearer. Not decided.
**Sign that it matters:** `not_found` for a flow right after an engine restart in a real session.
**Action:** Read the saved run log (`Log/`, `Reports/`, supervisor snapshot) and the engine start sequence in `Engine.ahk`; decide test or product. Do this before phase 3 builds on the restart behavior.
**Evidence:** saved run log `%TEMP%/ahf_testruns_keep/20261013-151836-20516`.

### F-50*: `storage` not ready within 45 s after a freeze in the hang test

**What:** `test_frozen_storage_is_hung_ended_and_restarted_and_answers_again[0]`: "storage not ready again within 45.0 s".
**Status:** Observed once in about 10 `--all` runs, 2026-10-13, under full load (8 workers, many AHK processes). Not analysed; load is assumed, not proven. The limit already goes through `scaled()`.
**Sign that it matters:** the same message, especially at low load.
**Action:** Read the saved run log (`Reports/`, supervisor log): was `storage` started late, or did it hang a second time?
**Evidence:** saved run log `%TEMP%/ahf_testruns_keep/20261013-152128-3060` (includes the report written at the moment of the failure).

### F-51*: Log line lost while other processes hold the files (`readers-allow-read`)

**What:** `test_no_log_line_is_lost_while_other_processes_hold_the_files[readers-allow-read]` failed once at `-n 12` (more workers than the 8 cores, run took 51 s). The test serial and in 8 more runs passed.
**Status:** Observed once, 2026-10-13. Run log did not exist yet, no evidence kept. Related to F-25 (permanently locked log file loses a batch), not proven.
**Update 2026-10-13 (bug hunter):** Not reproduced: the test passes serially (2 of 2) and I did not create artificial load. The holder keeps the file for about 4 ms out of every 5 ms with `FILE_SHARE_READ` only, so a write attempt finds it free only occasionally; with 100 or more attempts in 3 s a loss needs a long gap between attempts, which is the stall case fixed for F-25 in 2675105 (assumed cause, not proven; no evidence of the original failure exists). If it fails again at normal worker counts after 2675105, the cause is something else: read `Log_storage.txt` in the run log for `log line lost` and its message.
**Sign that it matters:** the failure at normal worker counts, or "lines lost" in a real session.
**Action:** On the next failure read the failure text and `Log/` in the run log.
**Evidence:** none kept.

### F-73*: Closing the debug window is reported as a crash, and the supervisor stays up

**What:** After the manager and the debug window were closed (2 s after start, no quit command sent), the supervisor kept running. Both children were logged as `ended unexpectedly (exited, exit 0)` and a crash report was written, although they exited normally. The manual check step 8 of the debug window expects only the debug process to end, with no "ended unexpectedly" entry and no report.
**Status:** Observed once by the project owner's manual check (2026-10-13). Verified by the logs. The manager part is decided: closing the manager window only hides it, the application keeps running, and only its Exit button or the tray entry ends it (E14, `work_items/phase3/README.md`, S4). So the manager does not count as a defect. The debug part is a defect. Cause in code not analysed.
**Update 2026-10-14 (bug hunter):** Analysed the log of the manual session (`Log/` and `Reports/` of the default data folder, 2026-10-13 19:12:49 to 19:12:51). Verified facts: the supervisor logged no `exit requested` at 19:12:51 (the stub manager's own window close would send `cmd.app.exit` and be logged by `Shutdown`), `debug` and `manager` were `gone (peer_closed)` in the same second, both with exit 0, and both were classified `crashed` (`Children._OnGone`, `voluntary` needs `sys.bye` with `clean`, `src/supervisor/Children.ahk:582`). So the two processes did not end through their own window-close paths: the debug window's close (`DebugGui._OnClose` -> `DebugView.CloseWindow` -> `sys.bye`) is covered by `test_closing_the_window_ends_only_that_role_without_a_crash_and_it_can_be_opened_again` (read, not run by me) and the manager's close would have been logged. What produces exactly this signature was reproduced (verified): a WM_CLOSE to the hidden main window of an AHK script (the same effect has the default tray menu entry "Exit") ends the script with exit 0, no `sys.bye`. Children set no `#NoTrayIcon` and no `A_IconHidden` (grep in `src/`), so every role has a tray icon and a main window that the user, the taskbar group menu or a tool can close. That the owner's windows were closed this way is assumed, not proven (no log of how they were closed). Not reproduced: the owner's exact steps. The earlier text "a defect of the debug part" is therefore not confirmed: the window close of the debug role works as designed in the test.
**Options (nobody decided):** (a) hide the tray icon of all roles (`A_IconHidden := true` in `Role.Start`, or `#NoTrayIcon` in `AhfBoot.ahk`) so the "Exit" entry and the main-window close are not offered; the manager's own tray entry (E14) is added later by the manager. Small, outside `src/core/ipc/`, but `Role` is `src/core/` and needs the owner's agreement. (b) `OnExit` in `Role`: an exit with reason `Close` or `Menu` sends `sys.bye {clean}` first, so the supervisor reports a normal exit; the user then ends single roles by tray, and the supervisor restarts nothing. Not recommended: a role disappearing silently is hard to diagnose. (c) accept: an external close of a role is an unexpected end and the report is correct.
**Sign that it matters:** false crash reports after a normal close of a window.
**Action (revised):** Ask the owner how the two windows were closed in step 8 (X button, taskbar, tray?) and decide (a) to (c). The original action: Fix the exit classification of a normal window close (debug window, and the manager window in S4), and check the quit path. The manual check guide must follow E14 (see F-74).
**Evidence:** `Log_children` of the last manual session (the entries at 19:12:51).

### F-74*: Manual-check guide and start tasks do not match

**What:** The guide `doc/MANUAL-CHECKS.md` (section 1) asks for an empty data folder with `skeleton_flow.json` copied to `Flows\skeleton.json`. The VS Code start task passes no `--data` and no `--session`, so the product uses the default folder `%APPDATA%\AutoHotFlow v2`, which has no skeleton flow. Also, the process tasks print nothing when the application ends, so the end cannot be seen in the task.
**Status:** Verified by reading `doc/MANUAL-CHECKS.md:13-21` and `.vscode/tasks.json` (the manager stub task, lines 533-546). Not checked: the VS Code UI behaviour.
**Action:** The project owner has another agent fix the task and the guide.
**Evidence:** manual check of the project owner, step 2 and step 5.

### F-85*: A burst of log lines closes the hub's link to `storage` and loses the lines (phase 3)

**What:** A role that writes thousands of log lines in a short time (the test role `echo`, `cmd.test.log`, no stand-still involved) overflows the hub's send queue to `storage` (`maxQueueFrames` 1000 frames, `src/core/ipc/PipeConnection.ahk:146-149`). The hub then drops the messages ("'storage' does not accept the message"), the overflow closes the link to storage ("client 'storage' gone (queue_overflow)"), storage is judged hung, a `hung-storage` report is written, and storage is restarted. Pending requests to storage in that time fail, and the log lines of the burst are lost.
**Status:** Reproduced (verified), `decision needed`. Measured with `cmd.test.log` and a tight loop, one run per size: 500, 1000, 1500 and 2000 lines: all lines in `Log.txt`, the link intact. 3000 lines: link closed with `queue_overflow` in 3 of 3 runs, 0 to 979 of 3000 lines in `Log.txt`; 20000 lines: link closed, 0 lines. The threshold lies between 2000 and 3000 lines in a burst; it is not a rate limit (not measured: the sustained rate that overflows). Storage itself already writes in bundles (WI-25), so the file writes are not the bottleneck; storage reads and parses one frame per line, and the hub reads faster than storage consumes (assumed, not measured).
**Why it matters:** phase 3 elements (loops, the engine at level `a1`/`a2`) can log at this rate, and a log burst should never cost the connection of the process that owns the data.
**Options:** (a) the hub treats `evt.log.append` as droppable: when the queue to the target is above a soft limit (for example 800 frames) the message is dropped and counted, with one summary line when there is room again, instead of driving the queue into the hard limit (in `src/supervisor/Hub.ahk`, no core change); (b) the sender batches lines (`evt.log.append` with a list, a protocol change); (c) a larger `maxQueueFrames` for the storage link (moves the limit). Recommended: (a) here and the same idea in `Role._Enqueue` for F-17.
**Action:** Decision. The test `tests/fault/test_log_burst.py::test_a_burst_of_log_lines_does_not_cost_the_storage_link_or_the_lines` (slow tier, 5000 lines) is `xfail(strict=True)` and failed as expected in 3 of 3 runs (run IDs `20261014-060840-21784`, `20261014-060923-1844`, `20261014-061005-6576`, base commit f0793ce plus the test file; with `--runxfail` the failing assert is the `queue_overflow` check). Remove the mark with the fix.
**Evidence:** the runs above; supervisor log of the 3000-line run: 155 "does not accept" lines, `queue_overflow`, "storage ended unexpectedly (hung)".

## Watch list (E7)

These items were deliberately not fixed in phase 2b. Closed items (F-05, F-07, F-11, F-16, F-19 and others) are not listed. The findings above are not repeated here.

- **`deadlineMs` of `sys.shutdown` is not used everywhere.** Only `Storage.OnShutdown` uses it. `Engine.OnShutdown` and `StubManager.OnShutdown` do not. The hard deadline is enforced by the supervisor, which is enough for now. *Sign:* a role needs more cleanup time than the deadline allows, and the supervisor kills it (for example the engine when many instances stop). *Action:* derive a partial deadline per instance (2 s, see `doc/ARCHITECTURE.md` 6.3) in `Engine.OnShutdown`. *Evidence:* `src/engine/Engine.ahk:76`, `src/manager/StubManager.ahk:99`, `src/storage/Storage.ahk:62` (as cited in `v2-phase2-final:work_items/STATUS.md`).
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
- **Parallel runs under load.** F-19 (the time limits) is closed. The remaining risk is F-36, F-45, F-47 and, since 2026-10-13, F-48 to F-51 (see above). The default run (fast tier) showed none of them in about 10 runs; the `--all` run with 8 workers showed one different test in about every second run. A gate with fewer workers (`-n 4`) is not measured yet.
- **Progress checkboxes.** In `v2-phase2-final:work_items/phase2/README.md` the phase 2 checkbox is set. WI-13 and WI-14 were deliberately not checked. WI-17 is checked only after step 7 (phase 3 plan and questions to the owner) is done.
- **Foreign process.** `AutoHotkey64.exe` (PID 29328, `/restart /script ...\src\AutoHotFlow.ahk`) was reported in earlier runs. It was gone on 2026-10-11, and the tests never started or stopped it. *Action:* none; check if it reappears.

## Not checked

- Timing under system load (parallel runs; see F-36, F-45, F-47).
- A second Windows user (relevant to F-18).
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

Work that is open but is not a finding with an entry:

1. **ARCHITECTURE 6.3, F-29.** Write down the orphan rule for a child that never connected: it keeps the 10 s budget of the peer. The project owner accepted F-29 on 2026-10-13 (option (b)); the description is still missing.
2. **Syntax list of the expression language (WI-37).** The owner confirms that `%` as modulo, `^=`, `%=`, `<>` and `"a""b"` stay unsupported (section 15 of `doc/EXPRESSION-LANGUAGE.md`). WI-39 depends on the answer.
3. **`evalparam` in the golden data.** Decision for WI-42: a copy of the function in the harness, or stubs for all callees (see `tests/golden/FINDINGS.md`, "Not covered").
4. **Three `uncaught/timeout` cases** in the groups `assignment` and `script` of the golden check (reported by the verifier, not investigated). Check whether they are the known hangs of the v1 parser.

## Open decisions

Decisions on entries are in the summary table (status `decision needed`, `accepted`, `closed`) and in the status book `work_items/phase3/STATUS.md`, section "Decisions of the project owner". This chapter lists only what is open without an entry:

1. **Hand check of the GUI.** The owner checks the stub and the debug window by hand, using the guides in the "Not checked" section. The phase 2 checkbox for WI-13 stays open until then.
2. **Default working directory of flows (S4).** v2 reads no `settings.json` yet. The v1 default of `FlowWorkingDir` is `A_MyDocuments\AutoHotFlow`; v2 takes it over only if decided in S4. The test profile of a data directory will carry a `settings.json` with `FlowWorkingDir` below the data directory and `UILanguage` `en`. The auxiliary files of the v1 "Automatic tests" become fixtures in `tests/data/workdir/`; WI-43 does not depend on the owner's Documents folder.
