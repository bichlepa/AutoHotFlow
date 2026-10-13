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
| F-12 | `Scheduler.Advance` pops before the state change | closed (fixed in 183c561) | |
| F-13 | Unprotected check-then-act spots in the engine | open (counts guarded in ad6ac7d; rest read and found protected) | |
| F-14 | `Ids.Next` and `ExecContext.Finish` not atomic | open, low | yes |
| F-15 | Engine sends events for a deleted element | accepted | |
| F-17 | Chatty child gives up during a long supervisor stall | open, low | |
| F-18 | Hub pipe not restricted to the user | open, low | |
| F-20 | Supervisor messages after `storage` is gone go only to stderr | open, low | |
| F-23 | Flow file parsed twice in the engine | open, not implemented | yes |
| F-25 | Permanently locked log file loses a whole batch | accepted (owner, 2026-10-13: acceptable risk; stall case fixed in 2675105) | |
| F-28 | Worker log entries never reach `storage` | closed (fixed in 58e48d2) | yes |
| F-29 | Child in handshake is not covered by the orphan guard | accepted (owner, 2026-10-13: low impact; 10 s instead of 3 s, option (b)) | |
| F-30 | Lost `sys.busy {busy: false}` | closed (reconnect case fixed in 4d97c49) | |
| F-35 | Hub connection deadlines ignore supervisor stalls | open, low | |
| F-36 | `sys.hello` unanswered for 15 s in `test_shutdown.py` | closed (owner decision, 2026-10-13) | |
| F-43 | Slow child during shutdown holds later groups | closed (fixed in 72b77e1) | yes |
| F-45 | `refreshed` 2 instead of 3 in the debug role test | observed, open | |
| F-47 | `cmd.worker.cancel` unanswered in the hang test | observed, open | |
| F-48* | `cmd.worker.run` unanswered for 5 s in `test_worker_busy.py` | observed once, open | |
| F-49* | `flow 'wecho' is not loaded` after an engine restart during a worker job | test problem (wait missing), test fixed; product contract note below | yes |
| F-50* | `storage` not ready within 45 s after a freeze in the hang test | observed once under load, open | |
| F-51* | Log line lost while other processes hold the files (`readers-allow-read`) | observed once at `-n 12`, open (stall hypothesis fixed in 2675105, not proven) | |
| F-72* | A second start is silent (forwarded to a running supervisor) | closed (fixed in 10c1f01, interface in d530148) | |
| F-73* | Closing the debug window is reported as a crash; the supervisor stays up | observed by manual check, open (manager part decided by E14) | |
| F-74* | Manual-check guide and start tasks do not match | verified, open (owner's agent) | |

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
**Status:** Closed (2026-10-13), fixed in 183c561. Verified: the effect was worse than an error in the log. `Pop` threw out of `Scheduler.Advance`, out of `Executor._Advance` and `_OnFinish`, into the finish callback of the element; the thread stayed `finished` for ever and the instance never ended (read in code: `Scheduler.Advance`, `Executor._OnFinish`/`_Advance`). Reproduced by the new unit test `Loop: leaving with an empty stack ends the thread as unhandled (F-12)` in `tests/ahk/engine_scheduler.test.ahk`: before the fix `error: AhfError: LoopStack.Pop: loop stack is empty`, after the fix 21 of 21 pass (direct `ahkrun.py` call, no pytest run id). Fix: with `leavesLoop` and an empty stack the thread is released, the outcome is `removed` with `unhandled` true, and the executor logs `f0` with the message `loop stack is empty when leaving loop ...`. This matches M-14 ("thread ends with exception"). Not checked: the pytest fast tier and the engine end-to-end with such a flow (no flow that enters a loop at `tail` exists in the test data).
**Why deferred:** (was) low priority; the bad case needs an empty stack.
**Sign that it matters:** An unhandled error from `Advance` in the engine log when a stack is empty.
**Action:** Proposal from the source: `Advance` catches the error and ends the thread with `exception`.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-21-engine-korrektheit.md`.

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
**Status:** Accepted by the project owner (2026-10-13) as an acceptable risk. Counted and noted in the log. F-04 is unchanged. The stall case was fixed in 2675105 (see update above).
**Update 2026-10-13 (bug hunter):** Analysed with F-51. The retry time of a log operation (`LOG_RETRY_MS` 3 s, `WriteQueue.RunOne`) ran on the wall clock from the first failed attempt. Read in code and shown by a unit test with a fake clock: when the process is stalled for longer than the retry time between two attempts (starved process on a loaded machine, freeze), the first attempt after the stall found the time up and the whole bundle was answered `busy` and reported lost without a further try. Fixed in 2675105 (a gap above 1 s between two attempts is added to the retry time); the new case `a stall does not use up the retry time` in `tests/ahk/storage_queue.test.ahk` fails before and passes after (direct `ahkrun.py` call, 15 of 15 pass), `tests/integration/test_storage.py` 32 passed (run 20261013-180701-17584, commit 2675105 plus uncommitted doc). This is the data-loss path for a stall only; the loss of a batch for a file that is held permanently (the original F-25 point: the batch is lost after 3 s, up to 500 lines) is unchanged and still open as a decision. Not checked: that a real stall caused the original loss.
**Why deferred:** Low priority.
**Sign that it matters:** Missing log lines for one file while another process holds it.
**Action:** Decide whether the loss is acceptable, or change the batch handling.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-25-storage-durchsatz.md`.

### F-28: Worker log entries never reach `storage` (phase 3)

**What:** Log entries of a worker never reach `storage`, because `SetLogTarget` is missing.
**Status:** Closed (2026-10-13), fixed in 58e48d2, see the update.
**Update 2026-10-13 (bug hunter):** Closed. Verified: `Worker` never called `SetLogTarget` (`grep` over `src`: only engine, manager, debug role), so its entries (role messages such as `shutdown requested`, `Log.Write` of elements) stayed in the 500-entry queue and were dropped. The new test `test_log_entries_of_the_worker_reach_storage` (`tests/integration/test_worker.py`) failed before (run 20261013-181219-14824) and passes after; `test_worker.py` and `test_architecture.py` 44 passed (run 20261013-181230-15192), `test_worker_pool.py`, `test_worker_busy.py`, `tests/fault/test_worker_lifecycle.py` 14 passed (run 20261013-181247-8412), all on 58e48d2. Decision taken: the worker logs straight to `storage` in `OnReady`, like the other roles; the alternative (through the engine) adds a hop and a dependency on the engine and was not needed. Not checked: load of a chatty element on `storage`.
**Why deferred:** (was) It needed a decision on the log route (through the engine, or directly). The source says this becomes relevant with dialog elements in phase 3.
**Sign that it matters:** Missing worker log lines. This becomes important with dialog elements.
**Action:** Decide the log route, then add `SetLogTarget`.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-27-worker-pool.md`.

### F-29: Child in handshake is not covered by the orphan guard

**What:** A child that is still in the handshake is not covered by the orphan guard. It can live up to 10 s after the supervisor has died.
**Status:** Accepted by the project owner (2026-10-13): low impact, the 10 s stay (option (b) below). Not yet described in `doc/ARCHITECTURE.md` 6.3; that description is still to be written.
**Update 2026-10-13 (bug hunter):** Cause verified by reading and by one measurement. `Role._Guard` (`src/core/Role.ahk`) starts the orphan clock only when `peer.status = "reconnecting"`; for every other status it resets `lostSince`. A role that has never been welcomed is `connecting` (first attempts) or `handshake`, so the guard does not count. The role then ends by the budget of the peer, not by the guard: `Peer.DEFAULT_RECONNECT_TOTAL_MS` (10 s) for a hub that is not there, and `helloTimeoutMs` (3 s) per attempt plus 3 s guard when the hub accepts the pipe but does not answer. Measured: `python tools/ahkrun.py src/AutoHotFlow.ahk --role=worker --hub=<pipe nobody serves> ...` ends with exit 4 `peer closed (hub_unreachable)` after 10.2 s (direct call, no pytest run id, commit 4d97c49), against about 3 s after a connection that was already ready (`test_role_ends_with_exit_4_when_its_pipe_is_cut_and_the_hub_does_not_come_back`). A supervisor that dies while a child is still starting therefore leaves that child for up to 10 s, not 3 s. A hub that is dead but whose pipe broke after the welcome is covered. Not changed: the fix is in `src/core/` and needs the project owner's agreement.
**Options:** (a) In `Role._Guard` also count `connecting` and `handshake` as lost (clock from the start of the process), so ARCHITECTURE 6.3 point 4 holds without exception; risk: a role started by hand or by a test before its hub (the supervisor creates the hub pipe before it starts children, read, not checked for every test setup) would give up after 3 s instead of 10 s, so such tests must be checked. (b) Keep the 10 s and describe it in ARCHITECTURE 6.3 ("a role that has not yet connected waits up to 10 s"). (c) Lower `reconnectTotalMs` for the first connect only. Recommendation: (a) with a test that starts a role without a hub and expects exit 4 within `ORPHAN_BUDGET_S`; low priority, the effect is a stray process for a few seconds.
**Why deferred:** Low priority.
**Sign that it matters:** A child process still runs up to 10 s after the supervisor is gone.
**Action:** Describe the behavior in `doc/ARCHITECTURE.md` 6.3, or close the gap.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-27-worker-pool.md`.

### F-30: Lost `sys.busy {busy: false}`

**What:** A lost `sys.busy {busy: false}` message leaves the worker shown as busy.
**Status:** Closed (2026-10-13) for the case that can be shown, fixed in 4d97c49, see the update. Before: assumed, low priority.
**Update 2026-10-13 (bug hunter):** Verified by reading and by a test. `Peer.Send` drops a message without a trace while the peer is not `ready` (`droppedSends`, `src/core/ipc/Peer.ahk`). `Worker.OnReady` announced the busy state only for a running job (`true`), never `false`. If the link broke during a job and the job ended in the gap, `sys.busy {busy:false}` was dropped, the reconnect announced nothing, and the supervisor kept the worker as busy for ever: `Children.OnLinkLost` resets nothing, `OnHello` ignores a child that is not `starting` and `Heartbeat.Tick` skips a busy child. Effect: an idle worker that later hangs is never detected, and the process is not ended as hung. The engine's 5 s acceptance deadline does not cover this (it concerns the job, not the heartbeat). Fix: `Worker.OnReady` always announces the current state (`true` or `false`). The new test `test_worker_announces_its_busy_state_again_after_it_rebuilt_the_connection` (`tests/fault/test_pipe_break.py`, stand-in hub, link cut by the hub) fails before (`['hello', 'hello']`, run 20261013-183502-13236) and passes after (run 20261013-183508-7492, commit 4d97c49 plus the test). `test_worker.py` and `test_architecture.py` 44 passed (run 20261013-183521-20328). Decision taken: fix in the worker, not in the supervisor; the alternative (reset `busy` when the child's link is lost or on a new hello) would also cover a worker that dies in the gap, but a worker that is still running a job would then be pinged until its `true` arrives. Not checked: the exact race (job end inside the gap) is not forced, the test checks the announcement after a reconnect; the engine does not receive the lost `evt.worker.done` either (a separate matter: the slot is released by the engine's own deadlines, read in `WorkerBridge`, not tested).
**Why deferred:** (was) The engine's acceptance deadline of 5 s was thought to cover the case; it does not.
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
**Status:** Observed, open. Verified in 2 of 2 runs with 14 files and 2 of 3 runs with two files, also without the WI-32 changes. Not seen again in 14 acceptance runs (WI-32 and WI-35). The project owner decided to close it (2026-10-13).
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
**Update 2026-10-13 (bug hunter), explanation and recommendation. Status stays: decision needed.**
**What happens, in plain words.** The supervisor ends the session group by group, by rank: 0 UI (manager, editor, debug), 1 engine, 2 triggerhost, 3 everything else (workers), 4 storage (`Children._RankOf`, `ShutdownGroups`). Storage is last on purpose: it must still be there while the others hand over their data. A group counts as done only when each of its children has said `sys.bye` or has ended (`Children.GroupDone`: `!bye && !gone` blocks). A child that was started shortly before the exit and has not yet said `sys.hello` (state `starting`) is alive, so it is in its group (`ShutdownGroups` takes everything that is not `gone`). It cannot be reached (`SendShutdown` only sends; it has no link), so it cannot say `bye`, and its group stays open. The groups behind it, in the worst case `storage`, are never started (`Shutdown.Tick`: the loop only goes on when `GroupDone`). If the child's hello comes in time, `Shutdown.OnHello` (the F-41 fix) sends it `sys.shutdown` and everything goes on; the exit is only delayed. If the hello comes after the deadline, `Shutdown._Force` terminates all living children, `storage` among them, which never got `sys.shutdown`. Exit code 5, and `storage` is `clean: false`.
**When and how it would show.** Only when the exit starts while a child is still starting, and the child needs longer than the deadline (default 5 s) for its hello. Candidates: the warm worker after a start or after a worker was ended, an editor just opened, the debug window; on a slow or loaded machine (start is about 30 ms when idle, `doc/MEASUREMENTS.md`, so it needs heavy load or a deliberate delay). Signs: supervisor log `shutdown: deadline reached, terminating the remaining processes` followed by `terminating storage`, exit code 5, `evt.process.exited` of `storage` with `clean: false`, no `sys.shutdown` of `storage` in its log. Likelihood: low (a few hundred ms window before the exit multiplied by a rare slow start); it becomes more likely with phase 3, which has more roles that start on demand (editors, workers, trigger host). Cost: not a crash. The session still ends, but at the full deadline and with exit 5. Data loss is possible only if `storage` still held unwritten data (variable values, flow saves queued by the engine or the editor at their own `sys.shutdown`): a kill of `storage` without `sys.shutdown` skips its "empty the queue" step (ARCHITECTURE 6.3, point 2; `storage` code not read for this).
**Verified by a test run.** The case is reproduced with the existing test role `echo:slowhello<ms>` (rank 3, as a worker) in the scenario of `test_a_child_that_says_hello_during_the_shutdown_gets_sys_shutdown_and_the_session_exits_clean` (`tests/fault/test_shutdown.py`), with `slowhello4000` and a deadline of 1500 ms instead of 12000 ms (throwaway test, not committed; direct run, no run id in the report, run log `20261013-185737-22564`, commit cc1b7c8). Result: exit code 5 after 1.87 s, supervisor log `exit requested ... deadline 1500 ms`, then only `deadline reached, terminating the remaining processes`, `terminating echo:slowhello4000`, `terminating storage`, `client 'storage' gone (peer_closed)`; `evt.process.exited` of `storage`: `clean: false`, `exitCode: 1`. The log has no `shutdown: ... connected during the shutdown` line for storage and storage never got `sys.shutdown`. Assumed, not checked: that real workers behave like the test role (same rank, same state `starting`); the data-loss case with a busy `storage`; the effect of a restart of a crashed child (restarts are cancelled by `Children.BeginShutdown`, so a restarted child in `starting` is only possible if it was relaunched before the exit began).
**Recommendation (one):** The proposal from the source, in this form: `Children.GroupDone` does not wait for a child whose state is `starting` (it has never connected, so it has sent nothing that a later group must write). The path of its late hello stays as it is: `Shutdown.OnHello` sends it `sys.shutdown` (its group index is behind `groupIndex`, so it gets it at once, with the rest of the deadline), it says `bye` and ends. Reasons: (1) three lines in one function, no new state, the F-41 path is already tested; (2) the ranks stay as they are, `storage` is still last for every child that is connected, which is the only kind that can have sent data; (3) a slow starter can no longer cost `storage` its `sys.shutdown`. Consequence to accept: if the late hello comes after `storage` has already ended, the late child (for example a worker) either ends by itself on `sys.shutdown` or is terminated at the deadline (exit 5 then, with clean data); and a child that connects after its group was skipped might try to talk to a `storage` that is gone (a fresh worker or editor has nothing to store yet, assumed). Changes: `src/supervisor/Children.ahk` (`GroupDone`), a test in `tests/fault/test_shutdown.py` (the scenario above, expecting `storage` `clean: true`; fails before, passes after), a sentence in `doc/ARCHITECTURE.md` 6.3. It touches `src/supervisor/`, so the foundation tier runs once (`--foundation`); `src/core/` is not touched.
**Alternative rejected:** At the start of phase 2, terminate every child in state `starting` at once (`Children.Terminate(name, false)`, no exit code 5). It gives a fixed exit time and no late hello, but it ends a process that may be in the middle of its start without any protocol, its `evt.process.exited` would be `clean: false` for a process that did nothing wrong, and it adds a second path next to the F-41 path instead of using it. Another rejected option: reorder the ranks so that `storage` does not wait for the workers; it breaks the rule that `storage` is last, which protects the data of workers that are connected and finishing.
**Update 2026-10-13 (implementation), status: closed.** Implemented as recommended in 72b77e1: `Children.GroupDone` skips a child in state `starting`; ARCHITECTURE 6.3 describes the rule. Test `test_a_child_that_has_not_connected_does_not_hold_storage_and_the_session_ends_with_storage_clean` (`tests/fault/test_shutdown.py`, `echo:slowhello4000`, deadline 1500 ms, both scaled): before the change it failed with `storage` `clean: false` (exit 5, `terminating storage` in the supervisor log; run log `20261013-190726-13324`); after the change it passes (exit 5 only because the late child is ended at the deadline, `storage` `clean: true`, run log `20261013-190820-16532`). The unit test `LateHelloGetsTheShutdown` (`tests/ahk/supervisor_tick.test.ahk`) asserted the old wait ("storage waits for the group of the late child") and was changed to the new rule. Runs on 72b77e1: foundation tier (`--foundation`) 439 passed, 1 skipped, exit 0, no INTERNALERROR (run log `20261013-191016-6624`); fast tier 336 passed, exit 0, no INTERNALERROR (run log `20261013-191117-24148`); `tools/arch_check.py` 0 violations.

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

### F-72*: A second start is silent (forwarded to a running supervisor)

**What:** When the product is started while a supervisor is still running, the start is forwarded as an empty `cmd.app.command` and the second process exits with 0. Nothing is shown, no dialog, no console output. The `--start` options of the second start are ignored.
**Status:** Observed by the project owner's manual check (2026-10-13). Verified by the supervisor log (nine lines `command from command:` between 19:13 and 19:17, run 2026-10-13 manual session) and by reading the code: `src/supervisor/Supervisor.ahk:316-331` (`_ForwardIfRunning`, mutex `Local\AHF.supervisor.main`), `src/supervisor/Supervisor.ahk:224-234` (empty command only logged), `src/supervisor/SupervisorCommand.ahk:32-46`.
**Sign that it matters:** a start that does nothing and gives no hint why.
**Action:** Decide the user-visible feedback (for example a message that an instance is already running, or show the existing window). Not decided.
**Evidence:** diagnosis run on the owner's machine (read only); the supervisor log of `%APPDATA%\AutoHotFlow v2`.
**Update 2026-10-13, closed.** Decision of the project owner: the running supervisor tells the manager to show its window (the v1 behaviour). Interface: `cmd.manager.show` (`doc/PROTOCOL.md` 4.8), commit d530148. Implementation in commit 10c1f01: a forwarded `cmd.app.command` without `--command` makes the supervisor log `manager show requested by second start` and send `cmd.manager.show`; a manager that is not running is started like at the first start (`manager is not running (not_running), started it`); the second start still exits with 0. The stub manager shows and raises its window; the headless stub records `stub.show`. The difference to v1 (`#SingleInstance, force` replaced the old instance) is `M-23` in `doc/MIGRATION.md`.
**Verified:** `tests/fault/test_second_start.py` (real second-start command line, headless stub): failed before the change (no `stub.show`, no manager started), passes after. Fast tier: run 20261013-192725-2312, commit 10c1f01, exit 0, 338 passed, no `INTERNALERROR`. Foundation tier: run 20261013-192746-13396, commit 10c1f01, exit 0, 439 passed, 1 skipped, no `INTERNALERROR`. `python tools/arch_check.py`: 0 violations.
**Not checked:** the visible window by hand (no `gui` test, see `doc/TEST-STRATEGY.md`): that `Show` and `Restore` bring the stub window to the front in front of other applications (Windows may only flash the taskbar button for a background process).

### F-73*: Closing the debug window is reported as a crash, and the supervisor stays up

**What:** After the manager and the debug window were closed (2 s after start, no quit command sent), the supervisor kept running. Both children were logged as `ended unexpectedly (exited, exit 0)` and a crash report was written, although they exited normally. The manual check step 8 of the debug window expects only the debug process to end, with no "ended unexpectedly" entry and no report.
**Status:** Observed once by the project owner's manual check (2026-10-13). Verified by the logs. The manager part is decided: closing the manager window only hides it, the application keeps running, and only its Exit button or the tray entry ends it (E14, `work_items/phase3/README.md`, S4). So the manager does not count as a defect. The debug part is a defect. Cause in code not analysed.
**Sign that it matters:** false crash reports after a normal close of a window.
**Action:** Fix the exit classification of a normal window close (debug window, and the manager window in S4), and check the quit path. The manual check guide must follow E14 (see F-74).
**Evidence:** `Log_children` of the last manual session (the entries at 19:12:51).

### F-74*: Manual-check guide and start tasks do not match

**What:** The guide `doc/MANUAL-CHECKS.md` (section 1) asks for an empty data folder with `skeleton_flow.json` copied to `Flows\skeleton.json`. The VS Code start task passes no `--data` and no `--session`, so the product uses the default folder `%APPDATA%\AutoHotFlow v2`, which has no skeleton flow. Also, the process tasks print nothing when the application ends, so the end cannot be seen in the task.
**Status:** Verified by reading `doc/MANUAL-CHECKS.md:13-21` and `.vscode/tasks.json` (the manager stub task, lines 533-546). Not checked: the VS Code UI behaviour.
**Action:** The project owner has another agent fix the task and the guide.
**Evidence:** manual check of the project owner, step 2 and step 5.

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

Decisions on entries are in the summary table (status `decision needed`, `accepted`, `closed`) and in the status book `work_items/phase3/STATUS.md`, section "Decisions of the project owner". This chapter lists only what is open without an entry:

1. **Hand check of the GUI.** The owner checks the stub and the debug window by hand, using the guides in the "Not checked" section. The phase 2 checkbox for WI-13 stays open until then.
2. **Default working directory of flows (S4).** v2 reads no `settings.json` yet. The v1 default of `FlowWorkingDir` is `A_MyDocuments\AutoHotFlow`; v2 takes it over only if decided in S4. The test profile of a data directory will carry a `settings.json` with `FlowWorkingDir` below the data directory and `UILanguage` `en`. The auxiliary files of the v1 "Automatic tests" become fixtures in `tests/data/workdir/`; WI-43 does not depend on the owner's Documents folder.

## Sources

All sources are at the tag `v2-phase2-final` and can be read with `git show v2-phase2-final:<path>`:

- `work_items/STATUS.md`: table "Funde", "Beobachtungsliste (E7)", "Bekannte Probleme", "Nicht geprüft", "Nächste Schritte", "Abnahmelauf WI-34", "Abnahmelauf WI-35".
- `work_items/HANDOVER.md`: "Offene Entscheidungen", "Offene Punkte", "Nicht gebaut", "Nicht geprüft".
- The package files `work_items/phase2b/WI-*.md` and `work_items/phase2/WI-*.md` as cited above.
