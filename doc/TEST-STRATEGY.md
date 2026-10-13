# Test strategy

Status: Draft. Tools checked in this environment: AutoHotkey v2 at `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`, Python 3.13, `psutil` available, `pytest` must be installed (`pip install -r tests/requirements.txt`).

## 1. Principles

1. **pytest is the driver for everything.** AHK code is started as a real process, not simulated.
2. **Python speaks the protocol.** `tests/support/ahfclient.py` implements framing, `sys.hello` and wake-up (`ctypes.windll.user32.PostMessageW`). This allows every role to be tested against a real hub connection. Confirmed in the spike: `open(r"\\.\pipe\...", "r+b", buffering=0)` connects to an AHK v2 pipe.
3. **Nothing hangs unnoticed.** Every test has a hard time limit (`pytest-timeout`), every started process is tracked in a fixture and terminated at the end together with its children (`psutil`).
4. **Isolation.** Every test gets its own temporary data directory (`--data=<dir>`) and its own session ID, so that pipe names do not collide and tests can run in parallel.
5. **Defined starting conditions, no dependency on `v1/`.** Test data lives in `tests/data/` (checked in, byte exact, see `tests/data/README.md`). A test never reads from `v1/`, never touches the default data directory (`%APPDATA%\AutoHotFlow`) and starts every process with its own `--data=<dir>`. As a safety net, `conftest.py` sets `AHF_DATA_DIR` (the supervisor's fallback when `--data` is missing, `Supervisor.DataDir`) to an empty guard directory; a test after which it is not empty fails (`default_dir_guard`). `A_AppData` itself cannot be redirected through `APPDATA` (verified). `tests/test_no_v1_dependency.py` enforces the first rule (exception: `tests/golden/`, which generates reference data with the v1 interpreter; the results are checked in).

## 2. Levels

| Level | Location | How | Purpose |
|---|---|---|---|
| **L1 Unit (AHK)** | `tests/ahk/*.test.ahk` | Small assert library `tests/ahk/lib/Assert.ahk`, one script per file, result as JSON lines in a file. pytest collects the files, starts them and evaluates the result. | pure logic: JSON, IDs, state machines, parser/evaluator, frame building |
| **L2 Integration** | `tests/integration/` | Start one or two roles for real, Python client as the counterpart. | IPC, dispatcher, timeouts, supervisor hub, storage queue |
| **L3 e2e** | `tests/e2e/` | Whole system (supervisor, engine, storage, trigger host, UI stub). Python behaves like an editor/manager. | flow runs, events arrive, start/stop/shutdown |
| **L4 Fault injection** | `tests/fault/` | Terminate processes (`kill`), freeze them (`psutil.Process.suspend()`), close the pipe, delay responses. | crash, hang, timeout without hanging in the whole system |
| **L5 Stress** | `tests/stress/` | many instances, rapid start/stop sequences, clients connect and disconnect under load. Fixed time budget, result as a report. | race conditions, leaks, message backlog |
| **L6 Characterization** | `tests/golden/` | Inputs and outputs of the v1 behavior as data (JSON). v2 must reproduce them. | expression evaluation, variable substitution, connection selection, load/save |

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
- Existing test flows (category "Automatic tests" in `tests/data/flows/v1_examples/`) will later serve as acceptance flows for the engine (run them, check the result).

## 5. Structure of the directory `tests/`

```
tests/
├─ requirements.txt           # pytest, pytest-timeout, psutil
├─ conftest.py                # fixtures: ahk_exe, datadir, run_role, hub (Python hub for role tests), cleanup
├─ support/
│  ├─ ahfclient.py            # framing, hello, wake, request/response with timeout
│  ├─ procs.py                # start/kill/suspend helpers, process tree cleanup
│  └─ ahk.py                  # search for the AHK interpreter (environment variable AHF_AHK2_EXE, default path)
├─ ahk/
│  ├─ lib/Assert.ahk
│  └─ *.test.ahk
├─ integration/  e2e/  fault/  stress/  golden/
└─ data/                      # flows/v1_examples, flows/personal, variables (synthetic), bigflows, skeleton_flow.json
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
