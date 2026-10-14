# Closed Items

Status: 2026-10-13.

This document lists findings that are closed or accepted. Moved from doc/OPEN-ITEMS.md on 2026-10-13. Entries are unchanged. Open findings are in `doc/OPEN-ITEMS.md`.

## Summary

| ID | Title | Status | Phase 3 |
|---|---|---|---|
| F-12 | `Scheduler.Advance` pops before the state change | closed (fixed in 183c561) | |
| F-15 | Engine sends events for a deleted element | accepted | |
| F-25 | Permanently locked log file loses a whole batch | accepted (owner, 2026-10-13: acceptable risk; stall case fixed in 2675105) | |
| F-28 | Worker log entries never reach `storage` | closed (fixed in 58e48d2) | yes |
| F-29 | Child in handshake is not covered by the orphan guard | accepted (owner, 2026-10-13: low impact; 10 s instead of 3 s, option (b)); described in ARCHITECTURE 6.3 point 4 | |
| F-30 | Lost `sys.busy {busy: false}` | closed (reconnect case fixed in 4d97c49) | |
| F-36 | `sys.hello` unanswered for 15 s in `test_shutdown.py` | closed (owner decision, 2026-10-13) | |
| F-43 | Slow child during shutdown holds later groups | closed (fixed in 72b77e1) | yes |
| F-72* | A second start is silent (forwarded to a running supervisor) | closed (fixed in 10c1f01, interface in d530148) | |

* provisional IDs, assigned by the agent on 2026-10-13; the project owner assigns the final ones.

## Findings

### F-12: `Scheduler.Advance` pops before the state change

**What:** `Scheduler.Advance` calls `Pop` before `finished -> ready`. With an empty stack (M-14) it throws instead of ending the thread with `exception`.
**Status:** Closed (2026-10-13), fixed in 183c561. Verified: the effect was worse than an error in the log. `Pop` threw out of `Scheduler.Advance`, out of `Executor._Advance` and `_OnFinish`, into the finish callback of the element; the thread stayed `finished` for ever and the instance never ended (read in code: `Scheduler.Advance`, `Executor._OnFinish`/`_Advance`). Reproduced by the new unit test `Loop: leaving with an empty stack ends the thread as unhandled (F-12)` in `tests/ahk/engine_scheduler.test.ahk`: before the fix `error: AhfError: LoopStack.Pop: loop stack is empty`, after the fix 21 of 21 pass (direct `ahkrun.py` call, no pytest run id). Fix: with `leavesLoop` and an empty stack the thread is released, the outcome is `removed` with `unhandled` true, and the executor logs `f0` with the message `loop stack is empty when leaving loop ...`. This matches M-14 ("thread ends with exception"). Not checked: the pytest fast tier and the engine end-to-end with such a flow (no flow that enters a loop at `tail` exists in the test data).
**Why deferred:** (was) low priority; the bad case needs an empty stack.
**Sign that it matters:** An unhandled error from `Advance` in the engine log when a stack is empty.
**Action:** Proposal from the source: `Advance` catches the error and ends the thread with `exception`.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-21-engine-korrektheit.md`.

### F-15: Engine sends events for a deleted element

**What:** For a deleted element the engine still sends `evt.element.state` (`running`, then `exception`).
**Status:** Observed; deliberately accepted.
**Why deferred:** Clients ignore unknown element IDs, so the decision was to leave it.
**Sign that it matters:** A client that does not ignore unknown element IDs.
**Action:** None planned. Revisit if a client does not ignore unknown IDs.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-21-engine-korrektheit.md`.

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
**Status:** Accepted by the project owner (2026-10-13): low impact, the 10 s stay (option (b) below). Described in `doc/ARCHITECTURE.md` 6.3 point 4 (2026-10-14).
**Update 2026-10-13 (bug hunter):** Cause verified by reading and by one measurement. `Role._Guard` (`src/core/Role.ahk`) starts the orphan clock only when `peer.status = "reconnecting"`; for every other status it resets `lostSince`. A role that has never been welcomed is `connecting` (first attempts) or `handshake`, so the guard does not count. The role then ends by the budget of the peer, not by the guard: `Peer.DEFAULT_RECONNECT_TOTAL_MS` (10 s) for a hub that is not there, and `helloTimeoutMs` (3 s) per attempt plus 3 s guard when the hub accepts the pipe but does not answer. Measured: `python tools/ahkrun.py src/AutoHotFlow.ahk --role=worker --hub=<pipe nobody serves> ...` ends with exit 4 `peer closed (hub_unreachable)` after 10.2 s (direct call, no pytest run id, commit 4d97c49), against about 3 s after a connection that was already ready (`test_role_ends_with_exit_4_when_its_pipe_is_cut_and_the_hub_does_not_come_back`). A supervisor that dies while a child is still starting therefore leaves that child for up to 10 s, not 3 s. A hub that is dead but whose pipe broke after the welcome is covered. Not changed: the fix is in `src/core/` and needs the project owner's agreement.
**Options:** (a) In `Role._Guard` also count `connecting` and `handshake` as lost (clock from the start of the process), so ARCHITECTURE 6.3 point 4 holds without exception; risk: a role started by hand or by a test before its hub (the supervisor creates the hub pipe before it starts children, read, not checked for every test setup) would give up after 3 s instead of 10 s, so such tests must be checked. (b) Keep the 10 s and describe it in ARCHITECTURE 6.3 ("a role that has not yet connected waits up to 10 s"). (c) Lower `reconnectTotalMs` for the first connect only. Recommendation: (a) with a test that starts a role without a hub and expects exit 4 within `ORPHAN_BUDGET_S`; low priority, the effect is a stray process for a few seconds.
**Update 2026-10-14 (bug hunter), follow-up "hub accepts the pipe but never answers `sys.hello`":** The 10 s in the update above did not hold for this case. Reproduced (verified): a hub stand-in that accepts and reads but never answers; the role sent 9 `sys.hello` in 25 s and was still alive (test `test_hub_that_never_answers_hello_ends_the_role_with_exit_4`, run ID `20261014-064634-7512`, base commit 1e444c2). Cause: the hello timeout closes the connection, `Peer._BeginReconnect` restarted the 10 s budget at each failed hello, and the orphan guard resets its clock in `handshake`; so neither ended the role. Fixed: `_BeginReconnect` keeps the budget when the connection ended in `handshake`, so the budget counts from `Connect` or from the loss of a ready connection, as ARCHITECTURE 6.3 point 4 says. After the fix the role ends with exit 4 after 12.3 s (budget 10 s plus the running hello, 3 s at most); run ID `20261014-064717-1744`, `test_role.py` 11 passed; `test_peer.py` 10 passed (`20261014-064746-2828`).
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

### F-72*: A second start is silent (forwarded to a running supervisor)

**What:** When the product is started while a supervisor is still running, the start is forwarded as an empty `cmd.app.command` and the second process exits with 0. Nothing is shown, no dialog, no console output. The `--start` options of the second start are ignored.
**Status:** Observed by the project owner's manual check (2026-10-13). Verified by the supervisor log (nine lines `command from command:` between 19:13 and 19:17, run 2026-10-13 manual session) and by reading the code: `src/supervisor/Supervisor.ahk:316-331` (`_ForwardIfRunning`, mutex `Local\AHF.supervisor.main`), `src/supervisor/Supervisor.ahk:224-234` (empty command only logged), `src/supervisor/SupervisorCommand.ahk:32-46`.
**Sign that it matters:** a start that does nothing and gives no hint why.
**Action:** Decide the user-visible feedback (for example a message that an instance is already running, or show the existing window). Not decided.
**Evidence:** diagnosis run on the owner's machine (read only); the supervisor log of `%APPDATA%\AutoHotFlow v2`.
**Update 2026-10-13, closed.** Decision of the project owner: the running supervisor tells the manager to show its window (the v1 behaviour). Interface: `cmd.manager.show` (`doc/PROTOCOL.md` 4.8), commit d530148. Implementation in commit 10c1f01: a forwarded `cmd.app.command` without `--command` makes the supervisor log `manager show requested by second start` and send `cmd.manager.show`; a manager that is not running is started like at the first start (`manager is not running (not_running), started it`); the second start still exits with 0. The stub manager shows and raises its window; the headless stub records `stub.show`. The difference to v1 (`#SingleInstance, force` replaced the old instance) is `M-23` in `doc/MIGRATION.md`.
**Verified:** `tests/fault/test_second_start.py` (real second-start command line, headless stub): failed before the change (no `stub.show`, no manager started), passes after. Fast tier: run 20261013-192725-2312, commit 10c1f01, exit 0, 338 passed, no `INTERNALERROR`. Foundation tier: run 20261013-192746-13396, commit 10c1f01, exit 0, 439 passed, 1 skipped, no `INTERNALERROR`. `python tools/arch_check.py`: 0 violations.
**Not checked:** the visible window by hand (no `gui` test, see `doc/TEST-STRATEGY.md`): that `Show` and `Restore` bring the stub window to the front in front of other applications (Windows may only flash the taskbar button for a background process).

## Sources

All sources are at the tag `v2-phase2-final` and can be read with `git show v2-phase2-final:<path>`:

- `work_items/STATUS.md`: table "Funde", "Beobachtungsliste (E7)", "Bekannte Probleme", "Nicht geprüft", "Nächste Schritte", "Abnahmelauf WI-34", "Abnahmelauf WI-35".
- `work_items/HANDOVER.md`: "Offene Entscheidungen", "Offene Punkte", "Nicht gebaut", "Nicht geprüft".
- The package files `work_items/phase2b/WI-*.md` and `work_items/phase2/WI-*.md` as cited above.
