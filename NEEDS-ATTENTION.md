# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-15, after the owner's decisions of the same day.

## Decisions

Other decisions of 2026-10-15 are in `doc/DECISIONS.md` (E0046 to E0051).

## Decisions

- **Test admission and run history (WI-0059), done.** Your decisions are implemented (`1120c28`, `ce1024f` and the commits before them): `AHF_MAX_WORKERS` stays cores − 2 (fast tier on an idle machine: 44.7 s with 6 workers, 41.2 s with 8, before the change; 48.2 s and 41.0 s after); `-m "not stress"` is not exclusive any more; the job object only counts, with a psutil fallback recorded as `ownTree`; the tooling tests are split; recheck runs at the commit of the run. The synthetic-load test ran green on the idle machine (run 20261016-083827-7ec528a4). **Note:** this follow-up was integrated without a verifier, because verifiers are paused; the implementer ran the fast tier and the foundation tier itself (foundation run 20261016-084047-7ec528a4, 460 passed).
- **F-0090 may be back.** The persistence test failed twice (`evt.engine.ready #1 missing`) under high external load, in runs on an older base. Not yet confirmed on the final tip; see `work_items/phase3/STATUS.md`.

## To know

- **Lost log line under load (F-0088 closed 2026-10-15, F-0089 open).** F-0088 is fixed and verified (`doc/CLOSED-ITEMS.md`). F-0089 (three fault tests that fail only under load) is still open and not analysed.
- **Integration of `wip/requirements`** was done on 2026-10-15 (19 commits, rebased, index regenerated).
