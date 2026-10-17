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

Step S0003 (trigger host and triggers), detailed on 2026-10-16 (E0056 to E0062). Complete on 2026-10-17: WI-0060 to WI-0068 done and verified, acceptance WI-0067 closed (owner items P1 to P3 solved).

| WI | Title | State | Model | Commits | Date | Note |
|---|---|---|---|---|---|---|
| WI-0060 | Enabled state of triggers | done, verified (slow: one load flake, green alone) | haiku (review sonnet) | 1326e8e–4bbe858 | 2026-10-16 | closes F-0099; reviewer approved |
| WI-0061 | Role `triggerhost` | done, verified (slow: F-0101 once more, green alone) | haiku (review sonnet) | 8bfb58b–36480c0 | 2026-10-16 | reviewer approved; supervisor restarts it (owner decision pending) |
| WI-0062 | Engine: arming, fired events, TriggerVariables | done, verified | haiku (review sonnet) | 41d8bdb–e6aed49 | 2026-10-16 | reviewer approved; M-0069 done |
| WI-0063 | Periodic timer and start-up triggers | done, verified | haiku (review sonnet) | 436aeb4–1f8e62c | 2026-10-16 | reviewer approved; M-0071; provisional F-9000* is F-0111 |
| WI-0064 | Hotkey trigger with window conditions | done (input tests green, 2026-10-17; the gui tests are for the owner) | haiku (review sonnet) | d39a5bc–8e37e0b, input tests e658784 | 2026-10-17 | cause found: plain hotkeys on vk9A to vk9C do not fire for SendInput, tests use vk88 to vk8F and vkE8; F-0114 (provisional F-9000*) |
| WI-0065 | Set_Flow_Status, Condition_Flow_Enabled | done, verified | haiku (review sonnet) | 5adfc6b–1bcbb127 | 2026-10-16 | reviewer approved; M-0072 to M-0074 (M-0072 confirmed by the owner) |
| WI-0066 | Guard against runaway flows | integrated and verified (fast and foundation green; slow and stress by the author) | haiku (review sonnet) | ed35b78–0941cda | 2026-10-17 | default limit is the owner's decision (NEEDS-ATTENTION) |
| WI-0067 | Acceptance S0003 | done, verified; P1 (key delivery) solved 2026-10-17 and the hotkey measurement done (MS-0040), P2 manual checks 4 and 5 done by the owner | haiku (review sonnet) | 752097a–251e86bc | 2026-10-17 | point-by-point result in the work item; measurements MS-0038, MS-0039, MS-0040 |
| WI-0068 | Enabled state per flow file (E0063, answer to the FlowState read error) | done, verified (stress test 200 flows green) | haiku (review sonnet) | a313d3b–8d2eb98 | 2026-10-16 | reviewer approved after a fix (late read arms the merged triggers); F-0109 closed |

Step S0004 (UI foundation and manager), detailed on 2026-10-17 (E0064 to E0074), not started. Block A: WI-0069 to WI-0076, then the owner's manual check; block B: WI-0077 to WI-0082.

| WI | Title | State | Model | Commits | Date | Note |
|---|---|---|---|---|---|---|
| WI-0069 | `ui_common/`, dialogs, DPI, spike on modal dialogs | done, verified (fast red by one load flake, green alone; gui 3 passed) | haiku (review sonnet) | e653f44–255266b | 2026-10-17 | block A; spike: pings answered, timers stall up to 0.7 s; `FileSelect`/`DirSelect` open for the owner |
| WI-0070 | Flow lifecycle in engine and storage | done, verified (fast green, foundation green after recheck of one load flake, slow green on 21ff0da and cb7bee9) | haiku (review sonnet) | 6f848fd–21ff0da (13 commits) | 2026-10-17 | block A; a save and trigger switches are busy during a pending delete; deviations M-0078, M-0079 accepted by the owner |
| WI-0071 | Categories and the order of the list (`Categories.json`) | done, verified (fast, foundation, slow green; slow one load flake, green alone; stress 200 flows: ready 45.4 s, largest snapshot 622 ms) | sonnet/haiku (review sonnet) | 2606b20 (rebased series) | 2026-10-17 | block A; accepted: empty categories from hand-edited files stay, case-differing names are a quirk |
| WI-0072 | Tray icon and tray menu of the application (own role `tray`, E0075) | done, verified (fast, foundation, slow green on 3a32a30) | sonnet (review sonnet) | 3a32a30 | 2026-10-17 | block A; unlimited restart with growing pause, decided by the owner |
| WI-0073 | Manager: window, model, resync, headless driver, replaces the stub | done, verified on 72da2f6 (fast, foundation, slow green; stress 201 flows: filled after 0.54 s, snapshot 0.2 s; gui test 4 passed) | sonnet (review sonnet) | ec2a38b–72da2f6 | 2026-10-17 | block A; the product start does not start the manager yet (the tray does) |
| WI-0074 | Flow tree and operations | done, verified on 5590990a (fast, foundation green) | haiku/sonnet (review sonnet) | fd0de334–5590990a | 2026-10-17 | block A; owner decisions F-0117, F-0120; drag test fixed by sonnet (cross-process RECT) |
| WI-0075 | Notices | open | | | | block A |
| WI-0076 | Import from v1, manual check of block A | open | | | | block A |
| WI-0077 | Settings model | open | | | | block B |
| WI-0078 | Settings dialog, language, about | open | | | | block B |
| WI-0079 | Start with Windows, run as administrator | open | | | | block B, manual check |
| WI-0080 | Log display | done, verified (foundation, slow green; fast red by 2 load flakes, green alone) on d6331fb8 | haiku (review sonnet) | dcacd43b–d6331fb8 | 2026-10-17 | block B; F-0116 and source group wait for the owner |
| WI-0081 | `.ahf` export and import | open | | | | block B |
| WI-0082 | Acceptance S0004 | open | | | | |

Step S0008 (remaining elements) is planned, not started.

Step-independent work item: WI-0059 (test admission, load report, run history), done, closed by the owner's criterion, commits 9cefa8c–ce1024f (plus AGENTS.md commits 2524a5d, 1120c28).

## Pending integrations

None.

## Running agents

- WI-0075 (notices): haiku, workspace `wi-75`.
- Bug hunter for F-0116, F-0117, F-0120 and E0081: haiku, workspace `hunt-1`.

## Last verified state

Commit `5590990a` (WI-0074 integrated) verified by `tools/verify.py --tiers fast,foundation`: VERDICT green. Fast run `20261017-162956-5590990a-2` (1403 passed, 1 skipped), foundation run `20261017-162956-5590990a` (470 passed, 1 skipped). Before that `d6331fb8` (WI-0080): foundation and slow green (`20261017-154520-d6331fb8`, `-3`), fast red by 2 `pipe_write_gone` tests under heavy load (`-2`), green alone (run `20261017-162931-26520`).

Commit `72da2f69` (WI-0073 integrated; status commit `b01c23f`) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261017-144912-72da2f69-3` (1368 passed, 11 skipped), foundation run `20261017-144912-72da2f69-2` (470 passed, 1 skipped), slow run `20261017-144912-72da2f69` (199 passed). Manager stress run (WI-0073, 201 flows): `20261017-143840-12032`, filled after 0.54 s. Earlier: `271f3d5` (file dialogs, E0076) green, fast `20261017-141011-271f3d5d`, foundation `20261017-141011-271f3d5d-2`, slow `20261017-141013-271f3d5d`.

Commit `cb7bee9` (WI-0064 input-test skip on a locked PC, tasklist fix; on top of `21ff0da`, WI-0070 integrated) verified by `tools/verify.py` (no --auto base): VERDICT red (foundation) only. Fast run `20261017-120443-cb7bee90-2` (1298 passed, 1 skipped). Foundation run `20261017-120443-cb7bee90` (465 passed, 1 failed): `tests/integration/test_trigger_arming.py::test_the_engine_is_restarted_and_rearms_without_the_startup_context`; `tools/recheck.py` alone: green (run `20261017-122140-21548`), a load flake. Slow run `20261017-120443-cb7bee90-3` (199 passed). Owner decision (2026-10-17): slow tier not needed for now; future runs use `--tiers fast,foundation`.

Commit `21ff0da` (WI-0070 integrated, 13 commits) verified: foundation run `20261017-111638-21ff0da0` (466 passed, 1 skipped), slow run `20261017-111638-21ff0da0-3` (199 passed); fast run stalled and was stopped by the owner's order (no result).

Commit `255266b` (WI-0069 integrated, 7 commits from `e653f44`) verified by `tools/verify.py --auto`: VERDICT red (fast) only. Fast run `20261017-102543-255266bd` (1261 passed, 1 skipped, 1 failed): `tests/integration/test_trigger_state.py::test_an_unreadable_state_file_refuses_a_switch_until_it_can_be_read`; `tools/recheck.py` alone at the same commit: green (run `20261017-103235-2496`), a load flake; recorded in the run history, no OPEN-ITEMS entry (owner rule). Foundation run `20261017-102543-255266bd-2` (466 passed, 1 skipped). Gui tier, owner away: `tests/integration/test_dialog_windows_gui.py` 3 passed (run `20261017-103249-24164`).

Commit `e495a8cc` (review fixes of the input tests and the input lock, after WI-0067) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261017-090407-e495a8cc` (1240 passed, 1 skipped), foundation run `20261017-090407-e495a8cc-2` (466 passed, 1 skipped). Before that, `aca17d96` (hotkeys with real keys while the engine is blocked): fast `20261017-085945-aca17d96` (1234 passed, 3 skipped), foundation `20261017-085945-aca17d96-2` (466 passed, 1 skipped). Open: owner decision on whether the non-gui input tests run in the fast tier (NEEDS-ATTENTION.md).

Commit `251e86bc` (WI-0067 integrated) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261017-011502-251e86bc` (1226 passed, 1 skipped). Acceptance runs of the implementer on `8e7d403` are in the WI-0067 result.

Commit `8e37e0b8` (WI-0064 integrated, without the input tests) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261017-001911-8e37e0b8` (1224 passed, 1 skipped).

Commit `0941cda8` (WI-0066 integrated) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261017-001338-0941cda8` (1208 passed, 1 skipped), foundation run `20261017-001338-0941cda8-2` (466 passed, 1 skipped).

Commit `1bcbb127` (WI-0065 integrated) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261016-234518-1bcbb127-2` (1187 passed, 1 skipped), foundation run `20261016-234518-1bcbb127-3` (466 passed, 1 skipped), slow run `20261016-234518-1bcbb127` (197 passed).

Commit `8d2eb98` (WI-0068 integrated, last code change `8d2eb98`) verified by `tools/verify.py --auto`: fast red (one test, alone green: `test_worker_reports_busy_when_a_job_begins_and_ends`, recheck `20261016-232414`), foundation green (`20261016-231808-8d2eb981-3`, 466 passed), slow green (`20261016-231808-8d2eb981-2`, 197 passed). Stress test `tests/stress/test_big_flows.py` green on `8d2eb98` (run `20261016-232423-8d2eb981`, 2 passed).

Commit `1f8e62c` (WI-0063 integrated) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261016-225522-1f8e62c4-2` (1170 passed, 1 skipped), foundation run `20261016-225522-1f8e62c4` (466 passed, 1 skipped).

Commit `e6aed49` (WI-0062 integrated) verified by `tools/verify.py --auto`: VERDICT green. Fast run `20261016-222803-e6aed492` (1164 passed, 1 skipped), foundation run `20261016-222803-e6aed492-3` (465 passed, 1 skipped), slow run `20261016-222803-e6aed492-2` (197 passed).

Commit `36480c0` (WI-0061 integrated) verified by `tools/verify.py --auto`: VERDICT red (slow) only. Fast run `20261016-214703-36480c09-2` (1137 passed, 1 skipped). Foundation run `20261016-214703-36480c09-3` (462 passed, 1 skipped). Slow run `20261016-214703-36480c09` (196 passed, 1 failed): `tests/stress/test_start_stop_storm.py::test_start_stop_storm_leaves_a_consistent_engine[smoke]`, the F-0101 symptom (handles 145 to 164). Alone at the same commit: green (recheck run `20261016-215353-20140`). Load flake.

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

