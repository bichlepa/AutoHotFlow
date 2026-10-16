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
| WI-0056 | Core dialogs (dialogs and worker) | done, verified | haiku (review sonnet) | c5db6ab–6a8ad1a | 2026-10-16 | Review approved with fixes; tooltip and A_UserAction decisions open for the owner |
| WI-0057 | Test corpus | done, verified | haiku (review sonnet) | 7fa6b92–a5d5d89 | 2026-10-16 | 21 corpus tests, 3 v1 flows green (variable test as copy, M-0069); 13 flows pending S0003/S0008 |
| WI-0058 | Acceptance S0002 | done (all six criteria met; retrospective and document review in the result; 13 review items listed, none blocking) | haiku | see git log | 2026-10-16 | F-0107 and F-0108 closed by the owner |

Step S0003 (trigger host and triggers), detailed on 2026-10-16 (E0056 to E0062).

| WI | Title | State | Model | Commits | Date | Note |
|---|---|---|---|---|---|---|
| WI-0060 | Enabled state of triggers | done, verified (slow: one load flake, green alone) | haiku (review sonnet) | 7c3e41f–4bbe858 | 2026-10-16 | closes F-0099; reviewer approved |
| WI-0061 | Role `triggerhost` | running | haiku | | | parallel to WI-0060 |
| WI-0062 | Engine: arming, fired events | open | | | | |
| WI-0063 | Periodic timer and start-up triggers | open | | | | |
| WI-0064 | Hotkey trigger with window conditions | open | | | | spike first (E0059) |
| WI-0065 | Set_Flow_Status, Condition_Flow_Enabled | open | | | | |
| WI-0066 | Guard against runaway flows | open | | | | sets the defaults from its measurement (E0062) |
| WI-0067 | Acceptance S0003 | open | | | | |

Step S0008 (remaining elements) is planned, not started.

Step-independent work item: WI-0059 (test admission, load report, run history), done, closed by the owner's criterion, commits 9cefa8c–ce1024f (plus AGENTS.md commits 2524a5d, 1120c28).

## Pending integrations

None.

## Running agents

WI-0061 implementer (haiku), workspace `wi-0061`, branch `wip/wi-0061`. The manual-check start path (section 3 of MANUAL-CHECKS) is integrated; the owner runs it.

## Last verified state

Commit `4bbe858` (WI-0060 integrated) verified by `tools/verify.py --auto`: VERDICT red (slow) only. Fast run `20261016-213054-4bbe8581-2` (1128 passed, 1 skipped). Foundation run `20261016-213054-4bbe8581-3` (461 passed, 1 skipped). Slow run `20261016-213054-4bbe8581` (195 passed, 1 failed): `tests/e2e/test_ui_stub.py::test_headless_stub_logs_every_skeleton_event_in_order`. `tools/recheck.py` alone at the same commit: green (run `20261016-213913-23872`), a load flake; recorded in the run history, no OPEN-ITEMS entry (owner rule).

Commit `da2f2ef` (DPI fix of the dialog windows, REQ-USE-090 for the dialogs) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261016-191518-da2f2efb` (1123 passed, 1 skipped). Manual check 3 passed on the owner's side (2026-10-16).

Commit `c9cd4d3` (WI-0058 acceptance, result and renumbered findings) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261016-185723-c9cd4d36` (1123 passed, 1 skipped).

Commit `f741f4d` (F-0097, loop stack shares the outer snapshot) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261016-184825-f741f4db` (1123 passed, 1 skipped). Timing of the flow from F-0097 not remeasured.

Before that, commit `a5d5d89` (WI-0057) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261016-183314-a5d5d89b` (1121 passed, 1 skipped). The corpus module is `slow` and was run by its own runs on the branch (21 passed, serial and parallel).

Before that, commit `6a8ad1a` (WI-0056) verified: VERDICT green. Fast run `20261016-175915-6a8ad1aa` (1115 passed, 1 skipped), foundation run `20261016-175915-6a8ad1aa-2` (461 passed, 1 skipped).

Earlier, commit `949afc2` (WI-0055), verified by the last verifier agent: fast run `20261016-164136-949afc21` (1006 passed, 1 skipped), foundation run `20261016-164302-949afc21` (461 passed, 1 skipped), slow run `20261016-164502-949afc21` (154 passed); architecture, requirements and include checks 0. F-0100 was not reproduced in that run. Later commits up to `cac616b` change only documents. From now on `tools/verify.py --auto` keeps the last green state (ORCHESTRATOR section 4).

Tree hashes (`git rev-parse <commit>:<path>`): `src` `687433af`, `tests` `a26eb334`, `tools` `7228456c`.

## Recorded only here

None. On 2026-10-16 all notes of this section were moved to `doc/OPEN-ITEMS.md` (F-0103 to F-0106), to `doc/MIGRATION.md` (owner confirmation of M-0038 to M-0048) or dropped as covered by a document (`doc/TEST-STRATEGY.md` for the corpus size, `doc/MANUAL-CHECKS.md` section 1, `doc/ORCHESTRATOR.md` section 3c, `tests/test_open_items_ids.py` for the skip in a workspace, `AGENTS.md` for the interpreter option).

