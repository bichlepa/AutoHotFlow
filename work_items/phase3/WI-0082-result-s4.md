# WI-0082 Result: acceptance of S0004 (agent part, 2026-10-19)

Code state of the stress run and the memory measurements: commit `87921e6c` (the new test `tests/stress/test_background_memory.py`); afterwards only documents, the requirement fields and the VS Code task changed. Code state of the acceptance runs in section 7: the commit named there (documents only differ from `87921e6c`). Status words: verified (read or run, number in the source), assumed, not checked.

Commits on `wip/wi-82`: `87921e6c` (memory test), `405e5dd1` (requirement fields, ARCHITECTURE 8, MIGRATION, task), `a94365a0` (MS-0042, MS-0043, REQ-PRF-030, ARCHITECTURE 9), and the last commit with this document and the HOW-TO entry.

## 1. The acceptance of S0004, point by point

| # | Criterion (README "Acceptance S0004") | Evidence | Status |
|---|---|---|---|
| 1 | Every engine and storage command of S0004 has e2e tests; the manager operations are tested headless through the model; the windows by `gui` tests of the owner and the manual checks | Engine and storage: `tests/integration/test_flow_lifecycle_engine.py` (23 tests), `test_flow_lifecycle.py` (5), `test_categories.py` (18), `test_settings.py` (21), `test_notices.py` (6), `test_startup_elevation.py` (13), `test_storage.py` (log tail). Manager headless: `tests/e2e/test_manager.py` (5), `test_manager_flows.py` (24), `test_manager_import.py` (16), `test_manager_import_settings.py` (4), `test_manager_archive.py` (17), `test_manager_log.py` (3), `test_manager_settings.py` (5), AHK unit tests `tests/ahk/manager_*.test.ahk`, `ui_common_*.test.ahk`. Mechanical check of PROTOCOL against the tests (type strings of all documented `cmd.*`/`evt.*`): the raw commands `cmd.storage.ahf.pack`, `cmd.storage.ahf.unpack`, `cmd.storage.startup.sync`, `cmd.storage.v1.list`, `cmd.storage.v1.read`, `cmd.import.scan` and `cmd.import.v1.vars` appear in no test text; they are exercised through the manager chain (import, export, shortcut) but not directly (finding F-0141*) | met for the flows; verified by reading the test files and by the green runs of section 7; the seven commands above only indirectly. The windows are gui tests and manual checks, owner: section 4 |
| 2 | The owner's v1 flows and variables (a copy of the v1 data folder) are imported; the report lists the MIGRATION places; the flows are disabled; the v1 folder is unchanged | `test_manager_import.py::test_every_flow_of_the_folder_is_imported_with_its_id_and_disabled`, `::test_the_report_has_the_places_the_engine_marked`, `::test_the_report_names_the_migration_places_of_an_imported_flow`, `::test_a_global_variable_that_v2_has_keeps_its_value_and_statics_come_with_their_flow`; the unchanged source is part of the tests (the folder is only read; REQ-MIG-060 evidence). A real v1 `.ahf` is read in `test_manager_archive.py` | met for the test data; **the import of the owner's own data copy is open (manual check 1, part B, steps 14 to 22)** |
| 3 | Closing the manager window keeps AutoHotFlow running; the tray icon stays after a crash of the manager and brings it back; "Exit" in the menu and in the manager ends the application cleanly (REQ-MGR-080, REQ-MGR-090, REQ-MGR-140, REQ-ROB-120 for the manager) | Headless: `tests/fault/test_tray_role.py::test_the_exit_entry_ends_the_supervisor_with_exit_0_and_leaves_no_process`, `::test_a_killed_tray_role_is_started_again_so_the_icon_comes_back`, `::test_a_crashed_manager_is_opened_again_by_the_show_manager_entry`, `::test_the_show_manager_entry_starts_a_manager_that_is_not_running`, `tests/stress/test_manager_big_flows.py` (kill, show: new manager after 0.19 s, MS-0043). Real window (gui tier, owner): `tests/fault/test_manager_window.py::test_closing_the_window_only_hides_it_and_the_application_runs_on`, `::test_the_exit_button_ends_the_application_cleanly`, `::test_a_crash_of_the_manager_leaves_the_rest_running_and_it_is_not_restarted`. The gui tests were reported green by the WI-0073 work (STATUS.md); not repeated by agents | headless part verified; the window part is the owner's run (section 4). REQ-MGR-080 and REQ-MGR-140 stay `done`, REQ-MGR-090 and REQ-ROB-120 `partial` |
| 4 | The settings take effect without a restart where the requirement says so (language including the tray menu, log thresholds, policy, working directory, number of workers, limits) | `test_settings.py`: `test_the_language_changes_the_texts_of_two_roles_at_once`, `test_the_log_thresholds_change_in_every_role_at_once`, `test_the_global_execution_policy_decides_for_flows_set_to_default`, `test_the_global_working_directory_is_a_working_directory_of_flows_at_once`, `test_the_number_of_workers_grows_and_shrinks_at_once`, `test_the_global_runaway_limit_stops_a_flow_without_its_own_limit`, `test_the_global_limit_of_running_instances_refuses_a_start`; tray menu: `tests/e2e/test_manager_settings.py::test_the_language_changes_the_tray_menu_and_the_manager_without_a_restart` | met (verified, headless); the look of the dialog and of the German windows is manual check 8 (owner) |
| 5 | Start with Windows and run as administrator pass their manual checks | Automated part: `test_startup_elevation.py` (shortcut created, removed, repaired; a start with Windows starts no manager; restart elevated with the fake hook; declined elevation) | **open: manual check 7 (real log on, real UAC) is the owner's**; the REQ-SET-030/040 stay `partial` |
| 6 | The memory of the background processes is measured again, with the manager open and with the manager not running (REQ-PRF-030, E0040) | MS-0042 (new): headless manager 62.5 MB (1 worker) and 76.9 MB (3 workers); no manager (`--windows-startup`) 53.2 and 67.0 MB; MS-0043: the manager with its window 11.0 MB against 9.5 to 10.9 MB headless | met for the budget (below 100 MB in all four variants); **the real window was not a session of the memory test** (see section 2) |
| 7 | `tests/stress/test_big_flows.py` with the manager connected stays within the budget | MS-0043: 200 flows, ready after 53.9 s, snapshot during the load at most 689 ms (budget 3 s, E0042), 0 timeouts; run 20261019-193837-87921e6c | met (verified, one run) |
| 8 | Serial, parallel, `-m stress`, foundation and slow runs are green | section 7 | see section 7 |

## 2. Memory (task 2)

Test: `tests/stress/test_background_memory.py` (new, stress tier, VS Code task "Test: memory of the background processes ..."). Corpus: that of `test_trigger_host_memory.py` (MS-0039). Variants: manager role headless plus tray role headless; start with Windows (`--windows-startup`: no manager); each with 1 and 3 workers (`--workers=N --warm-workers=N`; the test asserts the worker count); 3 sessions each; 20 s of armed triggers. Results in `doc/MEASUREMENTS.md` MS-0042:

| Variant | Sum of private bytes (median, min to max of 3) |
|---|---|
| manager, 1 worker | 62.5 MB (62.5 to 62.8) |
| manager, 3 workers | 76.9 MB (76.3 to 77.6) |
| no manager, 1 worker | 53.2 MB (52.7 to 53.4) |
| no manager, 3 workers | 67.0 MB (66.9 to 67.4) |

All below the 100 MB budget of E0040. Per role: supervisor about 18, engine 12.6, manager 9, storage 5.6, trigger host 5.5, tray 5.2, a worker 6.7 MB. Compared with MS-0039 (46 MB, no tray, manager stub): the tray role (5.2 MB) and the real manager (9 MB) are new.

**What was not measured, honestly.** A real manager window cannot be opened without a gui test, and agents do not run those. The memory test therefore uses the headless manager (the model and the connection, no window object). The "window hidden" variant is the same process as "window open" (closing only hides it, E0014), so it is not a separate case. The window's own cost comes from MS-0043: 11.0 MB private with the window and 200 flows against 9.5 to 10.9 MB headless, so about 1 to 2 MB; the sum with the real window is estimated at about 64 MB (assumed). **Incident:** I started the stress tier with `-m stress`, which replaces the default `not gui` filter; that run opened one real manager window for about 50 s (`test_the_window_fills_its_tree_with_200_big_flows`, marked `stress` and `gui`). It did no harm (it passed), but it was a gui test run by an agent, against the instruction. The same will happen to every `-m stress` run of the tiers: the file needs `not gui` in the stress selection, or the owner has to accept it (proposal for the owner, see section 6).

## 3. Load path with the manager (task 3)

`tests/stress/test_big_flows.py` (chain storage, engine, headless manager, trigger host; 200 flows, 12.07 MB, timers enabled) and `tests/stress/test_manager_big_flows.py`, run 20261019-193837-87921e6c (MS-0043):

| Value | Now | Budget | Earlier |
|---|---|---|---|
| Start to `evt.engine.ready` | 53.9 s | none (loading, F-0073) | 52.0 to 55.4 s (MS-0030) |
| All 200 timers armed | 55.4 s | 30 s after ready | - |
| Snapshot during the load, max / p95 / median | 689 / 613 / 158 ms (n = 202) | 3 s (E0042) | max 588 to 1511 ms (MS-0030) |
| Largest snapshot answer | 135,107 bytes, 0.396 s | - | 126,861 bytes, 0.202 s (MS-0041) |
| Manager process ready after "Show manager" | 0.19 s | - | 0.20 s (MS-0041) |
| Show manager to a list that holds all 201 flows | 0.65 s | 10 s | 0.54 s (MS-0041) |
| Window: tree of 201 flows filled | 8 ms | - | 4 ms (MS-0041) |

Reading: inside the budget. The snapshot answer needs twice the time of MS-0041 for 6 % more bytes; the load of the machine was not recorded, so the cause is not known (assumed: load). Not a failure of any assertion.

## 4. Manual checks and gui tests for the owner (task 4, prepared; results open)

Nothing below was run by an agent. The owner records the results in `doc/MANUAL-CHECKS.md` (the "Result" column of the tables). Every call has a VS Code task.

Manual checks (`doc/MANUAL-CHECKS.md`):

| Check | Task labels | Expected result | Result |
|---|---|---|---|
| Section 1, part A (steps 1 to 13): tree, categories, enable, duplicate, delete, run, notices, log, tray menu | "Setup: fresh data folder for the manual checks (manual_check.py prepare)" (optional, the start does it), "Start: manual check 1, manager in a fresh data folder (manual_check.py)" | every step as the table says; no dialog (class `#32770`) except the questions | open |
| Section 1, part B (steps 14 to 22): import of a copy of the owner's v1 folder | "Setup: copy of the v1 data folder for the import check (manual_check.py copy-v1)", then the same start task | the report lists every flow and the MIGRATION places, flows disabled, `%APPDATA%\AutoHotFlow` unchanged | open |
| Section 1, part C (steps 23 to 26): scaling 100 % and 225 %, killed manager | the start task of part A | readable windows at both scales; the tray icon brings the manager back (REQ-USE-090, REQ-ROB-120) | open |
| Section 1, parts D and E (steps 27 to 43): enabling imported flows, notices, categories, `.ahf` export and import | the start task of part A (D after B) | as the tables; known open points F-0123 (dialog instead of notice) | open |
| Section 7 (steps 1 to 17): start without parameters, start with Windows, run as administrator, both together (real log off and log on, real UAC) | "Start: AutoHotFlow without parameters (the real data folder, manager and tray, as a double click)", "Start: manual check 7, start with Windows and run as administrator (manual_check.py)" | warning in the section: it changes the real startup folder; clean up in step 17 | open |
| Section 8 (steps 44a to 59): settings dialog, language, about | the start task of part A | complete texts at 100 % and 225 %, German without a restart, About window | open |

`gui` tests (windows open, the PC must not be used); expected result: all pass.

| Task label | Test file | Tests |
|---|---|---|
| "Test: manager window (gui, a real window opens; ...)" | `tests/fault/test_manager_window.py` | 9: window, selection, close box hides, exit button, crash of the manager, tree, drag and drop, notices list, wrapped question text |
| "Test: tray icon and menu (gui, ...)" | `tests/fault/test_tray_role.py` (`-m gui`) | `test_the_real_icon_opens_its_menu_and_a_menu_open_for_8_seconds_does_not_make_the_role_hung` |
| "Test: settings dialog and about window (gui, ...)" | `tests/fault/test_manager_settings_window.py` | 3: dialog and Cancel, language change of an open dialog, About |
| "Test: gui (--all -m gui, ...)" | all gui tests | the aggregate of the three above plus the older ones |

Results of the gui tests: open (owner). The test `test_the_window_fills_its_tree_with_200_big_flows` ran once in my stress run and passed (section 2); the owner need not run it.

## 5. Documents (task 5)

- **REQUIREMENTS.md:** all 38 requirements that name S0004 in their plan were read against their evidence (`python tools/doc_index.py --check` verifies that every evidence path and test exists). Changed: REQ-MGR-090 (notices done, real icon open), REQ-MGR-140 (stale "until then the stub"), REQ-MIG-060 (settings import tested, window open), REQ-ROB-120 (open to partial, with the evidence), REQ-PRF-030 (MS-0042, MS-0043), REQ-TST-060 (the guides and what is open). No requirement was set to `done` by this item. Still `partial` and why: REQ-EXE-050/130/170, REQ-USE-010 (editing per flow or the element list: S0007), REQ-EXE-060/140, REQ-TRG-050, REQ-VAR-100, REQ-EDT-150 (open, editor: S0005), REQ-USE-040, REQ-USE-080 (editor, S0005 to S0007); REQ-MGR-010/020/030/040/050/070/090/100, REQ-MIG-060/070, REQ-SEC-060, REQ-USE-030, REQ-USE-090, REQ-LNG-010, REQ-SET-020/030/040, REQ-TST-060, REQ-ROB-120, REQ-PRF-030 (the window parts are checked by the owner only, section 4; PRF-030 also waits for the editor). `done`: REQ-MGR-080, REQ-MGR-140, REQ-SET-010/050/070, REQ-LNG-020.
- **PROTOCOL.md:** every `cmd.*` and `evt.*` string in `src/` (112) is documented (checked by a script; only `res.flow.start` is a generated name). 11 documented types are not in `src/`: the test commands (`cmd.test.*`, test roles), `cmd.exe` (an example), and `evt.connection.state` and `cmd.ui.confirmDeleteFlowFile` (documented as sent by the engine but no string in `src/`; not investigated, finding F-0142*).
- **ARCHITECTURE.md:** section 8 updated (ui_common exists, the file list of the manager, the new core files); section 9 gets the numbers of MS-0042; sections 3 and 6 were read against the code and needed no change (6.1 items 5, 7 and 8 match `Supervisor.ahk`). **MIGRATION.md:** M-0046, M-0075 and M-0086 updated (all M IDs used in `src/`, `tests/` and `doc/` exist). **`.vscode/tasks.json`:** a task for the new test; the manual checks and gui tests already had tasks.

## 6. Retrospective (task 6)

What was hard in the UI roles (details in `doc/howto/gui-and-hotkeys.md`, 22 entries, most from S0004): a menu or a standard dialog stops the timers of its process (hence the role `tray`); the DPI awareness and the layout of controls (clipped texts, F-0128); the tree view events and drag and drop across processes; closing a window must hide, not end, the role; windows can only be checked by the owner, so every part with logic was moved into the model and the form classes and tested headless or in AHK unit tests (`manager_settings_window.test.ahk`). Load-dependent flakes of the manager e2e tests were the main cost of the verification runs (STATUS.md: the closing-log test, the burst log test, the category tests); they were green alone every time (cause per test assumed: waiting for state with fixed times under load).

What S0005 (the editor) needs from `ui_common/` and the manager:

- `ui_common/UiWindow` (DPI, layout in `core/GuiLayout.ahk`), `UiDialogs` (questions that do not block), `UiFileDialogs`, `UiTexts` (language reload) are the base for the editor window; the manager shows how: model without GUI code, view, headless driver (`cmd.test.*`).
- The editor must be started by the manager ("Edit" is disabled until then, REQ-MGR-040): a command that starts one editor process per flow (ARCHITECTURE 3; the message is not defined yet, PROTOCOL must get it); the manager side (the button, the tray icon of an editor, REQ-EDT-230) is not built.
- The notices (WI-0075) have a reserved place for the variable window of an error (REQ-USE-080, S0007); `OpenLog(flowId)` of the manager waits for the flow settings.
- The renderer interface (`Renderer`, D0004) has no code yet; the editor is the first user of `evt.flow.*` per flow with `epoch` and resync as the manager does (WI-0073).
- Open points the owner decided or left: F-0123 (message of a missing trigger is a dialog), F-0121/F-0139 (tree label and language change of the log and notice windows without a test), F-0135 to F-0138 (elevation limits).

## 7. Runs (task 7)

| Run | ID | Commit | Result |
|---|---|---|---|
| fast, parallel | 20261019-195119-a94365a0 | `a94365a0` | 1605 passed, 1 skipped (4:14) |
| fast, serial (`--workers 0`, 13 min) | 20261019-200110-a94365a0 | `a94365a0` | 1605 passed, 1 skipped, 683 deselected (13:13) |
| foundation | 20261019-195119-a94365a0-3 | `a94365a0` | 471 passed, 1 skipped (2:28) |
| slow | 20261019-195119-a94365a0-2 | `a94365a0` | 204 passed (9:47) |
| `-m stress` | 20261019-193837-87921e6c | `87921e6c` | 32 passed, 2257 deselected (11:39), includes one gui test (section 2); documents only differ afterwards |

`tools/verify.py` VERDICT green for fast, foundation and slow. The gui tier was not run by design (apart from the accident in section 2). No red test, no flake in these runs.

## 8. Findings (provisional IDs)

- **F-0141*** (low): the storage and import commands `cmd.storage.ahf.pack/unpack`, `cmd.storage.startup.sync`, `cmd.storage.v1.list/read`, `cmd.import.scan`, `cmd.import.v1.vars` have no test that sends them directly (error answers of bad payloads are not tested); they run only through the manager chain and the supervisor.
- **F-0142*** (low): PROTOCOL documents `evt.connection.state` and `cmd.ui.confirmDeleteFlowFile`, but no string of these types exists in `src/` (not investigated whether they are generated names or dead).
- **F-0143*** (low, tooling): `-m stress` selects the gui variant `test_the_window_fills_its_tree_with_200_big_flows`, so a stress run opens a real window. Proposal for the owner: add `and not gui` to the stress selection or drop the `stress` mark from the gui variant.
- Not done: no owner decisions were taken; no requirement `Prio`, `Scope` or `Doubt` was changed.
