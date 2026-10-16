# WI-0058 Acceptance S0002

Size: S · Depends on: WI-0044 to WI-0057 · Blocks: S0003

## Goal

S0002 is demonstrably finished and the documents match the code. Afterwards S0003 is detailed.

## Tasks

1. **Checks:** the acceptance of S0002 in the README of this phase, point by point, with run IDs (smoke test, oracle, e2e, test corpus, measurements).
2. **Acceptance runs:** serial, parallel, `-m stress`, foundation (S0002 touches `src/Ahf*.ahk` and `tests/integration/helpers/`). Record the runtime of the full run and of the fast tier; if the fast tier has grown beyond its budget, propose a split.
3. **Documents:** `doc/ELEMENT-API-V2.md` (no open point of S0002 left in section 8), ARCHITECTURE (7, 8, 10: R0003 and R0004), PROTOCOL, MIGRATION, TEST-STRATEGY (7, 8, element tests, dialog tests), MEASUREMENTS, HOW-TO, CONVENTIONS, `AGENTS.md` (status), `work_items/phase3/STATUS.md`.
4. **Retrospective:** what did the estimate of the packages miss; how many of the v1 fixes of WI-0057 could a deterministic converter have made; what belongs in the scope of S0003. Briefly in the result.

## Acceptance criteria

All points of the acceptance of S0002 are met, or an open point is recorded in `doc/OPEN-ITEMS.md` with the agreement of the project owner.

## Result

Status: **partly done** (2026-10-16). All six acceptance points of S0002 are met with evidence (below). Open: task 3 (the documents besides ELEMENT-API-V2 section 8) and task 4 (retrospective) are not done in this package; the two new findings F-9501 and F-9502 wait for the project owner. Code state tested: commit `073b673` (the code is that of `a5d5d89`, WI-0057; the later commits change documents only). Branch changes: documents only.

**Acceptance points (README, "Acceptance S0002")**

1. **Smoke test green for every registered element: met.** `tests/ahk/element_smoke.test.ahk` (8 cases, serial, pytest `tests/test_ahk_runner.py -k element_smoke`: 8 passed) and in the fast runs `20261016-184147-073b6738` and `20261016-184636-073b6738`. It covers the engine block (every registered class of the product, not only the core set).
2. **Oracle: no deviation outside the list; the fixed corpus in the fast tier: met.** `tests/oracle/test_expr_oracle.py` serial: 7 passed (fixed corpus `tests/oracle/corpus.jsonl`, 3200 lines, asserted at least 3000; no open verdict). Also in the fast runs above. Not checked: the random-seed run (`-m slow`); F-0100 (its generator guard) is still open.
3. **Every core element has e2e tests through the flow builder; worker elements through the dialog seam: met.** All 27 classes of the core set table have a test in `tests/integration/test_core_a_*.py` to `test_core_e_dialogs.py` that builds the flow with `support/flowbuilder.py`; the four dialog and worker elements are answered by `support/dialogs.py` (DialogScript). Checked by grep for each class name and by the flow-builder use in each module, not by reading all 90 core tests. Caveat: the core set count (F-9501).
4. **v1 flows "variable test", "List test", "Loop test" and the synthetic flows headless and green, fixes with MIGRATION IDs: met.** Corpus run `20261016-184341-356` (`tests/integration/test_corpus.py -m slow`, serial, in the workspace): 21 passed in 40 s. "List test" and "Loop test" run as saved; "variable test" runs on the copy `tests/data/flows/v2_adapted/` with its one fix (two elements, `FIX_LIST`), documented as M-0069 in `doc/MIGRATION.md`. Sixteen synthetic flows green. The other 13 "Automatic tests" flows wait for S0003 and S0008 (table `PENDING`).
5. **R0003 and R0004 values in `doc/MEASUREMENTS.md`: met.** R0003: MS-0027 (parse time), MS-0028 (memory), MS-0029 (start), MS-0033 (after the role entries). R0004: MS-0031 (round trip 1.03 ms median). R0003 memory is above its threshold at 150 classes (MS-0028, +11.5 MB per process); this is decided (E0040, E0041), not open.
6. **Serial, parallel and `-m stress` green: met.** See the table of runs.

**Runs (all on commit `073b673`, `tools/run_suite.py`, 8 logical cores)**

| Run | Command | Result | Time |
|---|---|---|---|
| `20261016-184147-073b6738` | fast tier, parallel (4 workers) | 1121 passed, 1 skipped | 91 s (17 s admission wait) |
| `20261016-184636-073b6738` | fast tier, serial | 1121 passed, 1 skipped | 306 s (sum of test times 214 s) |
| `20261016-184426-073b6738` | foundation, parallel (4 workers) | 461 passed, 1 skipped | 124 s |
| `20261016-184341-356` | corpus, `-m slow`, serial (workspace) | 21 passed | 40 s |
| `20261016-185151-073b6738` | `tests/stress/test_big_flows.py -m stress`, serial | 2 passed | 57 s |

The one skipped test of the fast and foundation tiers is not identified (not checked). The gui tier and the slow tier besides the corpus were not run (the rules of the agents).

**Stress numbers (`20261016-185151-073b6738`)**

- Hub cost of one 109,235 character frame: mean 1.685 ms, max 1.882 ms (100 runs).
- 200 big flows (12.1 MB, 201 loaded): ready after 55.15 s (S0001: 59 s). The README names no budget for the time to ready. Snapshot during load: n=238, median 185 ms, p95 522 ms, p99 666 ms, max 689 ms, 0 timeouts. Budget 3 s (E0042): met; the maximum is below 1.5 s.

**Runtime of the fast tier (budget).** About 45 s by AGENTS.md. Measured: 91 s parallel, 306 s serial. Largest parts (serial): `test_ahk_runner.py` 584 cases (33 s), `test_core_e_dialogs.py` (29 s), `fault/test_var_persistence.py` (18 s). A split is proposed in F-9502; not decided.

**Document checks (task 3, partly).** `doc/ELEMENT-API-V2.md` section 8: no open point left (each item is decided, built or measured). The other documents of task 3 were not reviewed in this package.

**Decisions taken.** None. The split of the fast tier and the count of the core set are for the project owner.

**Findings written.** F-9501 (core set count 29 vs 27 listed, `Action_Sleep` in no row) and F-9502 (fast tier about twice its budget, split proposed), both in `doc/OPEN-ITEMS.md`.

**Commits.** Two: the findings in `doc/OPEN-ITEMS.md`; the result, the checkboxes and the status row.

**Not checked.** The random-seed oracle run, the slow tier besides the corpus, the gui tier, the retrospective (task 4), the documents of task 3 besides section 8, the per-test reading of the 90 core tests.
