# Open Points

Status: 2026-10-15, branch `v2-port`. Findings are carried in the summary table below; closed ones are in `doc/CLOSED-ITEMS.md`.

This document lists everything that is still open, observed, or deferred. History of the early findings (F-0001 to F-0043): tag `v2-phase2-final`, table "Funde" in `v2-phase2-final:work_items/STATUS.md`. The work-item files that this document cites were removed from the working tree; they can be read with `git show v2-phase2-final:<path>`.

Entries marked **(phase 3)** matter for the phase 3 plan.

Closed and accepted findings are in `doc/CLOSED-ITEMS.md`. Entries that wait for the project owner are in `NEEDS-ATTENTION.md` (repository root), not here.

Status words follow the sources: *verified* (read or tested), *assumed* (suspected, not proven), *not checked*. "Read in code" means the source was read but the behavior was not reproduced.

## Summary

Entries that only observe (not for the bug hunter) are in the chapter "Observed only (not for the bug hunter)" below the findings.

| ID | Title | Status | Phase 3 |
|---|---|---|---|
| F-0013 | `Ids.Next` and `ExecContext.Finish` not atomic | fixed (owner agreed on 2026-10-15), verifier pending | yes |
| F-0019 | Supervisor messages after `storage` is gone go only to stderr (narrowed: only the part that is never delivered, see the update) | decision needed, low | |
| F-0020 | Flow file parsed twice in the engine | open, not implemented | yes |
| F-0073 | The stress test with 200 big flows fails its snapshot budget (largest snapshot answer during loading 2326 ms, budget 1000 ms) | budget raised to 3 s (E0042, owner 2026-10-15); stays open as an optimization after the port (pre-filter for inactive flows); measurements in WI-0046 | yes |
| F-0097 | A loop inside a list loop (or a parse loop) costs time proportional to the size of the outer list per entry: entering a loop copies the hidden snapshot of the outer loop (`LoopStack.Push`), leaving it restores a copy | fixed (option A: the levels share the hidden snapshot), verified by unit tests (red before, green after) and the fast tier; flow timing not measured again, verifier pending | |
| F-0098 | A fast loop floods the subscribers of the flow topic: every element start and end is an `evt.element.state` event, so 100,000 passes of an empty loop send 200,000 events (and a loop with a body, three or more per pass) | accepted (project owner, 2026-10-16): both events stay | |
| F-0099 | `Action_Execute_Flow` needs an enabled trigger, but every flow is disabled after the start of the engine (the enabled state is not loaded or kept) | decided by the project owner (2026-10-16, E0053, E0056, E0057): the enabled state of a trigger comes with S0003, WI-0060 (REQ-EXE-070, REQ-TRG-050); until then a trigger counts as enabled when its flow is enabled | yes |
| F-0100 | Slow tier: the random run of the expression oracle stopped at the F-0075 class through a subtraction (`!(ftiny - fz . (f3 < ineg))`): the guard of the generator misses `ftiny` inside an operand of the concatenation | verified (seed 411675 reproduces it), open, test generator only | |
| F-0101 | Slow tier: `test_start_stop_storm_leaves_a_consistent_engine[smoke]` saw the engine's handle count grow by 19 (limit 5) | observed, red twice in a row and once alone, green three times on `c27ff8f`; cause not known; open, watch the history | |
| F-0102 | `tests/test_precommit.py` writes the text `index v1`, which the v1 guard of the fast tier reads as a dependency on `v1/` | open, verified (red on the base commit); test text only | |

## Findings

### F-0013: `Ids.Next` and `ExecContext.Finish` not atomic (phase 3)

**What:** `Ids.Next` increments and reads the counter in separate lines. `ExecContext.Finish` checks and sets its state in separate steps.
**Status:** Fixed (see the update of 2026-10-14), verifier pending. Original finding: read in code (`src/core/` and `src/elements/`).
**Why deferred:** Low risk so far. A change in `src/core/` needs the project owner's agreement.
**Sign that it matters:** Duplicate IDs, or an element that finishes twice.
**Action:** In phase 3, guard both spots with `Critical`, with the agreement of the project owner.
**Update 2026-10-13 (bug hunter):** Re-read, both races are real in principle: AHK v2 may interrupt a thread between lines (timer or message handler), so `Ids.Next` (`src/core/Ids.ahk:22-24`: increment, then read `this.counter`) can return the same number twice if an interrupting call runs in between, and `ExecContext.Finish` (`src/elements/base/ExecContext.ahk:36-40`) can run `onFinish` twice. `Executor._Advance` already uses `Critical` for the same reason (WI-0016 seen 2 of about 50 runs). Not reproduced. Smallest fix for `Ids.Next`: read into a local and use `Critical "On"`/restore, or compute `n := ++this.counter` in one expression (still not formally atomic). Not done because it changes `src/core/`; waiting for the owner's agreement.
**Update 2026-10-14 (bug hunter), fixed:** The `Ids.Next` race is reproduced: a test with a 1 ms timer taking ids while the main thread takes ids (`tests/ahk/core_ids.test.ahk`, "an interrupting timer never gets the same id") failed 3 of 3 runs with a duplicate id after about 118,000 ids. `Ids.Next` now takes the number under `Critical` (`n := ++this.counter`), and the test passes 3 of 3 runs. `ExecContext.Finish` now checks and sets `finished` under `Critical` and calls `onFinish` after restoring it; this half has no test (the interruption between the two lines cannot be forced), it follows the pattern of `ThreadState.Finish`. The project owner agreed to the change on 2026-10-15 and had it integrated. Not checked: stress runs.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-0021-engine-korrektheit.md`.

### F-0019: Supervisor messages after `storage` is gone go only to stderr

**What:** Supervisor messages after `storage` has left (and messages during a supervisor crash) do not go to the log, only to stderr.
**Status:** Open, low priority. Partly covered by the crash report (WI-0028).
**Why deferred:** Partly covered already.
**Sign that it matters:** A gap in the log after `storage` has exited.
**Action:** Route these messages to a fallback log, or accept the gap.
**Update 2026-10-15 (bug hunter), narrowed:** The title is wider than the behavior. Verified by reading `src/supervisor/DiagLog.ahk` and `tests/ahk/diag_log.test.ahk` (queue cases at lines 41 to 87, not run in this round): while `storage` is not connected (start, crash, planned restart) the supervisor queues its entries (up to `Role.LOG_QUEUE_MAX`, the oldest are dropped and counted) and `Flush()` delivers them on the next `sys.hello` of `storage` (`Supervisor.ahk:189-190`). So a restart of `storage` loses nothing but an overflow of the queue. What is never delivered: (1) the entries the supervisor writes after `storage` has left for good, that is the last lines of a session (`shutdown: finished with exit code`, `supervisor: ends with exit`, `Supervisor.ahk:424`, `Shutdown.ahk:190`), (2) the queue content when the supervisor ends while `storage` is down, (3) the queue overflow. In a product start nobody reads stderr (the supervisor has no console), so these lines are lost. The effect is a log that ends without the closing lines of a session; the diagnosis report (WI-0028) is the other trail. Not checked: whether a test reads those closing lines from the log (grep over `tests/` and `doc/` finds none).
**Options:** (a) accept and describe it in `doc/ARCHITECTURE.md` 6.2 (stderr is the only trail for the end of a session); (b) at the end of the supervisor write the remaining queue and the closing lines to a fallback file in the session folder (`supervisor-tail.log`), synchronously, once, outside the message path; (c) shut `storage` down after the closing lines are sent (needs the order of the shutdown changed; larger). Recommendation: (a) now, (b) if a session end without closing lines ever hampers a diagnosis. Not a safe call for an agent: it is a product decision about log files, so no change made.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-0023-diagnose-logpfade.md`.

### F-0020: Flow file parsed twice in the engine (phase 3)

**What:** The engine pays twice for each flow file: once for the frame and once for the flow text. The source gives about 0.23 s per flow and 45 s for 200 flows.
**Status:** Open, not implemented. Figures as given in WI-0024.
**Why deferred:** The alternatives belong to phase 3: send the flow as an object, chunking, or a native parser.
**Sign that it matters:** Slow start with many flows (for example 200 flows).
**Action:** Choose one alternative in the phase 3 plan.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-0024-hub-routing-laden.md`.

### F-0073: Stress test with 200 big flows: a snapshot answer during the load takes 2.3 s (budget 1 s)

**What:** `tests/stress/test_big_flows.py::test_many_big_flows_load_without_hung_and_with_a_responsive_engine[200]` failed in the stress run of the S0001 acceptance (WI-0043). Everything else in the test held (all 200 flows loaded, no `hung`, `crashed` or `restarted`, no storage error, no snapshot timeout); only the latency check failed: `n=251 median=148.45 p95=543.45 p99=1351.00 max=2325.93` ms against the budget of 1000 ms (`SNAPSHOT_BUDGET_S`, serial run, no scaling). The time until `evt.engine.ready` was 59.35 s.
**Status:** measured in WI-0046 (`doc/MEASUREMENTS.md` MS-0030), open. On a machine with the normal load the budget held in 3 of 4 runs of the plain case (3 runs with hooks and one unhooked run through `run_suite.py`: ready after 52 to 55 s, largest snapshot answer 576, 588 and 668 ms); one run broke it (1511 ms, not explained). Scheduled in S0002 (decision of the project owner, 2026-10-14): S0002 registers classes and so lets the conversion at load grow; WI-0045, WI-0047 and WI-0052 to WI-0056 run this stress test at their end and stop if the budget is broken (`work_items/phase3/README.md`, S0002, "Load path of the engine").
**Evidence:** stress run on the code of WI-0036 to WI-0042 plus the WI-0043 test (commit of the test `1783e67`); 14 other stress tests passed. Earlier measurement of the same test (MEASUREMENTS MS-0019, WI-0024, before phase 3): ready after 45.3 s, largest snapshot answer 506 ms (p99 495 ms, median 194 ms, n=199). So the median is about the same, the tail and the time to ready are worse (+14 s, max about 4.6 times).
**Cause (WI-0046, verified by hooks in the engine, 3 runs per variant):** the conversion is not the cause. With the product classes it costs 0.65 ms per flow (0.13 s of 54 s; 14,925 elements wait for their class). In the worst case after S0002 and S0008 (a stub for every class of the 8 flows, every parameter an expression) it costs 21 to 24 ms per flow on average, 4.3 s in total (about 8 % of the load time), 69 ms at most for one flow; time to ready and the largest snapshot answer stay the same within the spread (53.4 s, 555 to 791 ms). The variable phase is 1.9 s in total (answer handlers 40 ms). The load time is dominated by two parses of the same text: `Message.Parse` of the frame in the engine (about 160 ms per flow, about 32 s of the 52 s, assumed from MS-0020 and the difference to the handler time) and `FlowDefinition.FromText` (91 to 98 ms per flow, 19 s). They run with `LOAD_PARALLEL` = 2, so a ping waits behind up to two answers of about 160 + 100 to 300 ms each; the observed maxima of 0.56 to 0.79 s fit that, the 1.5 s run and the 2.3 s of the S0001 acceptance do not (assumed: load of the machine, not checked). Compared to MS-0019 (45.3 s, 506 ms) the time to ready is 15 to 20 % longer, the maximum about 1.2 times; the cause of this difference is not investigated (S0001 changed the loader and the evaluator; not checked).
**Decision (owner, 2026-10-15, E0042):** the budget is raised to 3 s; the finding stays open as an optimization after the port. The tail is a latency during the start, not a product requirement. Candidate: a conservative pre-filter for "has an enabled trigger" (`"enabled": "1"`, any doubt means parse) run by storage on the raw file text, so inactive flows are parsed on first use only. That saves both parses (frame and `FromText`) for inactive flows. Not checked: where the name for the snapshot would come from without a parse; whether files written by v2 use `true` instead of `"1"`.
**Options if the budget breaks again (for the project owner, none needed for the conversion):** the conversion needs no change (stagger, convert on first use and save converted flows would save at most 4.3 s of 53 s). What would help: a parse of the frame that does not escape the flow text twice (the flow text travels inside a JSON frame), reading flows lazily (the engine is ready before all 200 flows are parsed), or `LOAD_PARALLEL` = 1.

### F-0097: A loop inside a list loop copies the snapshot of the outer loop at every entry and exit

**What:** `Loop_Work_through_a_list` and `Loop_Parse_A_String` keep their values in the hidden loop variable `A_LoopCurrentList` (one member is read per pass, so a pass is cheap). Entering any loop at `head` pushes the loop variables (`LoopStack.Push` copies both maps, values included, `LoopStack.CopyMap`), leaving it restores the pushed copy; a branch of the flow (thread clone) copies the stack as well. A loop inside a list loop therefore copies the whole snapshot of the outer loop at every entry. As in v1, which copied too.
**Status:** verified. Flow: list loop over n members, inside a `Loop_SimpleLoop` with 1 pass: n = 500 / 1000 / 2000 take 1.76 / 5.47 / 19.7 s, 3.5 / 5.5 / 9.9 ms per outer pass (quadratic; without the inner loop about 0.5 ms per pass). Run in the flow runner, one machine with the load of other agents.
**Why deferred:** only a flow with a big list and a loop in its body suffers; a fix touches the loop stack of the engine (copy on write for values that nobody changes, or a snapshot outside the loop variables), which is hardened code (M-0019, WI-0021).
**Decision (project owner, 2026-10-16): option A**, share the hidden snapshot between the levels of the loop stack. The fix is scheduled after WI-0055, because it touches the loop stack that the flow-control work also uses. **Action (fix):** share the hidden snapshot between the levels of the stack (it is never changed after the head) or keep it in the thread in a structure that `Push` and `Clone` share.
**Done (2026-10-16):** `LoopStack.Push` copies only the two small maps; the hidden values (the snapshots) are shared between the levels, which is safe because nothing changes them in place (`SetVar` replaces an entry, an A_ name cannot be assigned by path). `Clone` still copies every level, as before (a branch owns its values). Status: fixed, verified at unit level; the end-to-end timing of the flow was not measured again.
**Evidence:** WI-0054 (measurement in the session of the report, before the fix). Test `tests/ahk/vars_model.test.ahk`: "loop stack: entering a loop shares the outer snapshot (F-0097)" (red before the change, green after) and "loop stack: nested snapshots stay apart (F-0097)" (green before and after). Fast tier green after the change (`python -m pytest tests -q`, 1123 passed, 1 skipped, exit 0).

### F-0098: A fast loop sends two events per element pass to every subscriber

**What:** The engine emits `evt.element.state` (`running`, `finished`) for every element start (`Executor._ElementStarted`, `_ElementStopped`). A loop pass has the loop element and the elements of the body, so 100,000 passes of an empty loop are 200,000 events, one per 0.2 ms of engine time; each event is a message through the hub to every subscriber.
**Status:** verified for the numbers: in the session the same loop takes 454 us per pass (93 s under load of other agents) against 213 us without the events (MS-0034), so the events cost as much as the loop. Not checked: the cost for an editor or a manager (they do not exist yet) and whether the hub drops events for a slow subscriber.
**Why deferred:** nothing is wrong for the engine (a snapshot answer stayed below 20 ms during the run); the question belongs to the editor (S0005): it can subscribe to the counts only, or the engine can coalesce the events of an element that runs more often than a few times per second (a count with the last state).
**Decision (project owner, 2026-10-16): accepted, no change.** The owner judges the cost negligible, and a change would break other parts of the software and tests that expect both messages. The editor (S0005) must still work with two events per pass.
**Evidence:** WI-0054, `tests/integration/test_core_c_loops.py::test_a_long_loop_does_not_block_the_engine_and_costs_little_per_pass`.

### F-0099: Execute_Flow needs an enabled trigger, but no flow is enabled after a start

**Decision (project owner, 2026-10-16, E0053):** belongs to S0003 (REQ-EXE-070), not fixed earlier.

**What:** The help of v1 says that the trigger of `Action_Execute_Flow` must be enabled, else the element ends with `exception` (or with `normal` with "Skip disabled flows"). Until the triggers have a state of their own (S0003) the engine counts a trigger as enabled when its flow is (`Executor.IsTriggerEnabled`, `FlowRecord.Enabled`). `FlowRecord.Enabled` is `false` for every flow after the engine has loaded it, and nothing keeps it (REQ-EXE-070: "the state survives a restart: not checked"; the `enabled` keys of the triggers in the files are not read). So after every start of AutoHotFlow each called flow has to be enabled again (`cmd.flow.enable`, later the manager) before a flow can call it; the v1 test flows that call their own triggers (44 uses, all with "This flow") end with `exception` unless the flow is enabled first.
**Status:** verified by reading `src/engine/FlowRecord.ahk` and by the tests of WI-0055, which enable the flows after the start (`flows.enable`). Not checked: whether the "Automatic tests" flows of v1 enable themselves with `Set_Flow_Status` before they call (WI-0057).
**Action:** fixed by WI-0060 (S0003): the enabled state per trigger after E0056, kept in `FlowState.json` (E0057, replaces "loaded from the file"); `IsTriggerEnabled` reads it. For WI-0057: the test corpus enables its flows. Alternative: a call of "This flow" does not need the enabled state (the flow runs already); not taken, because the help text makes no exception.
**Evidence:** WI-0055, `tests/integration/test_core_d_flows.py::test_disabled_and_missing_flows`.

### F-0100: the random oracle run finds F-0075 again through a subtraction

**What:** `tests/oracle/test_expr_oracle.py::test_a_random_run_shows_no_deviation_without_an_entry` failed in the slow tier of WI-0055 (run 20261016-163117-ebcaeac2, commit `ebcaeac`) with the case `c634: !(ftiny - fz . (f3 < ineg))`: native `0`, evaluator `1`. `ftiny - fz` is the Float `1e-300`; the concatenation makes a text out of the range of Float, the class of F-0075. The guard of F-0075 ("the generator does not use `1e-300` as an operand of the concatenation") looks at the direct operand only, not at an operand that is an expression with `ftiny` in it.
**Status:** verified: `python tools/expr_oracle.py --seed 411675 --count 20000` gives this one OPEN case on `ebcaeac` (WI-0055 does not touch `src/expr/` or the oracle). The random test therefore fails for some seeds.
**Action:** extend the guard of the generator to any operand of `.` (and of the boolean operators) that contains `ftiny` or `fhuge`, or mark the class with the entry of F-0075. Owner of the oracle decides.
**Evidence:** run 20261016-163117-ebcaeac2 (`%TEMP%\ahf_runs\20261016-163117-ebcaeac2\output.txt`).

### F-0101: the storm smoke test sees the engine's handle count grow now and then

**What:** `tests/stress/test_start_stop_storm.py::test_start_stop_storm_leaves_a_consistent_engine[smoke]` failed in the slow tier with the engine's handle count rising from 145 to 164 (limit +5). It failed twice in a row, and once alone; then it was green three times on `9f1d403` and `c27ff8f`, whose code changes do not touch the engine.
**Status:** observed, not reproduced in the green runs; cause not known (assumed: a handle that is released late, not a leak by a code change). Open.
**Action:** watch the history of the test (`python tools/test_history.py --test "tests/stress/test_start_stop_storm.py::test_start_stop_storm_leaves_a_consistent_engine[smoke]"`). If it fails again alone, read the handle types of the engine process in the run log and open a work package; if it fails only under load, add it to the load flakes.
**Evidence:** runs 20261016-172834-c27ff8f4-3 (red) and its recheck at 17:36 (red alone), in the run history of the main checkout.
### F-0102: `test_precommit.py` writes the text `index v1`, which the v1 guard reads as a dependency

**What:** `tests/test_no_v1_dependency.py::test_no_code_or_test_reads_the_v1_folder` fails on the fast tier since the pre-commit tests were added (`tests/test_precommit.py` lines 24, 66, 80, 91, 127: the test fixture text `index v1`).
**Status:** verified (the guard fails with the unchanged `tests/test_precommit.py`; the text is in the base commit, the file is not changed in this round). Red in the fast tier, not caused by the engine change.
**Why deferred:** Found while running the fast tier for F-0012; not in the scope of that finding.
**Sign that it matters:** The fast tier is red for every run until the text changes.
**Action:** Change the fixture text (for example `index one`) in `tests/test_precommit.py`, or add the file to the guard's exceptions. A one-line test change; the owner or the agent of the pre-commit hook decides.

## Observed only (not for the bug hunter)

Entries that the bug hunter does not take (`doc/ORCHESTRATOR.md` 3c): they were observed once or only under parallel load, were not reproduced when run alone, or are assumed and not checked. Each one has its sign (what to look for in a run) and its action. Hunter-eligible entries stay in the summary table and the findings above.

| ID | Title | Status | Phase 3 |
|---|---|---|---|
| F-0002 | Pipe not ready within 2 s under load | open, observed | |
| F-0041 | `refreshed` 2 instead of 3 in the debug role test | observed, open (0 of 33 in repetition on `dec432b`) | |
| F-0043 | `cmd.worker.cancel` unanswered in the hang test | observed, open | |
| F-0060 | `cmd.worker.run` unanswered for 5 s in `test_worker_busy.py` | observed once, open | |
| F-0062 | `storage` not ready within 45 s after a freeze in the hang test | observed once under load, open | |
| F-0063 | Log line lost while other processes hold the files (`readers-allow-read`) | observed once at `-n 12`, open (stall hypothesis fixed in 2675105, not proven) | |
| F-0071 | `test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted[0]` got no `evt.process.crashed` for `worker:1` in the slow tier | observed once, not reproducible in 8 runs, diagnostics added; a race in `KillWorker` found and fixed (plausible cause), open | |
| F-0075 | A numeric text outside the range of Float (`1e-3001`) is true in a boolean test of AutoHotkey when it is a concatenation result, and false in the evaluator | verified by the expression oracle (one case in 40,000 random cases), open, low, AutoHotkey quirk | |
| F-0077 | `test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms` did not see the job in the snapshot of the worker | observed once in a slow-tier run next to another suite run, 5 of 5 green alone, open | |
| F-0079 | Foundation tier: `test_suspend_and_resume` leaves two processes behind (cleanup of the process tracker) | observed once on `b92d800` (run 20261015-153715-b92d8005), open | |
| F-0080 | Foundation tier, timing under load: frozen-process tests exceed their budgets, one teardown leaves processes behind | observed once on `88be7fe` (run 20261015-153151-b481440a), not seen on `b92d800` in one run, open | |
| F-0084 | Slow tier: a frozen child is terminated 5.08 s after the hang (budget 4.0 s) | observed once, run 20261015-172954-99e2c044 on `1aceedd`; cause: a stand-still of the supervisor extends the kill time by design, test budget now accounts for it; open until a repeated slow run is green | |
| F-0086 | Foundation tier: `child_launcher.test.ahk` case "stdin of the child is NUL": `findstr` did not end within 10 s | observed once under load, run 20261015-201039-acc9907a on `acc9907`, green alone, open | |
| F-0087 | Slow tier: `test_clients_churn.py` smoke variant got 13 snapshot probes during the churn, 20 required | observed once under load, run 20261015-201045-acc9907a on `acc9907`, green alone, open | |
| F-0089 | Slow tier under load: three fault tests fail that pass alone: killed worker without `evt.process.crashed`, shutdown of session 1 took 6.15 s (limit 6.0), supervisor-stall test | observed once under load, run 20261015-203710-59c199ec (code of `d179825`), green alone (12 passed, run 20261015-204219-59c199ec), open | |
| F-0094 | Fast tier: `test_pings_are_answered_while_a_blocking_element_runs` third ping answered after 0.808 s (limit 0.8 s) | observed once under load, run 20261015-231712-bc27cbe5 on `bc27cbe` (the commit only touches `WorkerBridge`, not used by this test); green alone, run 20261015-231824-bc27cbe5; cause: the limit was the fixed block time (800 ms) and did not go through `scaled()`; fixed in the test, open until a repeated parallel run is clean | |
| F-0095 | Foundation tier: `test_a_child_that_has_not_connected_does_not_hold_storage_and_the_session_ends_with_storage_clean[0]` found the storage process still alive after the session ended | observed once under load, run 20261016-080313-0052a030 on `0052a03`; the slow tier (run 20261016-080657-0052a030) was green; not reproduced in 15 serial repetitions (run 20261016-090323-eaac3002); the supervisor reports `exited` only after the process handle is signalled, so the cause is a reused pid or a psutil artifact (assumed); the failure message now says what runs under the pid; open | |
| F-0096 | Foundation tier: `test_crashed_child_is_reported_within_1s_restarted_by_policy_and_others_are_untouched`: crash reported -0.053 s after the death (lower bound -0.05 s) | observed once under load, run 20261016-080313-0052a030 on `0052a03`; the slow tier (run 20261016-080657-0052a030) was green; cause: noise of the test's own timestamps, lower bound widened, open until a repeated foundation run is clean; tolerance (0.25 s, scaled) accepted by the project owner, 2026-10-16, see M-0062 | |
| F-0103 | `test_worker_reports_busy_when_a_job_begins_and_ends` failed once in a fast run; three serial reruns passed | observed once, not reproduced, not analysed | |
| F-0104 | Ping test: the three `sys.ping` requests of `test_pings_are_answered_while_a_blocking_element_runs` use a fixed timeout of 1.0 s while the block time is scaled | assumed (read in the code), not reproduced | |
| F-0105 | A role's summary line is written lazily: after a burst of log lines it can come late or not at all | assumed, not checked | |
| F-0106 | The header of a slow-run output in `run_suite` named another commit than the run folder | observed once, not reproduced, not checked | |

### Entries

### F-0002: Pipe not ready within 2 s under load (watch list)

**What:** In the first full test run of phase 2, two supervisor tests failed with "pipe not available after 2.0 s". The cause is assumed to be the load on the test machine.
**Status:** Observed once, open. Cause assumed, not proven. Not reported again in later full runs; the WI-0018 final state had 5 parallel full runs with 8 workers and no case.
**Why deferred:** Without a reproduction there is no reliable cause. The item was deliberately left open (E0007).
**Sign that it matters:** The message "Pipe nicht verfügbar nach 2,0 s" in a full run, especially in parallel runs.
**Action:** Repeat the run and read the supervisor log of the test (`AHF_TEST_KEEP=1`, see WI-0018). Record the cause, then fix it or close the item here.
**Evidence:** `v2-phase2-final:work_items/phase2/WI-0013-ui-stub.md`; `v2-phase2-final:work_items/STATUS.md`, table "Funde" and "Beobachtungsliste (E0007)".

### F-0041: `refreshed` 2 instead of 3 in the debug role test

**What:** `test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out` failed once in 10 parallel runs (WI-0034 acceptance) with `assert 2 == 3`.
**Status:** Observed, open. Not reproduced in the WI-0035 cycle 1 (10 parallel runs, 1 serial run, 505 fault runs, 14 stress runs). Cause not verified. The targeted repetition for F-0041 is not documented.
**Why deferred:** Not reproduced. The source suspects (assumed) that `DebugView.RefreshSnapshots` asks only the processes the window already sees as `ready`, the same pattern as F-0034. The other possibility is that an answer missed `DebugView.SNAPSHOT_MS`.
**Sign that it matters:** `assert 2 == 3` in the test under parallel load.
**Update 2026-10-13:** It failed again in 1 of about 10 `--all` runs (8 workers). The report fetched at the moment of the failure shows supervisor, `storage` and `debug` as `ready` with the late child `starting`, so the process side was in the expected state. Assumed (not proven) cause: the window's own table still showed `storage` or `debug` as not ready, the same lag as in `test_refresh_stores_the_snapshot_of_every_role_and_the_supervisor` (2 of 4 runs, `4 >= 6`). Both tests now wait until the window's table shows the roles as `ready`; 12 further `--all` runs did not show it again. Status: mitigated in the test, cause not proven. If it returns, the lag is in `DebugView` and not in the test.
**Update 2026-10-15 (bug hunter):** Repetition on `dec432b` (serial results of the whole file `tests/fault/test_debug_role.py`, 7 tests, `--all -m slow`): 9 runs with `-n 6` on an otherwise idle machine and 24 runs with `-n 8` while 4 such loops ran at the same time (about 32 busy workers): 33 of 33 green, the target test never failed (0 of 33). Not reproduced. Read in code: `RefreshSnapshots` counts an answer only when `ok` and a snapshot map arrive; a role that does not answer within `DebugView.SNAPSHOT_MS` (3 s) is stored as `no snapshot` and is not counted, so `refreshed` 2 would need one of supervisor, `storage`, `debug` to miss 3 s (extreme load or a stall) or the window's table to lag (mitigated in the test). The failing assertion prints `answer` with `snapshots`, so the next failure shows which entry says `no snapshot`. Assumed, not proven. Next step: none until it fails again.
**Action:** On the next failure, read the run log (`doc/TEST-STRATEGY.md` section 6): `diagnosis/`, `Reports/`, `Log/`.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-0035-bugfix-schleife.md` (section "Analyse Zyklus 1"); `v2-phase2-final:work_items/STATUS.md`, "Abnahmelauf WI-0034 (2026-10-12, zweiter)" and "Abnahmelauf WI-0035, Zyklus 1".

### F-0043: `cmd.worker.cancel` unanswered in the hang test

**What:** `test_cancel_of_the_hang_element_reports_stopped_within_500_ms`: `cmd.worker.cancel` was unanswered for 5 s (`AhfTimeout: no answer to engine#3 within 5.0 s`). It happened once in the serial run of WI-0034.
**Status:** Observed, open. Not reproduced in 10 single runs (WI-0035 cycle 0), in WI-0035 cycle 1 (10 parallel, serial, fault 20x, stress). Cause not verified.
**Update 2026-10-15 (bug hunter):** Not reproduced under heavy load: 180 runs of `test_cancel_of_the_hang_element_reports_stopped_within_500_ms` together with `test_cancel_stops_the_running_element...` (360 test runs, 12 parallel loops on 8 cores, `python -m pytest tests/integration/test_worker.py -q -n 0 -k "hang_element or cancel_stops" --all`, code state of `3538a33`), 0 failures (each pair 4.4 to 8.6 s). Read in code (`src/worker/Worker.ahk` `_CmdCancel`, `_StopCurrent`; `tests/elements/Test/Actions/Action_TestHangWorker.ahk`): `_CmdCancel` always answers, with `ok` or `not_found` (it throws, the role layer turns that into an error answer), so the suspicion "an abort is not answered when it hits a hanging element" has no support: the hang element yields every 100 ms (`DllCall("Sleep")` slices, messages are handled between the lines). A cancel that arrives before the start timer (`_StartJob`) ran is also handled (job set to empty, the timer returns). What remains possible (assumed): the worker process was starved or the pipe wake-up was late for more than 5 s in the original serial run; no evidence kept. Failure rate 0 of 180.
**Why deferred:** Not reproduced. It may be the same family as F-0033 (which was fixed as a test correction), but this is not proven. The source suspects that an abort is not answered when it hits a hanging element.
**Sign that it matters:** `AhfTimeout: no answer to engine#3 within 5.0 s` at the cancel call.
**Action:** On the next failure, take the snapshot of the worker (`cmd.diag.snapshot`) and run with `AHF_TEST_KEEP=1`.
**Evidence:** `v2-phase2-final:work_items/phase2b/WI-0035-bugfix-schleife.md`; `v2-phase2-final:work_items/STATUS.md`, "Abnahmelauf WI-0034 (2026-10-12, zweiter)" and "Schleife WI-0035, Zyklus 0".

### F-0060: `cmd.worker.run` unanswered for 5 s in `test_worker_busy.py`

**What:** `test_worker_that_blocks_longer_than_the_pong_timeout_is_not_hung_while_it_has_a_job`: the worker was `ready`, `cmd.worker.run` got no answer within 5 s (`AhfTimeout: no answer to engine#4`).
**Status:** Observed once in about 10 `--all` runs (8 workers), 2026-10-13. Not reproduced in 10 single runs under background load. Supervisor log was empty (no `storage` in that test), so there is no evidence for a cause. Possibly the same family as F-0043 (an unanswered request to a worker); not proven. The 5 s default of `ask()` in `test_worker_pool.py` does not go through `scaled()`; that is a suspicion, not a finding.
**Sign that it matters:** the same `AhfTimeout` on `cmd.worker.run`.
**Action:** On the next failure read `diagnosis/snapshot_supervisor.json` (children output, log ring) in the run log. Compare with F-0043.
**Update (bug hunter, round 12):** Still no evidence of a cause. One test-side weakness removed: `ask()` in `tests/integration/test_worker_pool.py` had a fixed 5 s default that did not go through `scaled()`; it now uses `scaled(5.0)` like every other upper limit (`tests/support/timing.py`). That is hardening, not a proven cause (assumed: a stall of the worker or machine). `test_worker_pool.py` and `test_worker_busy.py` pass (10 passed, run 20261016-080754-25908, `-n 4`). Stays open until the failure does not return.
**Evidence:** saved run log `%TEMP%/ahf_testruns_keep/20261013-145541-19344` (failure text only, no diagnosis yet).

### F-0062: `storage` not ready within 45 s after a freeze in the hang test

**What:** `test_frozen_storage_is_hung_ended_and_restarted_and_answers_again[0]`: "storage not ready again within 45.0 s".
**Status:** Observed once in about 10 `--all` runs, 2026-10-13, under full load (8 workers, many AHK processes). Not analysed; load is assumed, not proven. The limit already goes through `scaled()`.
**Sign that it matters:** the same message, especially at low load.
**Action:** Read the saved run log (`Reports/`, supervisor log): was `storage` started late, or did it hang a second time?
**Evidence:** saved run log `%TEMP%/ahf_testruns_keep/20261013-152128-3060` (includes the report written at the moment of the failure).

### F-0063: Log line lost while other processes hold the files (`readers-allow-read`)

**What:** `test_no_log_line_is_lost_while_other_processes_hold_the_files[readers-allow-read]` failed once at `-n 12` (more workers than the 8 cores, run took 51 s). The test serial and in 8 more runs passed.
**Status:** Observed once, 2026-10-13. Run log did not exist yet, no evidence kept. Related to F-0022 (permanently locked log file loses a batch), not proven.
**Update 2026-10-13 (bug hunter):** Not reproduced: the test passes serially (2 of 2) and I did not create artificial load. The holder keeps the file for about 4 ms out of every 5 ms with `FILE_SHARE_READ` only, so a write attempt finds it free only occasionally; with 100 or more attempts in 3 s a loss needs a long gap between attempts, which is the stall case fixed for F-0022 in 2675105 (assumed cause, not proven; no evidence of the original failure exists). If it fails again at normal worker counts after 2675105, the cause is something else: read `Log_storage.txt` in the run log for `log line lost` and its message.
**Sign that it matters:** the failure at normal worker counts, or "lines lost" in a real session.
**Update (bug hunter, round 12):** Not reproduced under much heavier load than the original: 24 concurrent serial runs of the test file selection (`-k no_log_line_is_lost`, both share modes, 48 test runs) next to 12 busy-loop processes on 8 cores; 24 of 24 passed (runs took 17 to 29 s instead of 6 s). Read `WriteQueue.RunOne`: the retry time of a log operation is wall-clock, but a gap longer than `STALL_MS` between two attempts is added back to `retryUntil`, so a stalled storage process does not lose lines by timing out without having tried (verified by reading). Only the failure with a gap shorter than `STALL_MS` per step but a total beyond 3 s of real failed attempts remains possible, and the test holders leave the file free about 1 ms in 5 ms, so that is unlikely. No cause found; stays open.
**Action:** On the next failure read the failure text and `Log/` in the run log.
**Evidence:** none kept.

### F-0071: Killed worker: no `evt.process.crashed` within the budget (slow tier)

**What:** `tests/fault/test_process_crash.py::test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted[0]` failed in the slow tier: after `kill_role(chain, "worker:1")` no `evt.process.crashed` for `worker:1` arrived within `CRASH_BUDGET_S + 5` (`tests/fault/test_process_crash.py:37`). The supervisor text in the assertion message was empty.
**Status:** observed once, **not reproducible** (0 failures in 8 runs on commit `505aceb`, see below). Cause unknown, open (watch list). Second occurrence under load: F-0089. Test diagnostics improved so the next occurrence can be read.
**Evidence:** commit `2d57395`, command `python tools/run_suite.py --ref HEAD -- tests -q --all -m slow` (4 workers), exit code 1, `1 failed, 85 passed, 2 xfailed in 121.75s`, no INTERNALERROR. The fast tier (`tests -q`) was green, 568 passed.
**Reproduction (verified):** the test is marked `slow`, so it needs `--all -m slow`. 5 serial runs (`run_suite.py --ref 505aceb -- tests/fault/test_process_crash.py -q -n 0 --all -m slow -k killed_worker`): 5 of 5 passed (2.4 to 4.1 s each). 3 runs of the complete slow tier with 4 workers (`run_suite.py --ref 505aceb --workers 4 -- tests -q --all -m slow`): 3 of 3 green (86 passed, 2 xfailed, 111 to 118 s). Failure rate 0 of 8; too few to measure a rare flake.
**Where the chain stops (not known):** the log of the original run is not available, and the assertion text held only the supervisor stderr, which is empty in every healthy run too. So it is not known whether the kill worked, whether the supervisor saw the death, or whether the report was lost.
**Budget (verified by reading):** the wait is `scaled(1.0) + 5` s, i.e. 8 s in a parallel run. The supervisor finds a dead child in its 200 ms tick (`Supervisor.TICK_MS`) and judges the exit at once or after at most `Children.EXIT_GRACE_MS` = 500 ms, so the report is expected within 1 s. A miss of 8 s needs a stall of the supervisor or of the test process of more than 7 s, so "budget too small" alone is unlikely (assumed, not proven). Still open: a tick stall under load (F-0062/F-0063 class), a lost report, or a test-helper problem (the recorder `chain.rec` missing the event). Not distinguishable without a second occurrence.
**Change:** `kill_role` in `tests/fault/test_process_crash.py` now puts the supervisor view of all roles (`chain.states()`), the last 30 event types and whether the death watcher saw the death into the failure message. On the next failure read that text first: role state `crashed` without the event points to the report path or the recorder; state `ready` points to a missed death (tick stall).
**Original suspicion (assumed):** The changes under verification (`VarAccess.ahk`, `Engine.OnShutdown`, unit tests) do not touch the supervisor, the worker pool start or the crash report, so they are probably not the cause. More likely a timing or load problem in the chain (worker killed while the engine was just starting the element; the supervisor text being empty suggests the log was not yet flushed) or an earlier hint of F-0062/F-0063 class flakiness. Not checked.

**Update (bug hunter, hunt round of 2026-10-16), plausible cause found and fixed, not proven as the cause of the observation:** the state `exited` with a last event `evt.process.exited` (F-0089 text) means the supervisor judged the end as a planned one, which `Children._OnGone` does only for `stopping`, shutdown or a clean goodbye; a worker killed from outside is `stopping` only if the engine's `cmd.process.kill` (`WorkerBridge._Lose` after `run not accepted: peer_gone`, `_Kill`) reached `Children.KillWorker` before the supervisor saw the process end. Measured (verified, Windows, 200 of 200 runs, Python `PeekNamedPipe` against `WaitForSingleObject` after `TerminateProcess`): the end of the pipe is visible 0.7 to 3.6 ms (median 0.8 ms) BEFORE the process handle is signalled. So the engine, told by the hub, can overtake the death; `KillWorker` then saw an unsignalled handle (the F-0042 guard `_HasEnded` does not fire) and relabelled the crash as `stopping`/`killed`. Under load the gap grows. Fix in `Children.KillWorker`: a `ready` worker without goodbye whose hub link is gone is dying on its own; it is only terminated (harmless on a dying process), the label stays, the end is judged as a crash. Unit test `KillOfAWorkerWithALostLinkStaysACrash` in `tests/ahk/supervisor_tick.test.ahk` fails before and passes after (foundation run 20261016-074716-5612 before: 3 failed incl. the new one; after: run 20261016-074735-13424, 43 passed). Fast tier 890 passed (run 20261016-074742-11324); crash, worker and supervisor_tick tests 111 passed (run 20261016-074849-1956). Not checked: that this was the cause of the original observation (no log of it), the load flake itself (the fault test was green anyway in these runs). Keeps F-0071/F-0089 open until the next slow-tier run is green without a repeat.

### F-0075: A temporary text such as `1e-3001` is true in AutoHotkey's `||`, `&&` and `!`, false in the evaluator

**What:** The expression oracle (WI-0044) found it with `ftiny . m["k"] || 2147483648 && i1` (`ftiny` is the Float `1e-300`, `m["k"]` is `1`). The concatenation gives the text `1e-3001`, a pure number whose value is outside the range of Float (it underflows to 0). Native AutoHotkey v2 takes this temporary text as true (`||` returns it, `!` gives `0`); the evaluator holds the value in a variable (`left := ...`) and there AutoHotkey takes the same text as false (`||` goes on to the right operand). Checked by hand: a variable that holds the text `1e-3001` is false in `if`, `?:`, `||` and `!`; texts such as `0.0`, `00`, `1e-300` agree on both sides. Only the text out of range differs.
**Status:** verified (run of `python tools/expr_oracle.py --seed 100 --count 40000`, the only deviation without an entry in 40,207 cases; the three probes above). Open, low: it needs a number text with an exponent beyond about 308, which only a concatenation of a tiny or huge Float with more digits makes. Not fixable inside the evaluator without keeping the temporary value out of a variable, which AutoHotkey code cannot do for a value that comes from a recursive call.
**Handling:** the generator of the oracle does not use the Floats `1e-300` and `1e300` as an operand of the concatenation or of a boolean operator, so a random run does not stop at it (`tools/expr_oracle.py`, `pick_var`). A deviation class is not made for it.
**Action:** none unless a real flow shows it. If the evaluator is ever made to follow AutoHotkey for it, the oracle starts to see it again with `ftiny` or `fhuge` in the pool of every operand.

### F-0077: the cancel test of the worker did not see the job in the snapshot

**What:** In a slow-tier run (`--all -m slow`, 4 workers, a foundation run of the same commit at the same time) `tests/integration/test_worker.py::test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms` failed: "the worker never showed the job in its snapshot", with a snapshot whose `info.job` was empty at an uptime of the worker of 5088 ms. The element (`Action_TestBlockWorker`, 3000 ms) runs for 3 s, so the polling (deadline 5 s, a request every 50 ms) either saw no answer while the job ran, or the job was over before the first answer came. Seen on the commit that added the variable requests of WI-0050; that change does not touch this path (the test speaks to the worker directly, the element uses no variable).
**Status:** observed once; 5 of 5 runs of the test alone (serial) green. Cause not investigated (assumed: load, the snapshot answers came late).
**Action:** if it comes back, record the times of the snapshot answers in the failure message (a request takes up to `ROOT_TIMEOUT_S`, which is longer than the element runs).
**Update (bug hunter, round 12):** Read in code (`src/worker/Worker.ahk`): `_CmdRun` stores the job before it answers, so the snapshot shows the job from the first poll on until the element ends after 3 s. An empty job at an uptime of 5088 ms therefore means that no snapshot answer arrived during the first 3 s (worker or machine stalled for more than 3 s; such stalls of 35 to 44 s were measured under CPU load, see F-0079) or that the first answer was late. This fits the load suspicion; the test cannot recover from a stall longer than the element, by design of the check. Not changed (assumed cause, not reproduced).

### F-0079: `test_suspend_and_resume` leaves two processes behind

**What:** `tests/support/test_procs.py::test_suspend_and_resume` checks the suspend and resume steps, which pass, and then fails in its `finally` block: `assert tracker.close() == []`, with two process IDs left over.
**Status:** observed once, on `b92d800` (run 20261015-153715-b92d8005, one run, not repeated). The same test failed on `88be7fe` in the foundation run 20261015-153151-b481440a with `assert 'running' == 'stopped'` after the suspend (the status did not change), so the test itself is not stable. Not root-caused (assumed: the process helper of `tests/support` or the suspend semantics on Windows, not the product code).
**Action:** a hunter reruns the test alone several times and reads the tracker code in `tests/support/`; the two failures may have one cause.
**Update (bug hunter, round 10):** Not reproduced: the body of the test in a loop, 100 iterations idle and 600 iterations next to 12 busy-loop processes on 8 cores, no failure (verified, script outside the repository). Read `tests/support/procs.py`: `_kill_tree` reports survivors only when a killed process is still alive 5 s later, and the test polls 2 s for the status `stopped`, so both failures fit a machine that stalled for seconds (assumed). A stall of this size was seen: runs of `child_launcher` under the same load took 35 to 44 s instead of 3 s in 3 of 25 runs. One plausible test-side cause was removed: the test suspended the process right after `Popen`, and `NtSuspendProcess` stops only the threads that exist at that moment, so a thread created later by the interpreter start would stay running. The test now waits for the first output line of the child before it suspends (tests/support/test_procs.py). Not proven to be the cause; stays open until the test has run in several foundation runs.

### F-0080: frozen-process tests exceed their timing budgets under load; a teardown leaves processes behind

**What:** In the foundation run 20261015-153151-b481440a on `88be7fe`, three tests about frozen processes failed their timing assertions: `test_shutdown.py::test_frozen_storage_is_terminated_at_the_deadline_and_the_others_exit_clean[0]` (exit after 5.09 s, budget 5.0 s), `test_supervisor.py::test_frozen_child_is_hung_within_8s_and_ended_like_a_crash` (terminated 4.68 s after the hang, budget 4.0 s; teardown reported processes left behind), and `test_supervisor.py::test_frozen_child_at_exit_is_terminated_at_the_deadline` (no answer to `py#1` within 2.0 s).
**Status:** observed once. Run 20261015-153715-b92d8005 (`b92d800`, one run) passed the same three tests. Not repeated on `88be7fe`. Suspicion (assumed): load from other runs at the same time (the run was not alone on the machine), not the commits of the session; the changed code (`src/core/Ids.ahk`, `src/engine/Engine.ahk`) is not on the path of these tests. The leftover processes are the part that matters: a teardown that leaves processes behind can disturb the next test.
**Action:** if it comes back, record the load on the machine during the run and the process IDs left behind; a hunter may reproduce it with a frozen-process test in a loop.

### F-0084: a frozen child is terminated late in the slow tier

**What:** `tests/integration/test_supervisor.py::test_frozen_child_is_hung_within_8s_and_ended_like_a_crash` failed with `assert crashed[0] - hung[0] <= 4.0`: the child was terminated 5.08 s after the hang. The hang itself was detected in time (5.89 s after the freeze, within 8 s).
**Status:** observed once, run 20261015-172954-99e2c044 on `1aceedd` (slow tier, one run). Same test family as F-0080 (frozen process timing under load). Suspicion (assumed): a slower child exit or start after the new entry scripts, or load; not separated.
**Action:** compare with `b92d800` and with an idle machine, same test in a loop.
**Update (bug hunter):** Cause found by reading and checked by a test (assumed for the one observed run, whose log is gone; verified for the mechanism). On an idle machine the test passes 6 of 6 times with the kill about 2.5 s after the hang (KILL_AFTER_MS 2 s plus tick and exit grace), far from 4.0 s. `Children.OnStall` moves `killAt` of a hung child by the length of every stand-still of the supervisor (gap of 2 s or more, `Stall.MIN_GAP_MS`), by design (WI-0033). So under load a supervisor stall of about 2.5 s gives exactly 5.08 s on the wall clock without any fault in the code. The test now adds the stand-still that the supervisor reports in its log to the 4.0 s budget, and a new slow test (`test_a_stand_still_of_the_supervisor_moves_the_kill_time_of_a_hung_child`) pins the mechanism (3 of 3 green). Not checked: that the failed run really had such a stall (log lost). Stays open until a repeated slow run is green.

### F-0086: a child of ChildLauncher did not end within 10 s although its stdin is NUL

**What:** `tests/ahk/child_launcher.test.ahk`, case "stdin of the child is NUL, it does not wait for input" (`CheckStdinIsNul`): `findstr x`, started with `ChildLauncher.Start`, had not ended after 10 s (`EndedWithin(..., 10000)`), message "the child waits for input".
**Status:** observed once, run 20261015-201039-acc9907a on `acc9907` (foundation tier through `tools/run_suite.py`, at the same time as a slow-tier run of the same machine and the test runs of another agent). Green alone right after (`-n 0 -k child_launcher`, 11 passed). The change under test (WI-0047, element packages) does not touch `src/supervisor/` or `ChildLauncher`. Suspicion (assumed): load; but 10 s is long for a process start and an end of input, so a stdin that is sometimes not NUL is not excluded. Not checked.
**Action:** run the case in a loop under load (two suites at once); if it fails again, log the handles of the child (stdin type) at the failure.
**Update (bug hunter, round 10):** Not reproduced: 25 runs of the whole file (`-n 0 --foundation -k child_launcher`) next to 12 busy-loop processes on 8 cores, 25 passed. But 3 of those 25 runs took 35 to 44 s instead of 3 s (not found which case stalled), so stalls of tens of seconds happen on this machine under CPU load. That supports the load suspicion for the 10 s limit; a stdin that is not NUL was not seen (assumed, not excluded).

### F-0087: the client churn smoke test gets too few snapshot probes under load

**What:** `tests/stress/test_clients_churn.py::test_clients_connecting_and_leaving_do_not_disturb_the_engine_or_leak[smoke]` failed with `assert len(latencies) >= 20`: 13 probe requests (answers 45 to 153 ms) during the churn. No error, no restart, no leak was reported before that assertion.
**Status:** observed once, run 20261015-201045-acc9907a on `acc9907` (slow tier, next to a foundation-tier run and another agent). Green alone right after. Suspicion (assumed): load; the number of probes depends on how fast the churn ends. Not checked.
**Action:** if it returns on an idle machine, count probes per second instead of an absolute number.

### F-0089: three fault tests fail under load and pass alone

**What:** in the same slow run: `test_process_crash.py::test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted[0]` ("no evt.process.crashed for worker:1", the watcher saw the death, state `exited`, event list ends with `evt.process.exited`), `test_shutdown.py::test_two_sessions_in_a_row_both_exit_within_2_seconds[0]` (`6.15 s <= 6.0`), `test_supervisor_stall.py::test_supervisor_stand_still_does_not_make_healthy_children_hung[0]` (assertion at line 55; the log shows "supervisor stood still for 7861 ms").
**Status:** observed once, together with the second observation of F-0088; serial rerun of the four fault files: 12 passed. These tests are not on the known list (F-0086 to F-0088). Suspicion (assumed): load of the run (4 workers plus other agents' runs), not WI-0047; the missing `evt.process.crashed` is the only one that is not a plain time limit. Not checked.
**Action:** if the crash event returns on an idle machine, check whether `evt.process.exited` can replace `evt.process.crashed` for a killed worker under a stalled supervisor. Same family as F-0071 (killed worker without `evt.process.crashed`): a second occurrence of F-0071 under load.

**Update 2026-10-15 (verifier of `7e046ff`):** more load-dependent failures of the same kind, each seen once and green when repeated: `test_worker_lifecycle.py` (killed worker before it answers: crash reported after 4.82 s, limit 3.25 s; run 20261015-205409-52f7923a), `test_engine.py::test_engine_reads_at_most_two_flow_files_at_a_time_while_loading` (no request in flight within the wait; run 20261015-205409-52f7923a), `test_storage.py::test_shutdown_finishes_the_queued_writes_then_says_bye_and_exits_0` (storage alive 3 s after `sys.bye`; run 20261015-210132-7e046ff7, green alone in run 20261015-210947-7e046ff7). Assumed: load of parallel agent runs. Not checked: whether the storage shutdown wait is a real race under load.

**Update (bug hunter, 2026-10-16):** see the update of F-0071: a race in `Children.KillWorker` (pipe end before process end) explains the missing `evt.process.crashed` and is fixed; the two pure time limits are untouched.

### F-0094: ping answered 8 ms over the limit while a blocking element runs

**What:** `tests/integration/test_worker.py::test_pings_are_answered_while_a_blocking_element_runs` (line 259): `answered[-1][2] < BLOCK_MS / 1000.0` was 0.808 against 0.8.
**Status:** observed once in the fast tier (844 passed, 1 failed) next to other suites; green alone. The limit equals the block time, so any scheduling delay breaks it. Assumed: load. Not checked: whether the limit is scaled (`scaled()`).
**Update (bug hunter, round 16):** Cause read in the test: the limit was `BLOCK_MS / 1000.0` (fixed 0.8 s, not scaled), measured from after `send_run`, so it was an upper limit under parallel load without `scaled()`, contrary to `tests/support/timing.py`. The pings themselves are fast (the test is green with margin alone). The test now lets the element block for `scaled(0.8)` s (parameter `Duration`) and compares the last pong against that time; in a serial run nothing changes. Verified: `tests/integration/test_worker.py` 18 passed with `-n 4` (run 20261016-090801-968), the test alone passed serially (run 20261016-090754-27000). Not proven by a failing run before: the stall cannot be forced; the failure had only been seen once under load.
**Action:** none unless it fails again with the scaled limit; then the pong was late by more than 2.4 s (read `Log/` of the run).

### F-0095: storage process still alive after the end of a session with a late child

**What:** `tests/fault/test_shutdown.py::test_a_child_that_has_not_connected_does_not_hold_storage_and_the_session_ends_with_storage_clean[0]` (line 145): `assert not alive(pids["storage"])` failed (`alive(25256)` true). The earlier assertions (exit code 5, `clean` true, no "terminating storage") passed.
**Run:** run 20261016-080313-0052a030, commit `0052a03`, `python tools/run_suite.py --ref 0052a03 -- --foundation -q -rA`, exit 1 (2 failed, 443 passed, 1 skipped, no INTERNALERROR). The same test passed in the slow tier, run 20261016-080657-0052a030 (`--all -m slow -q`, 130 passed).
**Suspicion (assumed):** the check runs right after the supervisor exit; storage has told the supervisor `clean` but the process object is still visible for a short time on a loaded machine (4 workers, many processes). Probably a race of the test (no wait for the process end), not a product defect. Not checked.
**Probable cause task:** none from the change under verification (it only touches `tests/support/test_procs.py`); load flake of an older test.
**Update (bug hunter, round 15):** Read in code (verified): the supervisor publishes `evt.process.exited` only in `Children._OnGone`, which runs after `WaitForSingleObject` on the process handle returned signalled (`Children.Tick`), and the session exit waits for `AllGone`. The test passes that event before it asks `alive(pid)`. So storage had ended in the kernel's view when the check ran; the "race of the test (no wait)" suspicion above is wrong. What remains (assumed, not proven): (a) the pid was reused by another process in the meantime (`alive` creates a fresh `psutil.Process(pid)`, which cannot tell the old process from a new one; Windows reuses pids, measured here: first reuse after about 140 spawns, 7 s), or (b) a psutil answer for a process that is being torn down. Checked: psutil 6.1.1 reports a terminated process whose handle another process still holds as not running (probe), so a held handle does not explain it. Not reproduced: 15 of 15 green (`AHF_FAULT_REPEAT=15`, serial, run 20261016-090323-eaac3002 on `eaac300`, 44 s). Changed: the assertion message of this test and of the late-hello sibling now carries `describe_pid` (name, start time, command line of what runs under the pid), so the next failure tells (a) from a living storage. Next step: if it returns, read that message; for (a) pin the identity (a `psutil.Process` taken at `wait_ready`) in `alive`.

### F-0096: crash report lag lower bound -0.05 s too tight

**What:** `tests/integration/test_supervisor.py::test_crashed_child_is_reported_within_1s_restarted_by_policy_and_others_are_untouched` (line 520): `-0.05 <= lag <= CRASH_BUDGET_S` failed with lag -0.053 s (event time before the recorded death time); the other crash was 0.056 s.
**Run:** run 20261016-080313-0052a030, commit `0052a03`, `--foundation -q -rA`, exit 1. Green in the slow tier, run 20261016-080657-0052a030.
**Suspicion (assumed):** the death time is measured by a watcher thread of the test (`start_watch_death`) that wakes late under load, so it can lie after the event time; the tolerance of 50 ms is below the scheduling delay of a loaded machine. A test measurement problem, not a late report. Related to F-0071/F-0089 only by being load-sensitive. Not checked.
**Probable cause task:** none from the change under verification; load flake of an older test.
**Update (bug hunter, round 14):** Read in code (verified): `lag` is the difference of two `time.perf_counter()` stamps, taken by two Python threads of the test: the death watcher (`start_watch_death`, stamps after `psutil.Process.wait` returns) and the event reader (`Watch._run`). The supervisor reports within a few ms, so a death watcher that is scheduled 50 ms later than the reader gives a negative lag; the product cannot report a death before it happened. Cause: noise of the test's own timestamps (assumed under load, not reproduced; the test is green alone, run 20261016-085756-5f78f214-wc, 1 passed). Fix: the lower bound is `-CRASH_LAG_NOISE_S` = `scaled(0.25)` (0.25 s serial, 0.75 s parallel); it still rules out a report long before the death. Waits for a repeated slow run to be closed.

### F-0103: busy-report test failed once in a fast run

**What:** `tests/integration/test_worker.py::test_worker_reports_busy_when_a_job_begins_and_ends` failed once in a fast run. Three serial reruns passed.
**Status:** observed once, not reproduced. The failure text was not analysed, so the cause is not known.
**Action:** On the next failure keep the failure text and the load of the run (`tools/test_history.py --flaky`, `--test` with the test ID). Check whether the busy report can arrive after the job has ended under load.

### F-0104: ping requests of the blocking-element test use an unscaled timeout

**What:** The block time of `test_pings_are_answered_while_a_blocking_element_runs` goes through `scaled()`, but each of the three `worker.request("worker:1", "sys.ping", ..., timeout=1.0)` calls in `tests/integration/test_worker.py` (about line 260) uses a fixed 1.0 s. Under load a late pong then fails as a request timeout. This is separate from the measured limit of F-0094.
**Status:** assumed (read in the code, not reproduced under load).
**Action:** Scale the request timeout as the block time is scaled, or state why 1.0 s is enough under load.

### F-0105: the summary line of a role can come late or not at all

**What:** A role writes its summary line lazily. After a burst of log lines the summary can come late or not at all. The hub's own summary line goes through the log sink; this path was not checked.
**Status:** assumed, not checked (suspicion of an earlier session; no reproduction).
**Action:** Write a test that sends a log burst to a role and checks its summary line. Check the summary path of the hub.

### F-0106: `run_suite` slow-run header named another commit than the run folder

**What:** The header of the output of one slow run named another commit than the run folder. Reading `tools/run_suite.py` (lines 189 to 195), the header label and the run folder both come from the commit that `--ref` resolves to, so the reading does not explain the mismatch.
**Status:** observed once, not reproduced, not checked.
**Action:** On the next slow run compare the header with the run record (`sha`) for a plain `--ref` run and for a `--with-changes` run.

## Watch list (E0007)

These items were deliberately not fixed in phase 2b. Closed items (F-0004, F-0006, F-0010, F-0015, F-0018 and others) are not listed. The findings above are not repeated here.

- **`deadlineMs` of `sys.shutdown` is not used everywhere.** `Storage.OnShutdown` uses it, and since WI-0041 `Engine.OnShutdown` does for the variable writes (the rest of the deadline is the limit of each request); the instances still stop with a fixed 2 s each. `StubManager.OnShutdown` does not. The hard deadline is enforced by the supervisor, which is enough for now. *Sign:* a role needs more cleanup time than the deadline allows, and the supervisor kills it (for example the engine when many instances stop). *Action:* derive a partial deadline per instance (2 s, see `doc/ARCHITECTURE.md` 6.3) in `Engine.OnShutdown`. *Evidence:* `src/engine/Engine.ahk:76`, `src/manager/StubManager.ahk:99`, `src/storage/Storage.ahk:62` (as cited in `v2-phase2-final:work_items/STATUS.md`).
- **`tests/support/pyhub.py` sends no wake-up.** `PyHub` answers only by polling (fallback timer, latency about 250 ms). Only `tests/support/test_client_hub.py` uses it; all other tests use `WakingHub`. *Sign:* a new time-critical test uses `PyHub` and misses a deadline. *Action:* switch to `WakingHub`, or add the wake-up to `PyHub` (see `doc/ARCHITECTURE.md` 2.2).
- **Idle CPU.** The target is met: 0.23 % of the total system (E0005). The reading "sum in percent of one core" gives 1.8 %, which misses the target; the reading is still open. A possible improvement is to keep the engine's safety timer (`SAFETY_MS = 100`, `src/engine/Engine.ahk:33`) active only while instances run. *Sign:* idle CPU above 1 % in a measurement with an editor (phase 3). *Action:* re-measure with the WI-0016 method after the change.
- **Sporadic dialog test `test_msgbox_is_captured_and_closed`.** One timeout in phase 2 (the ctypes argtypes cause was fixed). In WI-0018 two dialog-watcher tests failed under parallel load. The cause is assumed (reused process IDs in the watcher), fixed in `tools/ahf_dialogwatch.py`, and not reproduced. *Sign:* a test exits with 0 instead of 97, or times out. *Action:* read the dialog report in `%TEMP%\ahf_dialogs\` (the file name contains the test PID since WI-0018).
- **Deadlines of a role after standby (WI-0033).** `Peer.Request` sets each deadline with `SetTimer`. After a standby, all due deadlines of one role fire at once (answer `timeout`, the caller retries). *Status:* not checked; only a freeze of the supervisor was tested (with `psutil`), not a real standby. *Sign:* many `timeout` answers or retries at the same time after wake-up. *Action:* use a deadline list per role, as in `Hub.Tick`/`Hub.Shift`, and measure the stall per role.
- **Empty `--data=` writes to `C:\Log` (E0015).** The owner decided that this is acceptable for now. *Sign:* unexpected files in `C:\Log`, or logs missing from the data folder. *Action:* reject an empty value at start (exit 2 with a message). Not rechecked in WI-0032; the item comes from the review.
- **Factor 3 of `scaled()` (E0017).** The owner decided to keep the factor 3 for parallel runs. Cycle 1 of the WI-0035 acceptance neither confirmed nor refuted it: no run showed that it is needed or too loose. *Sign:* a scaled limit fails in parallel runs. *Action:* observe; the decision (E0017) stays as it is.

## Known problems still open

- **Test runtime grows.** At the end of phase 2b the run took 113 s in parallel and 596 s serially (706 tests). In WI-0035 cycle 1 the parallel runs took 137 to 164 s, the serial run 728 s (752 tests). Each package adds time. *Action:* watch it with each full run.
- **Delete command for a running flow is missing (phase 3).** `Executor.FlowDeleted` stops the instances at once, without a deadline and without an acknowledgment (E0009, confirmed by the owner on 2026-10-12). In v1, `DeleteFlow` gave up after 10 s. The command itself is not built yet.
- **Dangling connections.** 154 of 1039 connections in the example flows are dangling. M-0013 defines the behavior: ignore them and report them with an `f1` log entry (documented in `doc/MIGRATION.md`).
- **Parallel runs under load.** F-0018 (the time limits) is closed. The remaining risk is F-0032, F-0041, F-0043 and, since 2026-10-13, F-0060 to F-0063 (see above). The default run (fast tier) showed none of them in about 10 runs; the `--all` run with 8 workers showed one different test in about every second run. A gate with fewer workers (`-n 4`) is not measured yet.
- **Progress checkboxes.** In `v2-phase2-final:work_items/phase2/README.md` the phase 2 checkbox is set. WI-0013 and WI-0014 were deliberately not checked. WI-0017 is checked only after step 7 (phase 3 plan and questions to the owner) is done.
- **Foreign process.** `AutoHotkey64.exe` (PID 29328, `/restart /script ...\src\AutoHotFlow.ahk`) was reported in earlier runs. It was gone on 2026-10-11, and the tests never started or stopped it. *Action:* none; check if it reappears.

## Not checked

- Timing under system load (parallel runs; see F-0032, F-0041, F-0043).
- A real second Windows user connecting to the pipe (F-0017 is closed on the DACL test only).
- Standby (see the watch list item on deadlines after standby).
- Screenshots with a locked desktop.
- Real blocking dialog elements in a worker.
- Worker pool in a long run with more than 3 workers.
- Trigger host (not built).
- AHK client (editor) as the other side of the latency measurement.
- Idle CPU and memory with a warm worker (not measured again).
- Editor memory with 5 open editors, and redraw time (no editor role yet).

## Not built yet (phase 3 scope)

Editor, real manager, real elements, trigger host (WI-0014, decision E0006: built early in phase 3), expression evaluation, translations, import and export. `cmd.flow.patch` knows only the schema and the revision check. The delete command for a flow is missing (see above).

## Open actions

Work that is open but is not a finding with an entry. Rule: a finished action is deleted from this list, not marked as done; its history is in the git log.

1. **Three `uncaught/timeout` cases** in the groups `assignment` and `script` of the golden check (reported by the verifier, not investigated). Check whether they are the known hangs of the v1 parser.
2. **Small test gaps of WI-0048 (verifier, `7007f78`).** (a) `Action_Do_nothing` with `executionResult` set to `Exception` has no test; the result `exception` is new behaviour. (b) `ProductRegistersElements` asserts only `Length >= 3`; a test should compare the registry with the element files of `src/elements/*/` (or check that `tools/gen_element_includes.py --check` covers it, not checked). Do it with the next element work, in one small commit.

3. **Distinct code for "flow not loaded yet".** Right after an engine restart `cmd.flow.start` is answered `not_found` while the flows are still loading (from F-0061, closed). A code such as `not_ready` would be clearer. Not decided; the manager of phase 3 follows the resync rule in PROTOCOL 4.8 meanwhile.

## Open decisions

None here. The decisions waiting for the project owner are in `NEEDS-ATTENTION.md` (repository root).

Decisions on entries are in the summary table (status `decision needed`, `accepted`, `closed`) and in the status book `work_items/phase3/STATUS.md`, section "Decisions of the project owner".
