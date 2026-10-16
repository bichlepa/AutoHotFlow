# Phase 3 status (current state)

Kept by the orchestrator as described in `doc/ORCHESTRATOR.md`. This file shows the **current state only**: one line per work item, the last verified state, running agents and the open observations that are recorded only here. The history (session logs, finished agent tables, run-ID lists of old states) is in the git history of this file; the last long version is commit `16b47b6`. Decisions are in `doc/DECISIONS.md`, findings in `doc/OPEN-ITEMS.md` and `doc/CLOSED-ITEMS.md`, the plan in `work_items/phase3/README.md`.

## Work items

Step S0001 (expressions and variables), state as of `cac616b`.

| WI | Title | State | Model | Commits | Date | Note |
|---|---|---|---|---|---|---|
| WI-0036 | Golden data from v1 | done | sonnet | 786a688–829ce0f | 2026-10-13 | 2161 cases, frozen since E0035 |
| WI-0037 | Expression language: parser | done | sonnet | 0a24b4c–6023cde | 2026-10-13 | `src/expr/`, `doc/EXPRESSION-LANGUAGE.md` |
| WI-0038 | Evaluator | done | sonnet | ebcb01e–0506198 | 2026-10-14 | Decisions to confirm in the work item |
| WI-0039 | Converter of v1 expressions | done | sonnet | 7732b8e–1e444c2 | 2026-10-14 | Catalog accepted; F-277 open |
| WI-0040 | Variable model in the engine | done | opus | deade8e–84a3912 | 2026-10-14 | Verified; M-43 confirmed |
| WI-0041 | `global`/`static`, data folder | done | sonnet | 4f3c3ce–2c20eff | 2026-10-14 | Real data folder not checked |
| WI-0042 | Parameter evaluation, `ctx` API | done | opus | c2949f6–c70025e | 2026-10-14 | GUI and triggers not checked |
| WI-0043 | Acceptance S0001 | done | | 78cf1bd–7f802bf | 2026-10-15 | Closed by the owner (E0050) |

Step S0002 (element foundation and core set), state as of `cac616b`.

| WI | Title | State | Model | Commits | Date | Note |
|---|---|---|---|---|---|---|
| WI-0044 | Oracle of the expression language | done | sonnet | 6cb6541–c860a0b | 2026-10-14 | Corpus count 3000 vs 3200: see below |
| WI-0045 | Migration markers | done | sonnet | e340c64–a8ac273 | 2026-10-15 | Stress 200 flows passed |
| WI-0046 | R0003 measurement | done | sonnet | a840b44–88f0ad0 | 2026-10-15 | R3 not closed: memory is an owner decision |
| WI-0047-PREP | Role entry scripts | done | sonnet | b874545–1aceedd | 2026-10-15 | E0041; 49 MB after, 1 worker |
| WI-0047 | Element layout per package | done | opus | 862f392–d179825 | 2026-10-15 | E0045 qualified IDs |
| WI-0048 | L0001 smoke test | done | sonnet | a7c469a–7007f78 | 2026-10-15 | Verified |
| WI-0049 | Flow builder, headless runner | done | sonnet | 50635b5–4aca8e8 | 2026-10-15 | One criterion (loops) met by a shape test |
| WI-0050 | R0004 `ctx.Request` | done | opus | c4e29cc–5359b78 | 2026-10-15 | Round trip about 1.0 ms |
| WI-0051 | Dialog indirection, test provider | done | sonnet | b09ca61–3d553b7 | 2026-10-15 | E0038 |
| WI-0052 | Core set A: variables, conditions | done | sonnet | e4b8276–13100b6 | 2026-10-15 | Verified; churn test F-0092 fixed later |
| WI-0053 | Core set B: lists | done | sonnet | 5857a59–15132a2 | 2026-10-15 | Verified |
| WI-0054 | Core set C: loops | done | sonnet | be5c088–2467349 | 2026-10-16 | Verified; REQ-ELM-240 partial |
| WI-0055 | Core set D: flow control | done, verified | opus | e4b368d–949afc2 | 2026-10-16 | Fix of F-0100 class open; see NEEDS-ATTENTION |
| WI-0056 | Core dialogs (dialogs and worker) | not started | | | | Depends on WI-0050, WI-0051 (both done) |
| WI-0057 | Test corpus | not started | | | | Depends on the core sets |
| WI-0058 | Acceptance S0002 | not started | | | | Last item of S0002 |

Step S0008 (remaining elements) is planned, not started.

Step-independent work item: WI-0059 (test admission, load report, run history), done, closed by the owner's criterion, commits 9cefa8c–ce1024f (plus AGENTS.md commits 2524a5d, 1120c28).

## Pending integrations

None.

## Running agents

| Slot | Role | Workspace | Model | Task |
|---|---|---|---|---|
| 1 | Implementer | wi-0056 | haiku | WI-0056, started from `4af717b`; waiting for its own background run |
| 4 | Documentation helper | docs-cleanup | haiku | HOW-TO cleanup and the 11 status-book notes (owner delegated) |

F-0012 round (hunt-1) is integrated and its workspace removed; its review approved it without fixes.

## Last verified state

Commit `220fbe5` verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261016-174506-220fbe53-3` (1083 passed, 1 skipped), foundation run `20261016-174506-220fbe53` (461 passed, 1 skipped), slow run `20261016-174506-220fbe53-2` (154 passed). The storm smoke test that failed earlier passed here (F-0101 stays open to watch).

Earlier, commit `949afc2` (WI-0055), verified by the last verifier agent: fast run `20261016-164136-949afc21` (1006 passed, 1 skipped), foundation run `20261016-164302-949afc21` (461 passed, 1 skipped), slow run `20261016-164502-949afc21` (154 passed); architecture, requirements and include checks 0. F-0100 was not reproduced in that run. Later commits up to `cac616b` change only documents. From now on `tools/verify.py --auto` keeps the last green state (ORCHESTRATOR section 4).

Tree hashes (`git rev-parse <commit>:<path>`): `src` `687433af`, `tests` `a26eb334`, `tools` `7228456c`.

## Recorded only here

None. On 2026-10-16 all notes of this section were moved to `doc/OPEN-ITEMS.md` (F-0103 to F-0106), to `doc/MIGRATION.md` (owner confirmation of M-0038 to M-0048) or dropped as covered by a document (`doc/TEST-STRATEGY.md` for the corpus size, `doc/MANUAL-CHECKS.md` section 1, `doc/ORCHESTRATOR.md` section 3c, `tests/test_open_items_ids.py` for the skip in a workspace, `AGENTS.md` for the interpreter option).

