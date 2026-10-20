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
| S0006 to S0010 | | rough, see the plan |

Step-independent: WI-0059 (test admission, load report, run history) is done. Step S0008 (remaining elements) is planned, not started.

## Work items of the next step

S0005 is done; next is S0006, to be detailed with the owner (WI-0085 to WI-0090 and the look corrections are integrated). WI-0092 (acceptance) must list the `gui` test for real mouse input (task 7 of WI-0090: wheel and drag with SendInput, VS Code task) and the check of the status bar layout.

| WI | Title | State | Model | Commits | Date | Note |
|---|---|---|---|---|---|---|
| WI-0083 | GDI+ wrapper and the R0002 measurement | done | haiku | e0febbf1..92b9cac5 | 2026-10-19 | R0002 failed: 300 ms vs 16 ms (MS-0044); owner decided E0090 (caches), added to WI-0085 |
| WI-0084 | Geometry and scene (headless) | done | haiku | 98f467b0..e065b5d1 | 2026-10-19 | review approved; verified green |
| WI-0085 | Renderer: draw the scene, style, icons | done, look not yet accepted | haiku | see git log (WI-0085) | 2026-10-19 | review approved with one fix; frame 6.3 ms, rebuild 106 ms (152 ms at 4K, F-0151); owner accepts the look (E0088); verified green |
| WI-0086 | Engine: run states, connection taken, warnings per element | done | haiku | f2846ee2..19c91fdf | 2026-10-19 | review approved with one fix; verified green; F-0148 |
| WI-0087 | Open and close an editor: supervisor and manager | done | haiku | 1646a787..e147d1f4 (see git log) | 2026-10-19 | review approved with one text fix; verified (one load flake); F-0149 carried to WI-0088 |
| WI-0088 | Editor role: model, resync, window, headless driver | done | haiku | see git log (WI-0088), tip 663c5adf | 2026-10-20 | review approved; verified green; gui window test left to the owner; F-0149 closed |
| WI-0089 | Live states, marks and the event load | done | haiku | see git log (WI-0089), tip bfcdc7f9 | 2026-10-20 | review approved with fixes; batch per flow decided by the owner (evt.element.states); slow 204 and foundation 471 green; the restart test of the editor was a wrong test assumption (F-0155, fixed); F-0150 closed, F-0156 open; window latency measurement is for the owner |
| WI-0090 | View: zoom, move, tooltip, status bar, DPI | done | haiku | see git log (WI-0090), tip 26de7a68 | 2026-10-20 | review approved with one fix (drag ends without a button); gui test of real mouse input and the status bar layout on screen are left to WI-0092; F-0157 |
| WI-0091 | Tray icon and tray menu of the editor | done | haiku | see git log (WI-0091), tip 9b3267ca | 2026-10-20 | review approved with one fix (F-0158 recorded); gui test written, not run |
| WI-0092 | Acceptance S0005 | done | haiku | see git log (WI-0092), tip 477e762a | 2026-10-20 | review approved with fixes; REQ-PRF-060 unmet for 300 changing elements (F-0156); manual check 9 and the decisions in NEEDS-ATTENTION wait for the owner; result in WI-0092-result-s5.md |

## Pending integrations

None.

## Running agents

WI-0089 implementer (haiku), workspace wi-89.

## Last verified state

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
