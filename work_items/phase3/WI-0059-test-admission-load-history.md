# WI-0059 Machine-wide test admission, load report and run history

Size: M · Depends on: – · Blocks: – · Inserted by the project owner between the work items of S0002 (2026-10-15). Not part of the step table of `README.md`; it is a tooling work item.

## Goal

Test runs of parallel agent sessions must not overload the machine, whichever way pytest was started. Every run records the machine load next to its results, so that load-induced failures can be told from real ones and a long-term history exists (flaky tests, load dependence, duration trends).

## Facts (verified)

- `tools/run_suite.py` has an admission (Admission lock file, `active_runs()` over `status.json` with pid and create time, `--max-runs` default 2, exclusive for stress/soak). It only covers runs started through `run_suite`.
- A direct `python -m pytest tests` runs through `tests/conftest.py` without admission and registers nowhere.
- `pytest.ini` has `-n auto`: one worker per logical core for every run, regardless of other load.
- `prune_old_runs` deletes old run folders in the registry (`%TEMP%\ahf_runs`).
- `/temp` is already in `.gitignore`.
- Worktrees of the parallel agents live outside the main checkout (`AutoHotFlow-wt\<name>`), so a path relative to the current project folder differs per workspace.
- Rule in `doc/TEST-STRATEGY.md`: no automatic rerun. This stays.

## Part A: Admission

- Shared module `tests/support/admission.py`: `Admission`, `active_runs`, `write_status`, `_alive` move there (moved, not copied); `run_suite.py` imports it.
- `conftest` takes part: `pytest_cmdline_main` (controller only, not the xdist workers) calls `admit()` before collection. `pytest_sessionfinish` sets the state to done. A run started through `run_suite` registers only once: `run_suite` sets `AHF_ADMITTED=<run id>`, `conftest` skips its own admission then.
- Slots are workers: the sum of the registered workers of all running runs stays ≤ `AHF_MAX_WORKERS` (default: logical cores − 2, at least 1). A run gets `min(requested, free slots)` workers, at least 1. `-n auto` counts as "all cores − 2".
- Exclusive runs (`-m stress` / `-m soak`): as in `run_suite` today, they wait for an idle machine and block others while they run.
- Waiting: no time limit (`AHF_ADMISSION_TIMEOUT` is optional, default unlimited). A message to stderr every 30 s: "waiting: 2 runs active, 6/6 workers". The waiting time goes into the history record.
- Opt-out for the owner and for debugging (`-n 0 -s`, `--pdb`): `AHF_NO_ADMISSION=1`.
- Crash safety: entries of dead pids are ignored (existing `_alive`), a stale lock file expires after 30 s (existing).

## Part B: Load measurement

- Sampler in the controller (thread, 1 s): system CPU (`psutil.cpu_percent`), CPU of the own process tree, and the number of registered runs. "External load" = system minus own tree, clamped at 0. Time series with timestamps in memory.
- Per test: start and stop times from `pytest_runtest_logreport`. For every test (not only red ones) the plugin stores mean and peak of system CPU and external CPU in its window, and the maximum number of concurrent runs.
- Terminal summary: for every red test one line with these numbers, so the load is visible at the first look. No threshold, no classification.

## Part C: Run history

- Location: `temp/history/` of the main checkout, resolved with `git rev-parse --git-common-dir` (its parent folder), so every worktree writes to the same place. Fallback when there is no main checkout or it is not writable: `<AHF_RUNS_DIR>\history\`. Override: `AHF_HISTORY_DIR`. The path is printed at the end of every run next to the path of the run's own log. `prune_old_runs` never touches this folder.
- One JSON file per run: `<timestamp>_<run id>.json`, written at the end of the session (also after `KeyboardInterrupt`, with `"complete": false`). Writing is atomic (temp file, rename). One file per run needs no locking between parallel runs.
- Content:
  - Run: id, start, end, duration, waiting time, host name, logical cores, `AHF_MAX_WORKERS`, workers granted, pytest arguments, tier/markers, started through `run_suite` or directly.
  - Code: commit SHA, branch, dirty flag (uncommitted changes; a `run_suite --with-changes` run is dirty), worktree path.
  - Where the logs are: path of the run folder, `output.txt`, run log, location of the dialog screenshots if any.
  - Load: mean and peak of system and external CPU over the whole run, maximum concurrent runs, number of own processes at peak.
  - Result: counts per outcome, and per test: node id, outcome, duration, load figures from Part B. For red tests also the first line of the failure text.
- Parse script `tools/test_history.py` (read-only, needs only the JSON files):
  - `--last N`: table of the last runs (time, commit, counts, duration, mean external load, log path).
  - `--flaky [--since DATE]`: tests that were red and green at the same commit (clean runs only), with the load figures of the red runs next to those of the green runs. This is the strongest signal for load problems.
  - `--test <node id>`: history of one test (outcome, duration, load, commit).
  - `--load`: red rate and test duration over buckets of external CPU (0–10 %, 10–25 %, …). This is the data from which a threshold could be derived later, if one is ever needed.
  - `--durations`: tests whose duration grows over commits.
- Recheck tool `tools/recheck.py <run id | latest>`: takes all red tests of a run from the history and runs them serially (`-n 0`) under an exclusive admission. Output per test: green again (consistent with load) or red again (real defect or test problem, classify as before). The first result stays in the history; the recheck is a run of its own with its own record (field `recheckOf`). It is a defined second run under reference conditions, not a retry loop.

## Acceptance criteria

- Two `python -m pytest tests -q` started at the same time (without `run_suite`) never use more workers than `AHF_MAX_WORKERS` together; the second logs "waiting" and starts afterwards.
- A run through `run_suite` registers only once.
- A killed run frees its slots at the latest at the next admission check.
- Every run (green, red, interrupted) leaves one valid JSON file with commit, dirty flag, log path and load figures.
- Two runs from two different worktrees write into the same history folder.
- With synthetic load (a helper burns N cores during a test window) the external CPU of that test is clearly higher than for the same test without load. The test checks the relation, not absolute numbers.
- `test_history.py --flaky` finds a test that is red and green at the same commit in prepared history files (fixtures in a tmp dir).
- Unit tests for admission and history writing use their own `AHF_RUNS_DIR` / `AHF_HISTORY_DIR` in a tmp dir and never the real registry or the real history.

## Docs

Done in this work item:

- `doc/TEST-STRATEGY.md`: admission, load figures, history, recheck; one sentence on how the recheck differs from the forbidden automatic rerun.
- `doc/PARALLEL-WORK.md`: agents no longer need to coordinate test runs by hand; explicit exception: the test tooling writes only into `temp/history/` of the main checkout (ignored folder, no tracked content).
- `.vscode/tasks.json`: `Tool: test history (test_history.py)` and `Tool: recheck red tests (recheck.py)` (AGENTS rule 10).
- `doc/HOW-TO.md` only if something non-obvious turns up.

`AGENTS.md` is not changed by this work item. The integrator adjusts it afterwards, in a commit of its own. The report of the work item lists what is needed:

- Section "Tools in this environment": the new environment variables (`AHF_MAX_WORKERS`, `AHF_ADMISSION_TIMEOUT`, `AHF_NO_ADMISSION`, `AHF_HISTORY_DIR`, `AHF_ADMITTED`), `tools/test_history.py`, `tools/recheck.py`, the admission and the load figures in the description of the parallel test runs.
- Section "Working in parallel": the exception to "never change the main checkout" for `temp/history/`.
- Section "Tests run in parallel by default": the number of workers is limited by the admission (cores − 2 minus the workers of other runs).

## Not part of this

Adaptive time limits of `scaled()` by measured load. Reducing the process count of single tests. Any automatic decision based on the load figures.

## Risks and first task

- Not checked: whether an admission in `pytest_cmdline_main` works with `tryfirst`, the existing switch of `numprocesses` for stress/soak and the start of xdist. **The first task is a spike that proves this, before the rest is built.** Report the result of the spike in your report before continuing with Part A in full.
- The size of the history files is not measured. Estimate: some hundred bytes per test, below 1 MB per run at about 1000 tests. If it turns out larger, the per-test block can be thinned out for green tests (only duration and load).
- Reading the CPU of the own process tree through psutil costs time with many processes; the 1 s sampling has to be measured against the fast tier (budget: under 1 % of its run time).
- Writing from a workspace into the main checkout touches the rule of AGENTS.md ("never change the main checkout"). It is allowed only through the exception named above, and only for the ignored folder.

## Test notes for the implementer

- `tests/conftest.py` is shared: a change there requires the foundation tier (ORCHESTRATOR section 4).
- Do not run the stress or soak tiers; the owner decides.
- Do not run gui tests.
