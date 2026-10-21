# WI-0104 Result: acceptance of S0006 (agent part, 2026-10-21)

Code state of the runs: commit `682873bf`. The code is that of `0e7a7c3f`; the later commits change documents only, and `682873bf` fixes one doc test. Commits of this item (workspace `wip/wi-104`, not merged): `63ab5ba2`, `e42ad0ea`, `5c6d8a2e`, `1bf8dc63`, `ea85d0dd`, `0e7a7c3f`, `6b1fd465`, `0fa79fdf`, `a678f74f`, `50ccd737`, `268426bb`, `1c680527`, `d3e830a3`, `682873bf`, `0b80b634`. Status words: verified (read or run, number in the source), assumed, not checked.

**Verdict.** S0006 is **not accepted as a whole**. The agent part is done: every editing action has headless e2e tests, the crash and nothing-lost cases are tested, and the measurements are recorded. Three points stay open: the owner's manual check 10 (the look and feel, the real mouse, 225 %), the frame of a drag of 30 elements (26.9 ms against a budget of 16 ms: F-0162, the owner decides), and the S0007 refinement, which is a proposal.

## 1. The acceptance of S0006, point by point

| # | Criterion (README "Acceptance S0006") | Evidence | Status |
|---|---|---|---|
| 1 | Editing during execution (E0001, ARCHITECTURE 4.2): a running instance follows a connection added during the run; a removed next element ends its thread (M-0017); a changed trigger of an enabled flow fires with its new parameters | `tests/integration/test_flow_patch.py::test_a_running_instance_follows_a_connection_added_during_its_run`, `::test_a_removed_next_element_is_not_run_and_the_running_element_ends_normally`, `tests/integration/test_flow_patch_triggers.py::test_a_changed_interval_of_an_enabled_trigger_fires_at_the_new_interval`. Added here for the table of ARCHITECTURE 4.2: `::test_a_running_element_keeps_the_parameters_it_started_with`, `::test_a_running_element_that_is_removed_runs_to_its_end_and_the_instance_finishes`. These are engine-process tests with a storage stand-in, not tests through the editor | **met**, one case open (a waiting thread whose element changes: not tested) |
| 2 | Every editing action has headless e2e tests through the driver; the windows are checked by gui tests of the owner and by the manual check | `tests/e2e/test_editor_select.py`, `test_editor_add.py`, `test_editor_connect.py`, `test_editor_clipboard.py`, `test_editor_menus.py`, `test_editor_draft.py`, `test_editor_tray.py`; gui: `tests/fault/test_editor_menus_gui.py`, `test_editor_mouse_gui.py` (wheel and view only). The real mouse for select, move, connect and add has no gui test (F-9001*) | **met** for the headless part; the gui part is open (F-9001*, manual check 10, steps 1 to 16) |
| 3a | A killed editor loses no completed edit: the file has it within 10 s, the reopened editor shows it, and the user got the notice (REQ-ROB-120, E0093) | `tests/e2e/test_editor_nothing_lost.py::test_an_edit_is_on_disk_a_few_seconds_later_and_the_first_write_of_the_session_has_a_backup`, `::test_a_killed_editor_loses_no_completed_edit_and_the_reopened_editor_shows_it` (new); the notice: `tests/e2e/test_editor_crash_notice.py` (existing) | **met (headless)**; the real kill and the balloon click: owner (manual check 10, steps 26 and 27) |
| 3b | A killed engine loses at most the edits of the last 10 s; nothing asks at close or exit (REQ-EDT-100); the backups follow E0065 | `tests/e2e/test_editor_nothing_lost.py::test_a_killed_engine_keeps_the_edit_that_was_written_and_the_editor_shows_it`, `::test_an_editor_closed_with_an_edit_not_yet_written_asks_nothing_and_the_engine_writes_it` (new); the 10 s rule and the sessions: `tests/integration/test_flow_autosave.py` (existing: `test_a_killed_engine_keeps_the_commits_that_were_written`, `test_a_session_gets_one_backup_at_its_first_write_and_a_new_session_another`, `test_a_shutdown_writes_the_pending_commit_before_it_says_bye`) | **met (headless)** |
| 4 | Copy in one editor and paste in another works (E0091) | `tests/e2e/test_editor_clipboard.py::test_a_copy_in_one_editor_is_pasted_in_the_editor_of_another_flow`, `::test_a_copy_survives_the_editor_that_made_it` | **met (headless)** |
| 5 | Measured: the answer of a patch on a flow of 300 elements; the frame during a drag of 30 elements (below 16 ms, headless); the rebuild after the drop | MS-0057: engine time of a patch on 300 elements, mean 2.7 ms (one element), 3.1 ms (30 moves), 12.5 ms (30 additions). MS-0058: round trip of a patch during a run, median 16.9 ms, p95 66.7 ms (stress run `20261021-185339-682873bf`). MS-0056: drag frame 12.6 ms for one element, **26.9 ms for 30 elements (not met)**; rebuild after the drop 98 to 104 ms | **partly met**: the drag of 30 is above the budget (F-0162, owner decision). The p95 of the round trip is above 50 ms (recorded, not a criterion) |
| 6 | The owner edits the imported v1 flows at 100 % and 225 % (manual check 10) | `doc/MANUAL-CHECKS.md` section 10 (32 steps, three gui tests, VS Code tasks "Start: manual check 10 ..." and "Test: editor crash notice, balloon click (gui ...)") | **open: the owner's check**; nothing is claimed closed |
| 7 | Serial, parallel, `-m stress`, foundation and slow runs are green | section 3 | **met with the known load flakes** (section 3); the one red test of the parallel run that is not a load flake was a doc test, fixed by `682873bf` |

**Requirements of S0006 (AGENTS rule 12).** `v2`, `Plan` and `Evidence` updated for REQ-EDT-050, 060, 070, 080, 090, 100, 110, REQ-ROB-120, REQ-TRG-030 and REQ-USE-010. REQ-USE-010 stays `done`. The others stay `partial` until the owner closes manual check 10; REQ-EDT-050 to 080 also need the gui gestures written or checked by hand (F-9001*). REQ-TRG-030 is `partial` for the force question (F-9000*).

## 2. The tasks of WI-0104

1. **Criteria:** section 1.
2. **Editing during execution:** two cases added (`tests/integration/test_flow_patch.py`, commit `0e7a7c3f`); the others existed. Not added: the waiting thread whose element changes (open).
3. **Nothing lost:** new file `tests/e2e/test_editor_nothing_lost.py` (4 tests, commit `ea85d0dd`, groups `editor`, `tray`). All four passed serially on the first run. The 10 s rule for an engine killed before its write stays in the integration tests, whose timers are controlled.
4. **Measurements:** MS-0056 (drag and rebuilds, renderer bench), MS-0057 (engine time of a patch, bench), MS-0058 (round trip during a run, stress). Commits `50ccd737`, `0b80b634`.
5. **Manual check 10:** section 10 of `doc/MANUAL-CHECKS.md` and two VS Code tasks (the start, and the crash notice gui test, which had none). Commit `6b1fd465`. Open for the owner.
6. **Documents:** REQUIREMENTS (`0fa79fdf`), MIGRATION M-0095 and OPEN-ITEMS F-9000* to F-9003* (`a678f74f`), ARCHITECTURE 4.2 and two HOW-TO entries (`268426bb`), STATUS and README (`0b80b634`, `1c680527`). PROTOCOL: no interface changed in this item (no message type, no field), so it was not touched. ARCHITECTURE 2.1, 8 and 10: no change needed by this item. `python tools/doc_index.py --check` passes.
7. **Retrospective and S0007 refinement:** section 7. The proposal is in the files `WI-0105` to `WI-0113` and `WI-0115` (section "Refinement from WI-0104", commits `1c680527`, `d3e830a3`) and in the plan (`### Refinement of S0007` in `README.md`), marked as a proposal for the owner.
8. **Runs:** section 3.

**Code changes of this item (one change per commit):**

- `63ab5ba2`: a paste is refused above 2 MB (was 16 MB). Test `test_a_clipboard_of_our_format_above_2_mb_is_refused_and_nothing_is_pasted` (headless, passed).
- `e42ad0ea`: an action of the menus or the keys runs under try/catch in `EditorMenus.Run`. The cause is logged and the status bar says `Menu_action_failed` (en and de). Not covered by a test: a failing action cannot be produced without a test seam.
- `5c6d8a2e`: the menu bar is refreshed on window activation (WM_ACTIVATE), so the paste entry follows the clipboard of another program. Not run in a window (gui check, owner).
- `1bf8dc63`: test that the Advanced level shows the Beginner classes and not the Programmer ones (passed). The Advanced class itself is covered by the ahk unit test, because the Default package has none.

## 3. Runs

One machine. Runs with the marker `stress` were exclusive: the admission started them on an idle machine. Another agent (WI-0106) ran tests on the same machine during parts of the work.

| Run | Commit | Result |
|---|---|---|
| fast, parallel (`verify.py --ref d3e830a3`, tier fast) | `d3e830a3`, run `20261021-182554-d3e830a3` | 2083 passed, 1 skipped, 2 failed. `tests/test_open_items_ids.py` (the unstarred F-9000 to F-9003 of that commit; fixed by `682873bf`, the star rule of ORCHESTRATOR section 2). `tests/fault/test_worker_lifecycle.py::test_time_to_the_first_job_when_the_worker_has_to_be_started_cold`: load flake, recheck `20261021-184100-...-recheck` green again |
| foundation (`verify.py`) | `d3e830a3`, run `20261021-182554-d3e830a3-3` | 471 passed, 1 skipped (green) |
| slow (`verify.py`) | `d3e830a3`, run `20261021-182554-d3e830a3-2` | 205 passed, 1 failed: `tests/integration/test_flow_autosave.py::test_patches_every_second_give_a_write_at_least_every_10_s`, a known load flake (its fourth; recheck `20261021-184115-recheck` green alone) |
| stress, `-m stress` (`run_suite`) | `682873bf`, run `20261021-184149-682873bf` | 34 passed, 2747 deselected (11:22) |
| stress, round trip with the measurement line (MS-0058) | `682873bf`, run `20261021-185339-682873bf` | 1 passed (24 s) |
| SERIAL_RUN | | |
| GUI_RUN | | |

The `verify.py` VERDICT of `d3e830a3` was red: fast (the doc test and the cold worker start) and slow (the autosave flake). The doc test is green at `682873bf`; the two load flakes are green when they are rerun alone (recheck).

## 4. Decisions taken by the implementer

- **The dialog title "Create new <kind>" needs no new keys.** `EditorWindow.Choose` passes `"Create new " kind` as the title key; `UiDialogs` resolves it through `Lang`. The keys `Create new action`, `... condition`, `... loop` and `... trigger` already exist in `assets/language/basic/en.ini` (lines 66 to 69) and `de.ini` (lines 256 to 259), and partly in `ko.ini` and `ru.ini`. The task asked for four keys en and de; they were not added because they exist. Verified by reading `LangTable` and `UiTexts`; not seen in a window.
- **ko and ru editor texts:** not translated. The language table falls back to English (`LangTable.Fallback`). Open: F-9002*.
- **Trigger switch, force question:** not added. Documented as an open decision, F-9000*: the owner chooses between the question and the documented status text.
- **Paste limit 2 MB:** done (`63ab5ba2`), recorded as M-0095.
- **Real-mouse gui tests for the editing gestures:** not written in this item (time; the owner's manual check 10 covers them). Open: F-9001*.
- **The patch numbers** come from the existing benches (MS-0057) and from a stress test (MS-0058); no new measurement test was added.
- **`AHF_MEASURE_OUT`** was set for one stress run to keep the round-trip line (MS-0058); it is not a permanent part of the test.
- **Provisional finding IDs** are written with the star (F-9000* and so on). The star fix is a separate commit (`682873bf`); the integrator renumbers them.

## 5. Owner questions (decision needed; also for NEEDS-ATTENTION)

1. **Frame of a drag of 30 elements (F-0162):** 26.9 ms mean at 1920 × 1080 in MS-0056, budget 16 ms. The options are in OPEN-ITEMS F-0162 (a group layer for the dragged elements, accept, or reduce `Scene.WithDrag`).
2. **Force question of the trigger switch (F-9000*):** add the question, or keep the status text and write it into REQ-TRG-030.
3. **Manual check 10:** the owner runs sections 10 A to C at 100 % and 225 % and writes the result. The editing requirements stay `partial` until then.
4. **The S0007 refinement (E0095):** the proposal in `work_items/phase3/README.md` ("Refinement of S0007") and in each `WI-010x` file. In particular, the form between the class choice and the add changes the answer of WI-0099 (M-0091).
5. **ko and ru texts (F-9002*)** and **F-9003*** (F-0158 is not reproduced in the files of this branch): close or keep.

## 6. Findings

- **F-0162** (decision needed): the drag of 30 elements. MS-0056 updates the number.
- **F-9000*** to **F-9003*** (open, see section 5 and OPEN-ITEMS).
- Own mistakes, fixed in this item: (a) the new open items had no star (fixed by `682873bf`; the ID test caught it); (b) two pytest runs of mine wrote to the same output file (a bash subshell with `&` and a background run), one of them stuck and was stopped; its output is not a result (HOW-TO tests-and-tools).

## 7. Retrospective (task 7)

- **Hard:** the editing needs one implementation of the operations for the engine and the editor (`FlowPatch`), and the tests of a running instance need the engine process, not the editor. The menus have two sources of state (the model and the clipboard of another program); HOW-TO gui-and-hotkeys has the entry.
- **For S0007 (the patch client):** a form writes with `EditorDraft.Commit(ops, true)`, as the trigger star does. The form goes between the class choice and the add (the answer of WI-0099 changes). The entries `edit` and `settings` are disabled in `EditorMenus` until WI-0106 and WI-0109. The trigger force question (F-9000*) must be decided before WI-0106 and WI-0107. The request pattern for other flows is `EditorTriggers.Switch`. Keys typed in a dialog field must not reach the editor (WI-0108).
- **For the owner:** the batch of element states (F-0156) and the drag cost (F-0162) stay the two open performance points of the editor.

## 8. Not checked

- The real mouse, the real keys and the windows of the editing actions (manual check 10 and the gui tests, section 3).
- The look at 225 % and on a second screen (manual check 10, section 9 part C).
- The ko and ru texts and the look of the English fallback.
- Whether the WM_ACTIVATE refresh of the paste entry works in a window (not run).
- The try/catch of the menu actions by a failing action (no test seam; read only).
- The load of the machine during MS-0056 and MS-0057 (not recorded; another agent's runs were on the machine).
