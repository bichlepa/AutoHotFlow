# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-15, after the owner's decisions of the same day.

## Decisions

Other decisions of 2026-10-15 are in `doc/DECISIONS.md` (E0046 to E0051).

## Decisions

- **Test admission and run history (WI-0059), integrated as 9cefa8c to b53151a, verified on b53151a.** Four questions for you:
  1. Default `AHF_MAX_WORKERS` = cores − 2: the fast tier gets 6 workers instead of 8 even on an idle machine. Keep it?
  2. `-m "not stress"` runs exclusive and serial (the old behaviour, kept). Intended?
  3. Every test process runs in a Windows job object, for an exact own-CPU measurement (fallback: psutil walk). Accepted?
  4. Should the tooling tests (`test_admission.py`, `test_load_history.py`, `test_history_tools.py`) go into `FOUNDATION_FILES`? And should `recheck` test the run's commit in a worktree, as `run_suite` does, instead of the current checkout?
  The synthetic-load test (`test_external_load_shows_in_the_figures_of_the_test`) is slow-marked and still has to run once on an idle machine.
- **F-0090 may be back.** The persistence test failed twice (`evt.engine.ready #1 missing`) under high external load, in runs on an older base. Not yet confirmed on the final tip; see `work_items/phase3/STATUS.md`.

## To know

- **Lost log line under load (F-0088 closed 2026-10-15, F-0089 open).** F-0088 is fixed and verified (`doc/CLOSED-ITEMS.md`). F-0089 (three fault tests that fail only under load) is still open and not analysed.
- **Integration of `wip/requirements`** was done on 2026-10-15 (19 commits, rebased, index regenerated).
