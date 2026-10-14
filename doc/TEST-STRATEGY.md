# Test strategy

Status: Draft. Tools checked in this environment: AutoHotkey v2 at `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`, Python 3.13, `psutil` available, `pytest` must be installed (`pip install -r tests/requirements.txt`).

## 1. Principles

1. **pytest is the driver for everything.** AHK code is started as a real process, not simulated.
2. **Python speaks the protocol.** `tests/support/ahfclient.py` implements framing, `sys.hello` and wake-up (`ctypes.windll.user32.PostMessageW`). This allows every role to be tested against a real hub connection. Confirmed in the spike: `open(r"\\.\pipe\...", "r+b", buffering=0)` connects to an AHK v2 pipe.
3. **Nothing hangs unnoticed.** Every test has a hard time limit (`pytest-timeout`), every started process is tracked in a fixture and terminated at the end together with its children (`psutil`).
4. **Isolation.** Every test gets its own temporary data directory (`--data=<dir>`) and its own session ID, so that pipe names do not collide and tests can run in parallel.
5. **Defined starting conditions, no dependency on `v1/`.** Test data lives in `tests/data/` (checked in, byte exact, see `tests/data/README.md`). A test never reads from `v1/`, never touches the default data directory (`%APPDATA%\AutoHotFlow v2`, E33) or the folder of v1 (`%APPDATA%\AutoHotFlow`) and starts every process with its own `--data=<dir>`. As a safety net, `conftest.py` sets `AHF_DATA_DIR` (the supervisor's fallback when `--data` is missing, `Supervisor.DataDir`) to an empty guard directory; a test after which it is not empty fails (`default_dir_guard`). `A_AppData` itself cannot be redirected through `APPDATA` (verified). `tests/test_no_v1_dependency.py` enforces the first rule (exception: `tests/golden/`, which generates reference data with the v1 interpreter; the results are checked in).

## 2. Levels

| Level | Location | How | Purpose |
|---|---|---|---|
| **L1 Unit (AHK)** | `tests/ahk/*.test.ahk` | Small assert library `tests/ahk/lib/Assert.ahk`, one script per file, result as JSON lines in a file. pytest collects the files, starts them and evaluates the result. | pure logic: JSON, IDs, state machines, parser/evaluator, frame building |
| **L2 Integration** | `tests/integration/` | Start one or two roles for real, Python client as the counterpart. | IPC, dispatcher, timeouts, supervisor hub, storage queue |
| **L3 e2e** | `tests/e2e/` | Whole system (supervisor, engine, storage, trigger host, UI stub). Python behaves like an editor/manager. | flow runs, events arrive, start/stop/shutdown |
| **L4 Fault injection** | `tests/fault/` | Terminate processes (`kill`), freeze them (`psutil.Process.suspend()`), close the pipe, delay responses. | crash, hang, timeout without hanging in the whole system |
| **L5 Stress** | `tests/stress/` | many instances, rapid start/stop sequences, clients connect and disconnect under load. Fixed time budget, result as a report. | race conditions, leaks, message backlog |
| **L6 Characterization** | `tests/golden/` | Inputs and outputs of the v1 behavior as data (JSON). v2 must reproduce them. | expression evaluation, variable substitution, connection selection, load/save (expressions and variables: section 7) |

## 3. Important scenarios

**Fault injection (L4), each with the expectation "system stays operable, nothing hangs, the error is reported":**

| Scenario | Expectation |
|---|---|
| Editor process is terminated | Supervisor reports `evt.process.crashed`, engine and other editors unaffected, topic subscriptions of the editor disappear |
| Editor is frozen (`suspend`) | Detected as hanging after 3 missed pings, terminated, remaining roles keep running |
| Engine is terminated | Restart, `evt.engine.restarted`, clients perform resync, triggers re-armed |
| Engine is frozen | as above, after the ping timeout |
| Storage does not respond (frozen) | Requests run into a timeout, engine does not block, `evt.storage.error` |
| Worker crashes during execution | Thread ends with `exception`, engine keeps running, a replacement is requested (WI-27, `tests/fault/test_worker_lifecycle.py`) |
| Worker blocks in a call, abort or job deadline | Instance ends immediately, after 2 s the process is terminated, the next job runs on a new worker (WI-27) |
| Engine dies during a worker job | the new engine terminates the orphans, the pool rebuilds, the next job runs (WI-27) |
| Five failures of a pool within one minute | no new workers, worker elements end with "worker not available" (WI-27) |
| Snapshot of each role (`cmd.diag.snapshot`) | general part and role part in a fixed schema, no contents of variables and flows (WI-28, `tests/fault/test_snapshot.py`, schema in `tests/support/snapshotschema.py`) |
| Crash report with all roles, a frozen role, a crashed storage | folder `Reports/<time>_<reason>/` with one entry per role and a readable summary; the frozen role is noted as "no response", the report is there within the deadline; without storage it waits and stays in memory (WI-28, `tests/fault/test_report.py`) |
| Automatic report after crash, hang, error accumulation | exactly one report per minute, the rest is counted, none when shutting down (WI-28) |
| Debug window: `--command=debug`, closing, window | starts the role once, closing is not a crash, the window opens and closes as it does for the user (WI-28, `tests/fault/test_debug_role.py`; manual operation: result in `doc/MANUAL-CHECKS.md`) |
| Pipe is closed abruptly by the client | Hub cleans up, open requests to it are answered with `peer_gone` immediately (WI-34, F-40; implemented). Tests: `tests/integration/test_supervisor.py::test_open_request_to_a_client_that_goes_away_is_answered_with_peer_gone_at_once` and `..._to_a_child_whose_process_dies_...` (previously no response within 10 s, afterwards under 0.2 s), `tests/integration/test_engine.py::test_engine_resumes_loading_at_once_when_storage_dies_with_an_open_read` (engine without the 30 s of the read request) |
| Child reports itself only during shutdown | It receives `sys.shutdown` immediately on `sys.hello`, the session ends with exit 0 without waiting for the deadline (WI-34, F-41; `tests/fault/test_shutdown.py::test_a_child_that_says_hello_during_the_shutdown_gets_sys_shutdown_...`, test role `echo:slowhello<ms>`) |
| Debug window: process not `ready` | The refresh does not drop it; its entry reads `not ready (state: <state>)` (WI-34, F-38; `tests/fault/test_debug_role.py`) |
| Supervisor is terminated hard | All children terminate themselves after the orphan deadline |
| Shutdown with a hanging process | Total duration below deadline plus tolerance, hanging process terminated hard |
| Request without a response | Caller receives `timeout` after the deadline, a later response is discarded |

**Stress test (L5), minimum scope:**

1. Start 200 instances of a simple flow in parallel, all must end, no states remain `running`.
2. 1000 rapid start/stop changes of a flow, afterwards counters and states are consistent.
3. 20 editors (Python clients) connect and disconnect alternately while a flow is running. No lost engine response, engine latency stays within budget.
4. Soak run (minutes, not seconds), process count and memory stay stable.
5. Output as a report with latency distribution, so that before/after is comparable.

Note: The v1 hangs were never reliably reproducible. A comparison test against v1 is therefore not part of acceptance. Instead, the scenarios above are run repeatedly in v2 (e.g. 50 runs) without a single hang.

## 4. Round trip and compatibility

- For every file in `tests/data/flows/v1_examples/` and `tests/data/flows/personal/`: load, save, load again. The parsed structures must be equal **including types** (`"1"` stays a string). Unknown keys are preserved.
- Variables: read and write `.ahfvd`/`.ahfvar` pairs, identical content. The pairs in `tests/data/variables/` are synthetic and cover the formats (with and without BOM, CRLF, object content with mixed types). More are added when a feature needs them.
- `.ahf` export/import: round trip via ZIP.
- Existing test flows (category "Automatic tests" in `tests/data/flows/v1_examples/`) serve as acceptance flows for the engine (run them, check the result), from S2 on (WI-57) as far as their elements exist. They are not a v1 oracle (E35): a flow that needs a fix is adapted on a copy, and every fix is listed with its MIGRATION ID. Synthetic flows (flow builder, WI-49) carry the main load of the element tests.

## 5. Structure of the directory `tests/`

```
tests/
├─ requirements.txt           # pytest, pytest-timeout, psutil
├─ conftest.py                # fixtures: ahk_exe, datadir, run_role, hub (Python hub for role tests), cleanup
├─ support/
│  ├─ ahfclient.py            # framing, hello, wake, request/response with timeout
│  ├─ procs.py                # start/kill/suspend helpers, process tree cleanup
│  ├─ flowbuilder.py          # builds flow files in Python (section 9)
│  ├─ flowrun.py              # runs a flow headless and returns steps, log, probes (section 9)
│  └─ ahk.py                  # search for the AHK interpreter (environment variable AHF_AHK2_EXE, default path)
├─ ahk/
│  ├─ lib/Assert.ahk
│  └─ *.test.ahk
├─ integration/  e2e/  fault/  stress/
├─ golden/                    # golden data of v1 (section 7): cases, expected, harness for v1 and v2, FINDINGS.md
└─ data/                      # flows/v1_examples, flows/personal, variables (synthetic), skeleton_flow.json
```

## 6. Execution

```
pip install -r tests/requirements.txt
python -m pytest tests -q                        # fast tier (default, every change)
python -m pytest tests -q --foundation          # IPC / supervisor / diagnosis base, incl. its slow tests
python -m pytest tests -q --all -m slow          # slow tier only
python -m pytest tests -q --all                  # fast + slow + foundation + gui
python -m pytest tests -q --all -m gui -n 0      # windows and dialogs appear
python -m pytest tests -q -m stress              # long, on request only (-m soak: minutes)
```

**Tiers (marker-based, across the folders).** The folders say what a test checks, the markers say when it runs. Measured serial run: 752 tests, 10:44 min; 69 tests of 3 s or more took 433 s of them.

| Tier | Marker | Runs | Content |
|---|---|---|---|
| fast | none | default, every change | everything that takes less than about 3 s, shows no window and is not foundation |
| foundation | `foundation` (set centrally in `tests/conftest.py`: `FOUNDATION_FILES`, `FOUNDATION_AHK`) | `--foundation` or `--all`; when the base changes (see below) and at the end of every block | tests of the base that later packages are not expected to change: IPC (pipe, frame, peer, dispatcher), supervisor and process coordination (crash, hang, stall, shutdown, orphans, pipe break, timeouts), diagnosis (report, debug role and dump), the test tooling. About 60 % of the work of the default run before the split |
| slow | `slow` | `-m slow` or `--all`; at the end of a package that touches timing, supervisor, worker or storage, and at the end of every block | tests that wait for deadlines (hang detection, idle times, reconnect budgets, restarts in a row), about 3 s or more including the setup. Smoke variants in `tests/stress/` count as slow automatically |
| gui | `gui` | `-m gui` or `--all`; rarely, by hand, when the owner does not use the PC | tests that open a window or provoke a dialog on the desktop (debug window, `ahkrun` dialog guard with a real `MsgBox`) |
| stress / soak | `stress`, `soak` | `-m stress`, `-m soak`, serial | unchanged, see section 3 |

- A new test that waits for a deadline of the product or takes about 3 s or more gets `@pytest.mark.slow`. A test that must show a window gets `@pytest.mark.gui` (not `slow` at the same time: `-m gui` would drop it). Tests of windows stay `--headless` wherever the window itself is not the subject.
- `-m` only names the groups to switch on (conftest). Without `--all`, `slow`, `foundation` and `gui` are deselected unless named in `-m`. A test in several tiers runs only when all of them are on, so use `--all -m fault`, `--all -m slow`, `--all -m gui`. `--foundation` is the short form for the foundation tier including its slow tests (without gui).
- **Run log (every run).** `%TEMP%/ahf_testruns/<time>-<pid>/` (the path is printed at the end of the run; `AHF_TEST_LOGS` changes the folder; the newest 15 runs are kept): `summary.txt` (command, counts, failed tests, slowest 20), `results.txt` (every test in start order with UTC/local start time, outcome, duration), `failures/<test>.<phase>.txt` (times, xdist worker, traceback, captured output) and `data/<test>/` for every failed test: the data directory (`Log/*.txt`, `Reports/`, `*.stderr`) and `diagnosis/` with `snapshot_supervisor.json` and `report_answer.json`. The diagnosis is fetched from the supervisor while it still runs (the failure hook runs before the fixture teardown): the snapshot holds the log ring and the output of the children and works without `storage`; the crash report (`reason: test-failed`, written into `Reports/` of the data directory) is only requested when `storage` is connected. Without a `session_id` fixture (unit tests) or when the test ended the supervisor itself, `diagnosis-none.txt` says why there is none.
- **Times:** the application logs in UTC (`ts` yyyyMMddHHmmss), report folders carry local time; the run log shows both. Passed tests leave no data (`AHF_TEST_KEEP=1` keeps all directories as before).
- **When the foundation runs:** when a change touches `src/core/` (incl. `ipc/`), `src/supervisor/`, `src/AhfBoot.ahk`, `src/AutoHotFlow.ahk`, `src/debugview/`, `tests/support/`, `tests/integration/helpers/` or `tools/ahkrun.py`, and at the end of every block. Other changes (engine, storage, worker, elements, manager, editor) do not need it: they still start the real supervisor in the e2e and engine tests, so a break of the base shows up there too. A new role that the supervisor starts needs its entry in `tests/fault/test_snapshot.py` (that file stays in the default run for this reason).
- `FOUNDATION_FILES` is the one place to change when a test belongs to the base or no longer does. New test files of a topic that is not in the list are fast by default.
- Several tests exist as a smoke variant (`slow`) and a full variant (`stress`), e.g. the handle count of the supervisor over 12 restarts (smoke) and over 50 (full, `tests/fault/test_diagnose.py`).
- The strict reference run (`-n 0`, below) uses `--all`.
- **`--all` includes the `gui` tier** (3 tests that open windows). An agent never runs them, so an acceptance run by an agent is `--all -m "not gui"` (`-m` with a negation keeps the other tiers on). Stress and soak are never part of `--all`.
- **Acceptance of step S1 (WI-43), runtime of the full run.** On the code state of the end of S1 (1123 tests selected without gui and stress, 16 stress tests, 3 gui tests), measured with `tools/run_suite.py` on the development PC (8 logical CPUs, nothing else running except a planning agent): serial (`-n 0 --all -m "not gui"`) 1120 passed, 1 skipped, 2 xfailed in 772 s (12:52); parallel (`--all -m "not gui"`, 4 workers as the load budget of `run_suite.py` says) 1120 passed, 1 skipped, 2 xfailed in 200 s (3:19); `-m stress` 14 passed and 1 failed in 268 s (the 200-flow test, OPEN-ITEMS F-282). The serial run measured earlier in this document took about 640 s with 752 tests; the suite has grown by about 390 tests and the serial run by about 130 s since then (assumed: mostly the tests of S1 and the fixes of phase 2b, not broken down). The 2 xfailed are the known F-17 and F-275 marks, the 1 skipped is the deliberate skip of the runner self-check.

**Parallel (default since WI-18).** `pytest.ini` sets `addopts = -n auto --dist loadgroup` (pytest-xdist, 8 workers on this machine). `python -m pytest tests -q` (fast tier) thus runs in about 16 s with 8 workers (about 12 s with `-n 16`; the work adds up to about 100 s of test time). `--foundation` takes about 55 s, `--all` about 90 s (serial about 640 s). Serial: `-n 0`. Rules for this:

- Runs with `-m stress` or `-m soak` are switched to a single process by `tests/conftest.py` (`pytest_cmdline_main`) itself. Measurements (idle CPU, latency, memory) must never run in parallel with other load.
- The marker for groups is `@pytest.mark.xdist_group("name")` (with `--dist loadgroup`, tests of the same group run one after another on the same worker). `tests/test_ahk_runner.py` puts all items of one `.test.ahk` file into one group: its result cache is per process, without the group every worker that gets one case would run the whole file again (30 files were run up to 8 times each; the default run took 42 s instead of 32 s).
- **Time limits (WI-32).** An upper time limit that checks a promise of the product ("the role ends within 1 s", "crash reported within 1 s") runs through `support.timing.scaled()`: in the serial run (`-n 0`, `-m stress`, `-m soak`) it applies unchanged (this is the reference); in a parallel run (xdist worker) it is multiplied by the factor 3 (`AHF_TIMING_FACTOR` overrides it, `1` is strict). Only **upper** limits are scaled, never lower ones (a timeout must not fire too early), never counts or results. A red test in the parallel run then means "far too slow", not "somewhat slow on a loaded machine". A new time limit that checks a product promise must go through `scaled()`; measurements with fixed numbers (throughput, latency distribution) belong in `-m stress`.
- **The parallel run is not the reference (WI-34, E17).** Because `scaled()` relaxes the upper limits by the factor 3 in the parallel run, this run no longer detects a deterioration of latency up to this factor. The factor 3 stays. Therefore: **the serial run (`-n 0`) and `python -m pytest tests -m stress` are run at least at the end of every package that changes timing behavior, and at the end of every block.** They are the strict reference, their result counts. Waits for events that lie close to deadlines of the product (restart, end of a worker, detected hang) also run through `scaled()`; a fixed `timeout=` with a number next to such a deadline is a finding (F-42).
- **Do not automatically repeat red tests.** No `pytest-rerunfailures` and no loop that repeats a red test until it turns green. A flaky test can show a real error (F-26 was one, F-40 and F-41 were too). A red test is classified: test problem (then prove the cause and correct it, do not quietly relax a limit) or product defect (then a test that is red beforehand).
- **Wait for states, not for events.** A test that only subscribes after the `sys.hello` of a role can miss that role's event (e.g. `evt.engine.ready`) (PROTOCOL 5a). Either subscribe before the role starts or wait for the state (`Chain.wait_flows`, `cmd.process.list`).
- **Real time in AHK unit tests.** `WriteQueue` takes a clock (`WriteQueue(clock)`), the unit tests pass their own, and `storage_queue.test.ahk` sets `Critical` so that the timer of the queue does not process operations in the middle of the case.
- Every test needs its own names (session, data directory, pipe). No counting of "all AutoHotkey processes"; always recognize processes via the session ID in the command (`faultkit.session_processes`).
- AHK test scripts need `#SingleInstance Off` (present in `tests/ahk/lib/Assert.ahk` and the helpers), otherwise AHK asks on a second simultaneous start of the same script and the dialog guard ends the run (exit 15).

**Parallel work: runs on a frozen state.** `python tools/run_suite.py` runs the suite in its own git worktree
(`--ref <commit>`, or `--with-changes` for HEAD plus the uncommitted changes), so the working tree stays free while a
long run goes on, and the result belongs to exactly one code state. Output, `result.json` and the run log are in
`%TEMP%\ahf_runs\<id>\` (last 20 runs). Load budget: 4 xdist workers per run, 2 runs at the same time; a run with
`-m stress` or `-m soak` waits until no other run is active and blocks the start of others. Measurements therefore
stay comparable. Timing tests (`scaled()`) can still become flaky when other programs load the machine; for a
clean comparison use `--max-runs 1`. The run needs everything in the commit: a dependency on an untracked or
ignored file shows up as a failure here (this is how the `v1/AppData/Variables` dependency was found).

Environment variables: `AHF_AHK2_EXE` (path to the interpreter), `AHF_TEST_KEEP=1` (keep data directories after the test). `AHF_DATA_DIR` is set by `conftest.py` to the guard directory (product variable: data directory when `--data` is missing).

**Tests of step S1 (expressions and variables).** Where to look when a rule changes:

| Subject | Tests |
|---|---|
| Parser, evaluator, converter | `tests/ahk/expr_*.test.ahk` (tokenizer and literals, operators, script form, errors, cache, evaluation of operators and variables, `expr_v1convert`) |
| Golden data against v1 | `tests/golden/` (section 7); fast tier |
| Variable model | `tests/ahk/vars_model.test.ahk` (one case per rule), `engine_vars.test.ahk` (the Executor with real flows) |
| Global and static variables on disk | `tests/ahk/engine_var_files.test.ahk` (stand-in engine), `tests/fault/test_var_persistence.py` (real supervisor: round trip of v1 files, delayed write, kill of the engine, frozen storage) |
| Parameter evaluation and `ctx` | `tests/ahk/element_evalparams.test.ahk` (every content type, inline and worker, both modes), `core_lang.test.ahk`, `engine_flow_strict.test.ahk`, `tests/integration/test_worker.py`, `tests/fault/test_param_eval.py` |
| Expression language against native AHK v2 | `tests/oracle/` (section 8): fixed corpus in the fast tier, a random run of 20,000 cases in the slow tier |
| Loading and converting v1 flows | `tests/ahk/engine_flow_convert.test.ahk`, `tests/integration/test_flow_convert.py` |
| Acceptance of S1 | `tests/fault/test_s1_acceptance.py` (slow): a v1 flow from a copy of a v1 working directory (`tests/data/flows/s1_acceptance/`), converted on load, a variable of each kind, restart of the engine and of the session, and the copy of the v1 folder compared by file list and hashes before and after |

## 7. Golden data from v1 (L6, WI-36)

**Frozen since E35 (2026-10-14).** v1 is no longer the yardstick. The data below stays as it is and remains a regression test of the converter (WI-39); no new groups or cases are generated against v1. The oracle of the expression language is native AHK v2 (section 8, WI-44); the specification of an element is the AHK v2 behaviour and the v1 help text.

What v1 actually returns for expressions, scripts, variable substitution and variable access. The data comes from the v1 code itself, run with the v1 interpreter (`v1/AutoHotKey/AutoHotFlow.exe`, AutoHotkey_H 1.1.32, 32 bit), not from reading the code. It was the yardstick of the converter (WI-39): a converted expression returns in v2 what v1 returned, or its deviation is in the catalog.

| Path | Content |
|---|---|
| `tests/golden/cases/<group>.json` | the cases (inputs). Hand-written groups: `arithmetic`, `division`, `comparison`, `logic`, `concat`, `numbers`, `strings`, `variables`, `assignment`, `functions`, `errors`, `script`, `replace`, `builtin`, `varaccess`, `names`, `objects`. `corpus_flows` is generated from the example flows (below). |
| `tests/golden/expected/<group>.json` | the results from v1, one line per case (checked in; a change shows in the diff) |
| `tests/golden/FINDINGS.md` | the suspected v1 bugs confirmed or refuted with case IDs, further observations, what the corpus shows, what is not covered |
| `tests/golden/v1/harness.ahk` | the harness (v1 syntax, runs only in the v1 interpreter): includes the unchanged v1 sources (`Code tokenizer/parser/evaluator.ahk`, `Expression evaluator.ahk`, `Global variables.ahk`, `Variables.ahk`, `Jxon.ahk`, `Objects.ahk`) and replaces the rest of v1 (object store with the v1 `parseObjectPath`, critical section, logger, `lang`, flow and element properties) by small stand-ins. No dialog. Not named `*.test.ahk`, so pytest does not collect it. |
| `tests/golden/private/` | the project owner's own flows (E27), **local only, in `.gitignore`**, never checked in |
| `tools/golden_v1.py` | generator: cases to results |
| `tools/golden_corpus.py` | collects the cases of the corpus from flows |
| `tests/golden/test_golden_format.py` | pytest: every case file has a result file, both follow the format, the findings name existing cases; a sample of 12 cases is run in the v1 interpreter and compared with the stored results |

**Case.** `{"id", "kind", "text", ...}`. Kinds: `expression` (`Var_EvaluateExpression`), `script` (`var_evaluateScript`), `replace` (`Var_replaceVariables`, with `convertObjects`), `checkname` (`Var_CheckName`), `destination` (`Var_RetrieveDestination`, with `location`), `varget`, `varset` (`Var_Get`, `Var_Set`, with `value` and `location`). Optional: `vars` (initial variables per scope `instance`, `thread`, `loop`, `global`, `static`; JSON number = number, string = text, object or array = object), `common` (the functions without instance and thread, `Var_*_Common`, as used by editor and manager), `volatile` (value changes from run to run, only the type is stored), `note`, `sources`. The format is checked by `golden_v1.check_case` (unknown fields are refused).

**Result.** `outcome` (`ok`, `parse_error`, `eval_error`, `parse_error_ignored`, `uncaught_error` with the dialog text in `detail`, `timeout` when v1 hangs for more than 8 s), `value` (`{type: number|text|object, value, text}`; `type` is determined the way Jxon does it, `text` is `"" . value`), `errors` (parser and evaluator, with phase, description, line, column), `errorText` (the text v1 returns to the caller), `variables` after the run in all scopes (assignments!), `log` (the v1 log lines, e.g. `f0` for a missing variable). For a number, `value` is a JSON number and `text` the exact v1 text (v1 writes floats with 6 decimals: `2.000000`); compare numbers by `value`, text forms by `text`.

**Generating.** On purpose only, not in every test run: VS Code task `Testdata: generate golden data from v1` or `python tools/golden_v1.py` (measured: about 2 minutes for 2200 cases, six of which hang and wait for the 8 s watchdog). `python tools/golden_v1.py --check` generates without writing and lists the groups that differ (reproducibility check). `--group NAME`, `--show ID` (debugging: run the cases whose id contains ID and print them). The generator starts the harness through `tools/ahkrun.py --interpreter` (dialog guard, timeout); a case that raises an uncaught error or hangs is recorded as such and the run goes on with the next case. The interpreter understands only `/ErrorStdOut` without `=UTF-8` (see HOW-TO).

**Corpus.** `python tools/golden_corpus.py` (task `Testdata: collect golden cases from the example flows of v1`) turns the parameter values of the example flows in `v1/AppData/Saved Flows` into cases. The content type of a parameter is read from the v1 element files (`Element_getParametrizationDetails_*`); when it is unclear, the value runs as expression and as substitution. `--stats` prints statistics, `--report` what the results show.

**Private data (E27).** `python tools/golden_corpus.py --flows <folder> --out tests/golden/private/cases/corpus_private.json`, then `python tools/golden_v1.py --private` (tasks `Testdata: golden data of the private flows ...`). The folder is in `.gitignore`. Only counts may leave the machine (WI-39, WI-43).

**Comparison with v2 (WI-39, WI-40).** `tests/golden/v2/harness.ahk` runs every case with the new language and the variable model of the engine; `tools/golden_compare.py` compares the result with v1 and gives each deviation one class of `tools/golden_classes.py` (the deviation catalog, `doc/EXPRESSION-LANGUAGE.md` section 15.1); `tests/golden/test_golden_v2.py` (fast tier) fails for a case without a class, for a class without a case, for a case that is still in a `rewrite` class after the conversion, and when the converter is not idempotent. Volatile cases and the `uncaught_error`/`timeout` outcomes are not expected to match (a failing or hanging v1 case is the class "v1 error"; a volatile case only needs a value in v2). State at the end of S1 (WI-43): of 2161 cases 1600 agree, 553 have an accepted class, 8 are syntax that is reported and not converted (decided by the project owner), none is open. `python tools/golden_v1.py --check` (about 2 minutes) reproduces the results of v1 byte for byte.

## 8. Oracle of the expression language: native AHK v2 (E35, WI-44)

The expression language follows AHK v2 (E22), so AHK v2 itself is the yardstick: generated expressions run once as real AHK v2 code and once in the evaluator (`src/expr/`), and the results may differ only by a fixed, named list of deliberate deviations (E25, E29, E34, and what the work item found, `doc/EXPRESSION-LANGUAGE.md` section 19). What is compared and what is not (dot paths, built-in variables of AutoHotFlow, the script form keep their specification tests) is in that section, 19.1.

| Path | Content |
|---|---|
| `tools/expr_oracle.py` | generator, writer of the native script, runner, comparison, the list of deviations (`CLASSES`), command line |
| `tests/oracle/eval_harness.ahk` | the evaluator side: the same cases and variables through `Expr.Evaluate` (the test resolver of `tests/ahk/lib/`); not named `*.test.ahk`, so the AHK runner does not collect it |
| `tests/oracle/corpus.jsonl` | the fixed corpus (checked in): the hand-written cases and generated ones (seed 1), one JSON object per line: `t` the text, optionally `m` the model text and `r` the deviation rules |
| `tests/oracle/test_expr_oracle.py` | pytest: the fixed corpus (fast tier), a random run of 20,000 cases (`slow`), tests of the classification |

**How a case runs.** Both sides get the same variables (`ENV` in the tool: numbers, texts that look like numbers, the empty text, edge values such as the limits of Integer, a `Map`). Native: one script per batch of 1500 cases, each case a function whose parameters are the variables (so every case has its own copy), `return (<text>)` inside `try/catch`; the output per case is `Type()`, `String()` or the class and message of the error. Evaluator: `Expr.Evaluate` with its own resolver per case; the output is the same, plus warnings, errors and missing variables. The scripts run through `tools/ahkrun.py` (dialog guard, timeout). A batch whose native process ends without a result (`MinInt // -1` ends AutoHotkey) is bisected and the case is reported as `NativeCrash`.

**Comparison.** A case is `same` (type and text equal, no warning, no error) or has exactly one class of `CLASSES`; anything else is `OPEN` and fails. A deviation that changes the value has a *model*: the same expression with the deviation applied in native code (`/` as a function `D`, a decimal literal beyond 63 bits with `.0`); the evaluator must agree with the model, so a deviation cannot hide a second difference. A native error (`TypeError`, `ZeroDivisionError`) must be a warning of the evaluator that carries the same message (class E25; in the strict mode of E34 the same warning is an error of the element, the same rule as `ParamEvaluator`). Not compared: the value of the whole expression after an error (the evaluator goes on, AutoHotkey ends the expression), and the variable values after an assignment.

**Generator.** Seeded (`random.Random(seed)`), grammar based: operators with the precedence of the language and the minimum of parentheses (so the precedence of the parser is tested; chains such as `1 < 2 < 3`), nesting up to 4 levels, mixed types, edge values (`0x10`, `1e3`, `" 5 "`, `-0`, the limits of Integer, `1e308`, division by zero), assignments (also nested), `Round` and `Mod`, `Map` members. It avoids what native AHK v2 cannot run: a string literal in front of an arithmetic operator (load error, `doc/HOW-TO.md`), `//` and `Mod` together with operands near the limits of Integer (the process would end), numbers out of the range of Float as text in a boolean test (F-284). The expression of a hand-written case is read by a small parser of the tool, which also makes its model.

**Tiers and budget.** The fixed corpus (3200 cases, 208 of them hand-written) runs in the fast tier: measured **2.7 to 3.1 s** (two AHK processes, parse and evaluation in about 1 s each; the test fails above 15 s, the target is under 10 s). The fast tier as a whole (`python -m pytest tests -q`, other agents running on the machine): 30.2 s with the oracle (636 tests) and 32.7 s without it (629 tests), so the oracle does not show in the total. A random run of 20,000 cases takes about 17 s (`@pytest.mark.slow`, test `test_a_random_run_shows_no_deviation_without_an_entry`; the seed is random, `AHF_ORACLE_SEED` fixes it, a failing seed is printed with the command to reproduce it). By hand: `python tools/expr_oracle.py` (fixed corpus), `python tools/expr_oracle.py --seed N --count N` (random, VS Code tasks `Test: expression oracle (fixed corpus)`, `Tool: expression oracle with random seed`), `--show "<expression>"` (one case on both sides), `--classes`, `--write-corpus` (regenerates the corpus; only on purpose, a change of the generator changes the corpus and its diff).

**Adding a deviation.** Only for a deviation that is decided (an `E` decision or a documented rule): an entry in `CLASSES` (text as in `doc/EXPRESSION-LANGUAGE.md` 19.2), a model if the value changes, and at least one case in the corpus (`test_every_deviation_class_has_a_case`). An unexplained difference is a finding: fix the evaluator, or write it into `doc/OPEN-ITEMS.md` and keep it out of the generator until it is decided (F-284 is an example).

**Does it see an error?** Checked once by hand (not a permanent test): with `<=` changed to `<` in `ExprEvaluator.Apply`, the fixed corpus reports 7 cases as `OPEN`. `test_the_oracle_notices_a_wrong_evaluator_result` checks the classification itself.

## 9. Flow builder and headless runner (WI-49)

How an e2e test of an element is written: the flow in Python, one call to run it, the result as data. `tests/support/flowbuilder.py` builds the flow file, `tests/support/flowrun.py` runs it in a real session (supervisor, storage, engine, entry point with the test elements); both have docstrings with the full API. Tests: `tests/support/test_flowbuilder.py` (no process), `tests/integration/test_flowrun.py` (one fast smoke test, three `slow`).

```python
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)

def test_an_exception_takes_the_exception_connection(flows):
    fb = FlowBuilder("exc")
    els = fb.linear("Trigger_Manual -> Action_TestThrow exception-> Action_Do_nothing")
    run = flows.run(fb)
    assert run.reason == "finished" and run.path == [e.id for e in els]
    assert run.state_of(els[1]) == ["exception"]
```

- **Builder.** `trigger`, `action`, `condition`, `loop` add an element (class and parameters; IDs, positions, package and defaults are generated), `connect(a, b, result, into)` a connection with the result `normal`, `yes`, `no`, `exception`, for a loop the parts `head`, `tail` (leaving) and `into="head"|"tail"|"break"` (entering). `chain` and the text form `linear("Class(par=value) -> Class yes-> Class")` build linear flows. `probe(names)` adds the test element that copies variables into global variables for the runner. Output: `v2=True` (default) is the v2 file (`formatVersion` 2, `strictTypes` as a boolean, no conversion on load); `v2=False` is the v1 format for conversion tests. Parameters keep their Python type.
- **Runner.** The fixture `flows` (import it into the test module) writes flows into the data folder, starts one session when the first flow runs (a flow added later restarts it), and ends it at teardown; a process of the session that is left behind fails the test. `flows.run(fb, timeout=10)` starts an instance and waits (`scaled()`) for `evt.instance.ended`. The `FlowRun` has `reason`, `steps` (`path`, `names`, `state_of`, `exceptions`: one entry per started execution, so a loop shows its body once per round), `log` (entries of the flow up to the end) and `probe(name)` (text, type and location of a variable at the place of a probe element). `flows.add_file(path)` takes a ready flow file, `flows.request_ok(to, type, payload)` sends a request to a role.
- **Variables.** `flows.preset_var(name, value, flow_id=None)` (before the first run; `flow_id` makes it static), `flows.read_var` and `flows.wait_var` read the pair files (the engine writes 200 ms after a change). Module functions `write_var`, `read_var`, `var_value`, `delete_var` work on any data folder.
- **Limits (verified).** The result of a condition (`yes`, `no`) is not an event (`evt.connection.state` is not sent yet), so a test reads the branch from the path. Events of several instances of one flow that run at the same time are not told apart (the element event has no instance ID). Instance and thread variables of a running instance are read with `instance_var` (requests of WI-50); after the end of an instance they are gone (`gone`), so a test that needs them reads them with `probe` while the instance runs. The runner waits for the engine to have loaded the flows and the variable files (counted, as `evt.engine.ready` can be missed by a late observer).
