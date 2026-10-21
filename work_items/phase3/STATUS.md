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
| S0006 Editor II: editing | WI-0093 to WI-0104 | accepted by WI-0104 (agent part, 2026-10-21, E0091 to E0094); manual check 10 open for the owner |
| S0007 Editor III: settings dialogs | WI-0105 to WI-0115 | detailed on 2026-10-20 together with S0006 (E0095 to E0100); refined by the retrospective of WI-0104 before its packages start |
| S0008 to S0010 | | rough, see the plan |

Step-independent: WI-0059 (test admission, load report, run history) is done.

## Work items of the next steps

S0006 and S0007 are detailed (plan: `work_items/phase3/README.md`). Order: WI-0093 first, with WI-0097 and WI-0103 beside it; then WI-0094, WI-0095 and WI-0096; then WI-0098 to WI-0102 one after the other; then WI-0104. S0007 packages without an S0006 dependency (WI-0105, WI-0112, WI-0113) may run beside S0006 when the files do not clash (E0095). The history of S0005 is in the git history of this file (commit `830ddffc`).

| WI | Title | State | Model | Commits | Date | Note |
|---|---|---|---|---|---|---|
| WI-0093 | Engine: patch operations, shared `FlowPatch`, revisions that share, the meta race | done | haiku | 5743c3d0..b5acb473 | 2026-10-21 | patch 4.5 to 29 ms (MS-0053/54); F-0163, F-0164 decision needed |
| WI-0094 | Engine: triggers of an edited flow | done | haiku | e813da0d..15600ccd | 2026-10-21 | E0092; owner to confirm: activity of a flow after removals in a patch (undo of a sole trigger returns it disabled) |
| WI-0095 | Engine and storage: automatic saving and backups (E0065) | done | haiku | 9164afdc..59ba17bf | 2026-10-21 | F-0163 closed; editor sends no session until WI-0096 wiring; tests weaker than spec (no killed-editor test) |
| WI-0096 | Editor: draft, patch client, undo and redo, selection model, the view written | done | haiku | 1fc90266..c0f3f0ff | 2026-10-21 | F-0165, F-0166 |
| WI-0097 | Scene and renderer for editing | done, screenshots await the owner | haiku | bb015aba..49f7edd4 | 2026-10-20 | F-0162 (30-element drag 25 ms) decision needed |
| WI-0098 | Editor: select and move, loop height | done | haiku | see git log | 2026-10-21 | E0094; REQ-EDT-060 partial (real-mouse gui test unwritten); F-0166 part 1 tested; de/ko/ru texts of the status bar missing |
| WI-0099 | Editor: add elements, class list | done | haiku | see git log | 2026-10-21 | M-0091; open: dialog title "Create new <kind>" not a language key; Advanced level no e2e; tree dialog and real mouse are gui-only |
| WI-0100 | Editor: connect | done | haiku | see git log | 2026-10-21 | M-0092; REQ-EDT-070 partial (gui unwritten); author used --no-verify once (CRLF index sizes, see report); FlowPatch.Diff fix; moved connection not previewed |
| WI-0101 | Editor: delete, cut, copy, paste | done | haiku | see git log | 2026-10-21 | E0091; M-0093; REQ-EDT-080 partial; F-0168 (cold-start flake); clipboard limit 16 MB parsed on message path (consider 1-2 MB); ko/ru keys missing |
| WI-0102 | Editor: menu bar, context menus, trigger buttons | done | haiku | see git log | 2026-10-21 | M-0094; gui test written, owner runs it; menu callbacks without own try/catch (cheap in WI-0104); trigger switch without the force question; ko/ru keys missing |
| WI-0103 | Notice of a crashed editor | done | haiku | 5fe3f431..f7a7dad1 | 2026-10-21 | balloon shows the flow ID; real click not checked |
| WI-0104 | Acceptance S0006 | done (agent part); manual check 10 open for the owner | haiku | 63ab5ba2..682873bf | 2026-10-21 | result `WI-0104-result-s6.md`; code fixes (2 MB paste limit, menu failure, activation refresh, tests of nothing lost and of running edits); MS-0056, MS-0057; F-0170 to F-0173 open; S0007 refinement proposed (E0095), owner decides |
| WI-0105 | Form model and the `form` API | done | haiku | a7e46ddd..6e5558d2 (rebased) | 2026-10-21 | WI-0106 must re-render after SetChoices/SetLabel and include ElementForm in the editor entry; v1 percent-sign note for WI-0108 |
| WI-0106 | Element settings window | done | haiku | see git log | 2026-10-21 | M-0095 (renumber WI-0104's if clashing); F-0169 fixed; window never shown, gui test written for owner; slider fixed to 0-100 (v1 passes options); help and assistant buttons disabled |
| WI-0107 | Editor `ctx`, "Switch with the flow" | open | | | | |
| WI-0108 | Expressions checked while typing | done | haiku | see git log | 2026-10-21 | REQ-EDT-200 done; manual check 11 open (owner); String texts not checked (docs: no %var% in strings; owner to confirm); parser messages English |
| WI-0109 | Flow settings dialog | done | haiku | see git log | 2026-10-21 | REQ-EDT-140 partial; gui test written for owner; F-0175 (wrong REQ reference), F-0176 (Show log starts manager without filter); `ExecutionPolicy.Decide` throws on an invalid hand-written value (start error only) |
| WI-0110 | Assistants | done | haiku | see git log | 2026-10-21 | M-0098; REQ-EDT-130 partial; gui test for owner; modal ChooseColorW not measured (suggest extending E0076); tracker window mode relative to the tracker itself |
| WI-0111 | Help window: viewer interface, classic viewer, browser, setting | open | | | | E0099 |
| WI-0112 | Help content: Markdown, generator, core pages | done | haiku | see git log | 2026-10-21 | F-0167 owner decision; 17 pages with v1 markers for S0008; markdown pinned (generated HTML compared byte for byte); `Variables.md` still says threads |
| WI-0113 | Window of an unhandled error | done | haiku | see git log | 2026-10-21 | PROTOCOL 4.7a; owner: variable values (also passwords) kept in engine memory and shown in clear text; cyclic object cannot be stringified (not reachable via normal assignment); tray click does not open it; slow/foundation tiers via verify | | | | may run beside S0006 (not with WI-0093/WI-0094: `Executor.ahk`) |
| WI-0115 | Help viewer with WebView2 | open | | | | spike first; if it fails, the classic viewer stays (E0099) |
| WI-0114 | Acceptance S0007 | open | | | | manual check 11 |

## Pending integrations

None.

## Running agents

WI-0111 (haiku, wi-111).

## Last verified state

Commit `e597935a` (WI-0104, WI-0106 and the S0006 acceptance integrated; all tiers): fast 2109 passed, foundation 471 passed, slow 205 passed, 1 failed (`test_flow_autosave` every-10-s: `no peer engine` after about 60 patches under load, F-0174, a hunter entry; green alone) (runs 20261021-193520-e597935a, -2, -3). VERDICT red only by that.

Commit `cf085e1f` (WI-0101 and WI-0113 integrated, all tiers): fast 2066 passed, foundation 471 passed, slow 204 passed, 2 failed under load, both green alone (recheck): `test_log_burst` stand-still, and `test_flow_autosave` every-10-s (fourth load failure; the WI-0095 author investigates the cause: ok:false of a patch) (runs 20261021-091309-cf085e1f, -2, -3).

Commit `f58bb0b2` (WI-0105, WI-0112, WI-0100 integrated; fast, foundation, slow): fast 2023 passed, 1 failed (`test_worker_reports_not_busy_after_a_cancel_too`, load flake), foundation 471, slow 205 passed, 1 failed (`test_flow_autosave::test_patches_every_second_give_a_write_at_least_every_10_s`: a patch answered `ok: false` at test line 174 under load; green alone in recheck 20261021-084542-recheck; third load failure of this test, to harden: it should tolerate or retry a refused patch) (runs 20261021-083332-f58bb0b2, -2, -3). VERDICT red only by these.

Commit `be95b747` (WI-0098 and WI-0099 integrated; selection of 19 groups): 2179 passed, 2 failed under load, both green alone (`test_worker_lifecycle` cold start: recheck 20261021-075807-recheck; `test_flow_autosave` every-10-s timing: serial green; another autosave test failed alone once by a torn read of the flow file, fixed in the test helper); VERDICT red only by those (run 20261021-074758-be95b747). Earlier, `740897e1` (WI-0095): 13 red in the select run, all load or input tests (`test_hotkey_input` @input ids cannot be rechecked by `recheck.py`, skipped alone); not classified further.

Commit `c0f3f0ff` (WI-0103, WI-0094, WI-0096 integrated; selection of 10 groups): 1170 passed, 11 skipped, VERDICT green (partial run; runs 20261020-235009-f7a7dad1 and 20261021-001254-c0f3f0ff). A full tier run is still due.

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
