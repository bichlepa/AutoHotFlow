# Phase 3 status (current state)

Kept by the orchestrator as described in `doc/ORCHESTRATOR.md`. This file shows the **current state only**: the steps, the open work items, running agents, pending integrations and the last verified states. History (one line per finished work item with commits and notes, session logs, run-ID lists of old states) is in the git history of this file; the last long version is commit `6bb1e933`. Decisions are in `doc/DECISIONS.md`, findings in `doc/OPEN-ITEMS.md` and `doc/CLOSED-ITEMS.md`, the plan in `work_items/phase3/README.md`, the result of each acceptance in `WI-0043-acceptance-s1.md`, `WI-0058-acceptance-s2.md`, `WI-0067-acceptance-s3.md` and `WI-0082-result-s4.md`.

## Steps

| Step | Work items | State |
|---|---|---|
| S0001 Expressions and variables | WI-0036 to WI-0043 | done (acceptance closed by the owner, E0050) |
| S0002 Element foundation and core set | WI-0044 to WI-0058 | done (acceptance WI-0058, 2026-10-16) |
| S0003 Trigger host and triggers | WI-0060 to WI-0068 | done (acceptance WI-0067, 2026-10-17) |
| S0004 UI foundation and manager | WI-0069 to WI-0082 | done (acceptance WI-0082 on 2026-10-19; the manual checks of the owner passed on 2026-10-19) |
| S0005 Editor I: display | WI-0083 to WI-0092 | done (acceptance WI-0092 on 2026-10-20; manual check 9 passed, look accepted, E0088; step 25 (4K) not run, REQ-PRF-060 partial, F-0156 postponed) |
| S0006 Editor II: editing | WI-0093 to WI-0104 | detailed on 2026-10-20 (E0091 to E0094), not started |
| S0007 Editor III: settings dialogs | WI-0105 to WI-0115 | detailed on 2026-10-20 together with S0006 (E0095 to E0100); refined by the retrospective of WI-0104 before its packages start |
| S0008 to S0010 | | rough, see the plan |

Step-independent: WI-0059 (test admission, load report, run history) is done.

## Work items of the next steps

S0006 and S0007 are detailed (plan: `work_items/phase3/README.md`). Order: WI-0093 first, with WI-0097 and WI-0103 beside it; then WI-0094, WI-0095 and WI-0096; then WI-0098 to WI-0102 one after the other; then WI-0104. S0007 packages without an S0006 dependency (WI-0105, WI-0112, WI-0113) may run beside S0006 when the files do not clash (E0095). The history of S0005 is in the git history of this file (commit `830ddffc`).

| WI | Title | State | Model | Commits | Date | Note |
|---|---|---|---|---|---|---|
| WI-0093 | Engine: patch operations, shared `FlowPatch`, revisions that share, the meta race | done | haiku | 5743c3d0..b5acb473 | 2026-10-21 | patch 4.5 to 29 ms (MS-0053/54); F-0163, F-0164 decision needed |
| WI-0094 | Engine: triggers of an edited flow | open | | | | E0092 |
| WI-0095 | Engine and storage: automatic saving and backups (E0065) | open | | | | |
| WI-0096 | Editor: draft, patch client, undo and redo, selection model, the view written | running (haiku) | | | | E0086 |
| WI-0097 | Scene and renderer for editing | done, screenshots await the owner | haiku | bb015aba..49f7edd4 | 2026-10-20 | F-0162 (30-element drag 25 ms) decision needed |
| WI-0098 | Editor: select and move, loop height | open | | | | E0094 |
| WI-0099 | Editor: add elements, class list | open | | | | |
| WI-0100 | Editor: connect | open | | | | |
| WI-0101 | Editor: delete, cut, copy, paste | open | | | | E0091 |
| WI-0102 | Editor: menu bar, context menus, trigger buttons | open | | | | |
| WI-0103 | Notice of a crashed editor | running (haiku) | | | | E0093 |
| WI-0104 | Acceptance S0006 | open | | | | manual check 10; refines S0007 |
| WI-0105 | Form model and the `form` API | open | | | | may run beside S0006 |
| WI-0106 | Element settings window | open | | | | |
| WI-0107 | Editor `ctx`, "Switch with the flow" | open | | | | |
| WI-0108 | Expressions checked while typing | open | | | | E0096 |
| WI-0109 | Flow settings dialog | open | | | | |
| WI-0110 | Assistants | open | | | | |
| WI-0111 | Help window: viewer interface, classic viewer, browser, setting | open | | | | E0099 |
| WI-0112 | Help content: Markdown, generator, core pages | open | | | | E0097, E0100; may run beside S0006 |
| WI-0113 | Window of an unhandled error | open | | | | may run beside S0006 (not with WI-0093/WI-0094: `Executor.ahk`) |
| WI-0115 | Help viewer with WebView2 | open | | | | spike first; if it fails, the classic viewer stays (E0099) |
| WI-0114 | Acceptance S0007 | open | | | | manual check 11 |

## Pending integrations

None.

## Running agents

WI-0096 (haiku, workspace wi-96), WI-0103 (haiku, workspace wi-103).

## Last verified state

Commit `b5acb473` (WI-0097 and WI-0093 integrated; selection of the groups engine, tools, transport): VERDICT green (partial run). WI-0097 alone was not verified separately.

Commit `60b41ad0` (gui test fixes, F-0158 and the requirements of S0005; the later commits change only documents): foundation 471 and slow 204 green, fast 1784 passed, 1 failed under load (`tests/e2e/test_editor_tray.py::test_a_state_that_cannot_be_read_asks_for_the_force_no_changes_nothing_yes_writes_it`, 99 % CPU, first failure in 7 runs, green alone in recheck 20261020-215042-recheck): a load flake (runs 20261020-213655-60b41ad0, -2, -3).

Commit `477e762a` (WI-0092 agent part integrated, all tiers): fast 1785 passed (1 skipped), foundation 471, slow 204, VERDICT green (runs 20261020-205058-477e762a, -2, -3). Stress: 33 passed (run 20261020-203757-cc86de86).

Commit `9b3267ca` (WI-0090, WI-0091 and the look corrections integrated, all tiers): foundation 471 and slow 204 green, fast 1782 passed, 3 failed under load (`test_worker_lifecycle` cold start, `test_settings` log thresholds, `test_worker` not busy after a cancel; all green alone in recheck 20261020-195141-recheck): load flakes; VERDICT red only by those (runs 20261020-193737-9b3267ca, -2, -3).

Commit `b8ffb990` (F-0155 fix, F-0156 heading; selection of the groups): slow 204 and foundation 471 green, fast 1761 passed, 1 failed under load (`tests/fault/test_tray_role.py::test_a_killed_tray_role_is_started_again_so_the_icon_comes_back`, green alone in recheck 20261020-193207-recheck; the fast run took 24 minutes on a loaded machine): a load flake (runs 20261020-190757-b8ffb990, -2, and 20261020-190801-b8ffb990). WI-0090 and the look corrections (tip 38c9b502) are not yet verified.

Commit `bfcdc7f9` (WI-0089 integrated): foundation 471, slow 204 green; fast 1760 passed, 1 failed (`tests/e2e/test_manager_editor.py::test_the_editor_of_a_flow_that_just_died_is_started_again_and_its_slot_is_free`, red in 4 of 4 full runs since WI-0089, green alone: recheck 20261020-185530-recheck); VERDICT red (runs 20261020-184414-bfcdc7f9, -2, -3).

Commit `33f4e961` (F-0154 fix integrated: `--auto` handles deleted files; all tiers): fast 1742 passed (11 skipped), foundation 471, slow 204, VERDICT green (runs 20261020-163838-33f4e961, -2, -3).

Commit `663c5adf` (WI-0088 integrated, all tiers; `--auto` failed on a deleted file, fix in review): fast 1739 passed (11 skipped), foundation 471, slow 204, VERDICT green (runs 20261020-162905-663c5adf, -2, -3).

Commit `f1d55c17` (WI-0085 integrated; WI-0087 included, selection of 13 groups): 1216 passed (1 skipped), VERDICT green (run 20261019-230236-f1d55c17).

Commit `c20b0d79` (WI-0087 integrated, selection of the manager and supervisor groups): 918 passed, 1 failed under load (`tests/e2e/test_manager_flows.py::test_new_category_rename_and_the_delete_answered_no`, CPU 96 %; green alone in recheck 20261019-224555-recheck, green in 5 earlier runs): a load flake, WI-0087 not affected; run 20261019-224100-c20b0d79.

Commit `79f284cf` (WI-0086 integrated, all tiers): fast 1660 passed (11 skipped), foundation 471, slow 204, VERDICT green (runs 20261019-221605-79f284cf, -2, -3).

Commit `db97aa32` (strict test selection integrated; unknown paths are an error): the tree equals the tree that was verified on the branch: fast 1653 passed (11 skipped), foundation 471, slow 204, VERDICT green (runs 20261019-215643-805c609f, -2, -3).

Commit `28558ead` (WI-0084 integrated, selection of the group editor-geometry): 131 passed (1 skipped), VERDICT green (run 20261019-214248-28558ead).

Commit `3b89cad0` (WI-0083 integrated, all three tiers because the selection said everything): fast 1614 passed (11 skipped), foundation 471, slow 204, VERDICT green (runs 20261019-212108-3b89cad0, -2, -3).

Latest three verdicts (the older ones are in the git history of this file).

Commit `a94365a0` (WI-0082 acceptance state, 2026-10-19): fast 1605 passed (1 skipped), foundation 471 passed, slow 204 passed; read from the run history (`python tools/test_history.py --last`), no failure recorded.

Commit `832078da` (WI-0078 settings dialog and the checkboxes of WI-0079): fast 1605, foundation 471, slow 204, VERDICT green.

Commit `da0d9fae` (burst log test compares the burst file; WI-0077 included): fast 1560, foundation 471, slow 204, VERDICT green.

Load flakes that are known and green alone (`python tools/test_history.py --flaky` has the current list): the engine restart and re-arm test in `tests/integration/test_trigger_arming.py`, the manager e2e tests and the burst log test under load.

Later commits changed only documents (the documentation review of 2026-10-19 also changed `tests/conftest.py`: a stress, soak or idle run leaves gui tests out, F-0143; `tests/test_tier_selection.py`).
