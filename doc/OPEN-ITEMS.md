# Open Points

Status: 2026-10-12, branch `v2-port`, after the fix block WI-30 to WI-35 (acceptance run green, WI-35 cycle 1, code state `2f2e6e5`).

This document lists everything that is still open, observed, or deferred. Of the 45 finding IDs used in the work items (F-01 to F-47; F-34 and F-44 were never assigned), 27 are closed and are not carried over here. Their history is in the tag `v2-phase2-final`, table "Funde" in `v2-phase2-final:work_items/STATUS.md`. The work-item files that this document cites were removed from the working tree; they can be read with `git show v2-phase2-final:<path>`.

Seven findings are status "observed, open": F-36, F-45, F-47 and the provisional F-48 to F-51 (2026-10-13, found while building the test tiers). None of them is closed. The source recommends closing F-36, but that is a decision of the project owner and has not been made yet.

Entries marked **(phase 3)** matter for the phase 3 plan.

Status words follow the sources: *verified* (read or tested), *assumed* (suspected, not proven), *not checked*. "Read in code" means the source was read but the behavior was not reproduced.

## Summary

| ID | Title | Status | Phase 3 |
|---|---|---|---|
| F-02 | Pipe not ready within 2 s under load | open, observed | |
| F-12 | `Scheduler.Advance` pops before the state change | open, low | |
| F-13 | Unprotected check-then-act spots in the engine | open, observed | |
| F-14 | `Ids.Next` and `ExecContext.Finish` not atomic | open, low | yes |
| F-15 | Engine sends events for a deleted element | accepted | |
| F-17 | Chatty child gives up during a long supervisor stall | open, low | |
| F-18 | Hub pipe not restricted to the user | open, low | |
| F-20 | Supervisor messages after `storage` is gone go only to stderr | open, low | |
| F-23 | Flow file parsed twice in the engine | open, not implemented | yes |
| F-25 | Permanently locked log file loses a whole batch | open, low | |
| F-28 | Worker log entries never reach `storage` | open, low | yes |
| F-29 | Child in handshake is not covered by the orphan guard | open, low | |
| F-30 | Lost `sys.busy {busy: false}` | assumed, open, low | |
| F-35 | Hub connection deadlines ignore supervisor stalls | open, low | |
| F-36 | `sys.hello` unanswered for 15 s in `test_shutdown.py` | observed, open | |
| F-43 | Slow child during shutdown holds later groups | open, decision needed | yes |
| F-45 | `refreshed` 2 instead of 3 in the debug role test | observed, open | |
| F-47 | `cmd.worker.cancel` unanswered in the hang test | observed, open | |
| F-48* | `cmd.worker.run` unanswered for 5 s in `test_worker_busy.py` | observed once, open | |
| F-49* | `flow 'wecho' is not loaded` after an engine restart during a worker job | test problem (wait missing), test fixed; product contract note below | yes |
| F-50* | `storage` not ready within 45 s after a freeze in the hang test | observed once under load, open | |
| F-51* | Log line lost while other processes hold the files (`readers-allow-read`) | observed once at `-n 12`, open | |

* provisional IDs, assigned by the agent on 2026-10-13; the project owner assigns the final ones.

## Findings

### F-02: Pipe not ready within 2 s under load (watch list)

**What:** In the first full test run of phase 2, two supervisor tests failed with "pipe not available after 2.0 s". The cause is assumed to be the load on the test machine.
**Status:** Observed once, open. Cause assumed, not proven. Not reported again in later full runs; the WI-18 final state had 5 parallel full runs with 8 workers and no case.
**Why deferred:** Without a reproduction there is no reliable cause. The item was deliberately left open (E7).
**Sign that it matters:** The message "Pipe nicht verfügbar nach 2,0 s" in a full run, especially in parallel runs.
**Action:** Repeat the run and read the supervisor log of the test (`AHF_TEST_KEEP=1`, see WI-18). Record the cause, then fix it or close the item here.
**Evidence:** `v2-phase2-final:work_items/phase2/WI-13-ui-stub.md`; `v2-phase2-final:work_items/STATUS.md`, table "Funde" and "Beobachtungsliste (E7)".

### F-12: `Scheduler.Advance` pops before the state change

**What:** `Scheduler.Advance` calls `Pop` before `finished -> ready`. With an empty stack (M-14) it throws instead of ending the thread with `exception`.
**Status:** Open, low priority. Read in code.
**Why deferred:** Low priority; the bad case needs an empty stack.
**Sign that it matters:** An unhandled error from `Advance` in the engine log when a stack is empty.
**Action:** Proposal from the source: `Advance` catches the error and ends the thread with `exception`.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-21-engine-korrektheit.md`.

### F-13: Unprotected check-then-act spots in the engine

**What:** Further spots that check and then change state without protection: `Executor._OnFinish`/`_StopRun`, `_ElementStarted`/`_ElementStopped`, and `WorkerBridge`.
**Status:** Open, observed. Read in code, not reproduced.
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
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-21-engine-korrektheit.md`.

### F-15: Engine sends events for a deleted element

**What:** For a deleted element the engine still sends `evt.element.state` (`running`, then `exception`).
**Status:** Observed; deliberately accepted.
**Why deferred:** Clients ignore unknown element IDs, so the decision was to leave it.
**Sign that it matters:** A client that does not ignore unknown element IDs.
**Action:** None planned. Revisit if a client does not ignore unknown IDs.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-21-engine-korrektheit.md`.

### F-17: Chatty child gives up during a long supervisor stall

**What:** A child with high log load can give up during a long stall of the supervisor. The limits are the pipe queue (1000 frames) and the orphan deadline.
**Status:** Open, low priority. Read in code, not tested.
**Why deferred:** Low priority; no test exists.
**Sign that it matters:** A child exits or restarts after a long freeze of the supervisor while it logs a lot.
**Action:** Test a stall with a logging child. Fix it if the case is reproduced.
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

### F-25: Permanently locked log file loses a whole batch

**What:** When another process holds a log file for good, the storage loses the whole batch (up to 500 lines) for that file after 3 s, not only one line.
**Status:** Open, low priority. Counted and noted in the log. F-04 is unchanged.
**Why deferred:** Low priority.
**Sign that it matters:** Missing log lines for one file while another process holds it.
**Action:** Decide whether the loss is acceptable, or change the batch handling.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-25-storage-durchsatz.md`.

### F-28: Worker log entries never reach `storage` (phase 3)

**What:** Log entries of a worker never reach `storage`, because `SetLogTarget` is missing.
**Status:** Open, low priority.
**Why deferred:** It needs a decision on the log route (through the engine, or directly). The source says this becomes relevant with dialog elements in phase 3.
**Sign that it matters:** Missing worker log lines. This becomes important with dialog elements.
**Action:** Decide the log route, then add `SetLogTarget`.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-27-worker-pool.md`.

### F-29: Child in handshake is not covered by the orphan guard

**What:** A child that is still in the handshake is not covered by the orphan guard. It can live up to 10 s after the supervisor has died.
**Status:** Open, low priority. Not described in `doc/ARCHITECTURE.md` 6.3.
**Why deferred:** Low priority.
**Sign that it matters:** A child process still runs up to 10 s after the supervisor is gone.
**Action:** Describe the behavior in `doc/ARCHITECTURE.md` 6.3, or close the gap.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-27-worker-pool.md`.

### F-30: Lost `sys.busy {busy: false}`

**What:** A lost `sys.busy {busy: false}` message leaves the worker shown as busy.
**Status:** Assumed (the source tags it as suspected). Open, low priority.
**Why deferred:** The engine's acceptance deadline of 5 s covers the case.
**Sign that it matters:** A worker shown as busy for more than 5 s.
**Action:** Verify the case if it is seen. Otherwise no action.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-27-worker-pool.md`.

### F-35: Hub connection deadlines ignore supervisor stalls

**What:** Two time-bound spots in the hub connection do not know about a supervisor stall: `PipeConnection.WRITE_GONE_MAX_MS` and the drain deadline of `CloseWhenFlushed`. Both run on the wall clock.
**Status:** Read in code (`src/core/ipc/`), not changed, not observed.
**Why deferred:** Low priority. The effect would be that the connection of a process that is already gone is closed after a resume without the rest of its data (`peer_closed`).
**Sign that it matters:** A connection closed with `peer_closed` after a stall, with data missing.
**Action:** Apply the same stall handling as in WI-33 (`Shift` of the deadline) to these two spots. The change is in `src/core/ipc/` and needs the project owner's agreement.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-33-worker-und-stillstand.md`.

### F-36: `sys.hello` unanswered for 15 s in `test_shutdown.py`

**What:** The observer's `sys.hello` was unanswered for 15 s (`AhfTimeout: no answer to obs#1 within 2.0 s`, then repeated retries in `faultkit.connect`). It happened in `tests/fault/test_shutdown.py` (`test_healthy_session_exits...`, `test_ui_cancels_the_exit...`) when the file ran in parallel with other test files. This is the hub question from WI-23.
**Status:** Observed, open. Verified in 2 of 2 runs with 14 files and 2 of 3 runs with two files, also without the WI-32 changes. Not seen again in 14 acceptance runs (WI-32 and WI-35). The source recommends closing it; the decision is open.
**Why deferred:** The cause was not found. The source suspects a slow machine at that time (assumed, not proven). The failing test's data directory was empty and the supervisor's stderr was empty.
**Sign that it matters:** `AhfTimeout: no answer to obs#1 within 2.0 s` in `faultkit.connect`.
**Action:** The project owner decides whether to close it (recommended). If it comes back: run with `AHF_TEST_KEEP=1`, watch the processes of the session with `psutil` during the hang (state, CPU, threads), and check whether the supervisor's `AutoHotkey64.exe` is running.
**Evidence:** `v2-phase2-final:work_items/STATUS.md`, "Abnahmelauf Fix-Block (2026-10-12)" and "Abnahmelauf WI-35, Zyklus 1 (2026-10-12)"; `v2-phase2-final:work_items/phase2b/WI-32-teststabilitaet-abschluss.md`.

### F-43: Slow child during shutdown holds later groups (phase 3, decision needed)

**What:** A child that starts during shutdown, when its group is reached, holds that group and all later groups until its `sys.hello`. If it starts slower than the deadline (for example a worker under load), `storage` is killed at the deadline without having received `sys.shutdown`. The symptom is like F-41, but rarer.
**Status:** Read in code, not reproduced.
**Why deferred:** The fix changes the order of the shutdown ranks, so the project owner must decide.
**Sign that it matters:** `storage` is force-stopped at the deadline without `sys.shutdown`, under load with workers.
**Action:** Proposal from the source: a child that has never connected does not count as a condition for its group, because it has sent nothing that `storage` must write. The project owner decides; then implement and test.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-34-abnahmefunde.md` (section "Ergebnis").

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
**Status:** Analysed 2026-10-13 (bug hunter, `wip/bug-f49`). **Test problem, verified by code and a deterministic test; product race ruled out as far as read.** The supervisor sets a child to `ready` at its `sys.hello` (`src/supervisor/Children.ahk:299-308`), which the engine sends at the handshake, before `Role.OnReady` -> `Engine.OnReady` (`src/engine/Engine.ahk:89-94`) starts to wait for storage and load the flows. `evt.engine.ready` is emitted only in `Engine._Loaded` after every file has a result (`src/engine/Engine.ahk:319-334`; PROTOCOL 4.3 line "only after loading the flow list"). Until then `cmd.flow.start` goes to `FlowTable.Require` and is answered `not_found`, "flow 'x' is not loaded" (`src/engine/FlowTable.ahk:23-27`). The test waits for the restart with `chain.wait_restarted_ready` (`tests/fault/faultkit.py:315-323`), which only checks the supervisor state `ready`, then for orphan and warm worker, then starts the flow. The warm worker is started in `OnReady` in parallel with the flow load, so under load the worker can be ready before the flows are loaded. The missing wait is `chain.wait_flows(["wecho"])` (`faultkit.py:325`, snapshot based) after the restart. Not reproduced in 17 serial runs of the test on `702ad61` (0 of 17, machine loaded by other agents), so the original failure itself is not observed again; the window is shown deterministically by `test_f49_restarted_engine_is_ready_for_the_supervisor_before_it_has_loaded_its_flows` (storage frozen, 3 of 3). Test fix: `wait_flows` added in the test and in its sibling `test_engine_killed_during_a_hanging_job...`. Not checked: the saved run log of the original failure (`ahf_testruns_keep` is gone), so that the failure was in fact this window is assumed, not proven.
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
**Sign that it matters:** the failure at normal worker counts, or "lines lost" in a real session.
**Action:** On the next failure read the failure text and `Log/` in the run log.
**Evidence:** none kept.

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

## Open decisions

Next step (from the source): write the phase 3 plan with the project owner, then give the approval for phase 3. Phase 3 must not start without this approval.

1. **Closing the manager window (E14, phase 3).** In the stub, closing the window ends the whole application. What the real manager does (close the window only, go to the tray, or quit) is decided in phase 3.
2. **Approval of phase 3 and the phase 3 plan.** `work_items/phase3/README.md` does not exist yet (WI-17, steps 6 and 7). The project owner writes the plan with Claude.
3. **Hand check of the GUI.** The owner checks the stub and the debug window by hand, using the guides in the "Not checked" section. The phase 2 checkbox for WI-13 stays open until then.
4. **F-43.** The owner decides on the proposal (a child that never connected does not count as a condition of its group). Phase 3.
5. **F-36.** Closing is recommended by the source. The decision is open; the item stays "observed, open" until then.
6. **Factor 3 of `scaled()` (E17).** Decided to stay. Observe only.
7. **Settings file and working directory of flows (S4, S2).** v2 reads no `settings.json` yet (`cmd.storage.settings.get/set` is not implemented). When it does: (a) the v1 default of `FlowWorkingDir` is `A_MyDocuments\AutoHotFlow`, the real Documents folder of the user. The default in v2 is decided on purpose, not taken over from v1. (b) The test profile of a data directory always carries a `settings.json` with `FlowWorkingDir` below the data directory and `UILanguage` `en`. (c) The auxiliary files of the v1 "Automatic tests" (text files, ini, shortcuts in `Documents\AutoHotFlow`) become synthetic fixtures in `tests/data/workdir/`; WI-43 must not depend on the owner's Documents folder.

## Sources

All sources are at the tag `v2-phase2-final` and can be read with `git show v2-phase2-final:<path>`:

- `work_items/STATUS.md`: table "Funde", "Beobachtungsliste (E7)", "Bekannte Probleme", "Nicht geprüft", "Nächste Schritte", "Abnahmelauf WI-34", "Abnahmelauf WI-35".
- `work_items/HANDOVER.md`: "Offene Entscheidungen", "Offene Punkte", "Nicht gebaut", "Nicht geprüft".
- The package files `work_items/phase2b/WI-*.md` and `work_items/phase2/WI-*.md` as cited above.
