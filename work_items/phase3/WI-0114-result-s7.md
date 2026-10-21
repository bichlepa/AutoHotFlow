# WI-0114 Result: acceptance of S0007 (agent part, 2026-10-22)

Code state of the runs: commit `d6558ccb` (rebased onto `v2-port` at `f65ebc56`). The commits of this item (workspace `wip/wi-114`, not merged): `d6c59a6c` (core-set test), `5e1629b3` (requirements), `cb0ab6f1` (manual check 11 and task), `b10d43f3` (findings), `d6558ccb` (HOW-TO). Status words: verified (read or run), assumed, not checked.

**Verdict.** S0007 is **not accepted**. The agent part is done: every core element is changed through its settings form, saved and run (new test, 29 cases, green), the documents match the code, and the runs are recorded below. Open for the owner: manual check 11 (section 11 of `doc/MANUAL-CHECKS.md`, steps 1 to 42, at 100 % and 225 %) and the six gui tests of part G. Nothing is claimed closed. The S0008 proposal (section 7) waits for the owner's session.

## 1. The acceptance of S0007, point by point

| # | Criterion (README "Acceptance S0007") | Evidence | Status |
|---|---|---|---|
| 1 | Every core element is opened, changed and saved through its dialog in a headless test, and its new parameters run; every field type of v1 is covered by a test element | `tests/e2e/test_core_settings.py` (29 cases, one per class of the core set; part A: form and file and engine, part B: the saved file and the rebuilt flow with probes); field types: `tests/elements/Test/Actions/Action_TestForm.ahk` with `tests/ahk/editor_form.test.ahk` (Edit, multi-line, check box, radio, slider, drop-down, combo box, hotkey, button, file, folder, week days, date and time, list box) | **met (headless)**. The core set uses edit, multi-line, check box, radio, drop-down and list box only; slider, combo box, hotkey, file, folder, week days, date and time and button are covered by the test element alone (OPEN-ITEMS F-9002*) |
| 2 | `CheckSettings` of every core element runs without an error for its defaults; an element that throws gives a warning and the editor keeps running | Part A of the core test asserts `warnings == []` when the form opens (29 cases; the cases with initial parameters check those, not the bare defaults). Throwing `CheckSettings`: the test element `Action_TestForm` (`ThrowInCheck`) in `tests/ahk/editor_form.test.ahk` | **met (headless)**. The defaults of the core set are not checked alone (the cases with `initial` use their own parameters) |
| 3 | An expression with a syntax error shows a warning with its position while the user types (REQ-EDT-200) | `tests/e2e/test_editor_settings.py::test_a_syntax_error_of_an_expression_is_shown_after_typing_stops_and_goes_when_fixed`; `tests/ahk/editor_form_expr.test.ahk`; manual check 11, part A (steps 1 to 8) | **met (headless)**; the look is the owner's. REQ-EDT-200 is set back to `partial` for this reason |
| 4 | The flow settings change the policy, the working directory, the type mode, the limits and the notices of the flow, and the engine uses them | Dialog to patch: `tests/e2e/test_editor_flow_settings.py` (5 tests). Engine: policy and global working directory `tests/integration/test_settings.py` (`..._execution_policy_...`, `..._working_directory_...`), the limit of a flow `tests/integration/test_settings.py::test_a_limit_of_the_flow_wins_over_the_global_one` and `tests/integration/test_core_d_flows.py` (flow limits), the notices `tests/integration/test_flow_settings.py` (2 tests), the type mode `tests/ahk/element_evalparams.test.ahk`, the per-flow working directory as a function `tests/ahk/vars_model.test.ahk` | **met (headless), with one gap**: a run that reads `A_WorkingDir` of a flow with its own folder is not tested end to end (OPEN-ITEMS F-9008*) |
| 5 | Every core element has a help page that opens from its dialog (REQ-ELM-020); the help opens from the manager (REQ-LNG-040); the setting chooses the viewer, `auto` falls back to the classic viewer without the loader DLL (E0099); the generated HTML is current (E0100) | Pages: `tests/test_help.py` (29 core pages, generated pages current, links resolve). Viewer routing and the setting: `tests/fault/test_help_role.py` (7 tests). Loader: `tests/test_webview2_loader.py`. Dialog button: `src/editor/ElementSettingsWindow.ahk` (`Help` calls `controller.Help()`), not run headless. The real windows: gui tests `tests/fault/test_help_window_gui.py`, `tests/fault/test_help_webview2_gui.py` (owner) | **partly met**: the generator and routing are tested; the button in the dialog and the three viewers in a window are the owner's (manual check 11, parts D and G) |
| 6 | An unhandled error opens, from its notice, the window with the variables of the branch (REQ-USE-080) | `tests/integration/test_error_window.py` (4 tests, incl. the copy bounded to 200 variables); `tests/fault/test_error_window_gui.py` (owner) | **met (headless)**; the window itself is the owner's (manual check 11, part F). Clear-text values: F-9005* (owner decision) |
| 7 | The owner configures elements of the imported v1 flows at 100 % and 225 % (manual check 11), with the assistants and the help | `doc/MANUAL-CHECKS.md` section 11 (42 steps, parts A to G), VS Code task "Start: manual check 11, settings, help and the error window (manual_check.py)" and the gui tasks of part G | **open: the owner's check.** Nothing is claimed closed. REQ-EDT-120, 130, 140, 200, REQ-ELM-020, REQ-LNG-040, REQ-USE-080 stay `partial` |
| 8 | Serial, parallel, `-m stress`, foundation and slow runs are green | Section 3: fast, foundation and slow green on `d6558ccb` (parallel); stress 34 passed; serial 108 passed on the S0007 files | **met for the agent runs** (serial of the full fast tier not run) |

**Documents (task 4).** REQUIREMENTS: the S0007 requirements have `v2`, `Plan` and `Evidence` (`5e1629b3`; REQ-EDT-120, 130, 140, 200 (back to `partial`), REQ-ELM-020, REQ-LNG-040, REQ-USE-080, REQ-TST-060 changed; the others were current from their work items). ELEMENT-API-V2, PROTOCOL, ARCHITECTURE section 8: assumed current from WI-0105 to WI-0115 (the `help` role and `editor/form` are named in ARCHITECTURE section 8, read; the other sections were not re-read in full); no interface changed in this item, so PROTOCOL was not touched. MIGRATION: M-0064 is back (done by WI-0107, row checked). MANUAL-CHECKS section 11 rewritten (`a8b7fa77`, the expression steps 1 to 8 kept, numbers kept). `.vscode/tasks.json`: one new task "Start: manual check 11"; the seven gui tasks of part G exist (checked by label). `python tools/doc_index.py --check` passes.

## 2. The tasks of WI-0114

1. **Criteria:** section 1.
2. **Every core element editable:** `tests/e2e/test_core_settings.py` (commit `d6c59a6c`), 29 cases, all green. Each case: part A in the editor (manager, storage, engine, one editor, `cmd.test.form`: open, field check, set, OK, file and engine check); part B in the runner (the saved file as it is, and the same flow rebuilt from the saved parameters with probes; the results checked per case: probe value, branch, loop rounds, exception; the saved file must take the same path). Run time: about 64 s with 4 workers (2 sessions per case, about 4 s each). Group table: `editor`, `elements-e2e`.
   - Cases that cannot be shown by a probe: `Condition_Debug_Dialog` has no parameter (the case changes its name); `Condition_Flow_Running` and `Action_Stop_Flow` check only that the flow is not running (the `callee` flow never runs); `Action_Execute_Flow` checks no exception with `SkipDisabled` (the called flow may be disabled). These are weak checks, named here so that nobody reads more into them.
3. **Manual check 11:** section 11 of `doc/MANUAL-CHECKS.md` and the VS Code task (commit `a8b7fa77`, in the rebased history `cb0ab6f1`). Open for the owner.
4. **Documents:** section 1.
5. **Retrospective and S0008 proposal:** sections 6 and 7.
6. **Runs:** section 3.

## 3. Runs

| Run | Commit | Result |
|---|---|---|
| `python tools/verify.py --ref d6558ccb --tiers fast,foundation,slow` | `d6558ccb` | VERDICT green: fast `20261022-000649-d6558ccb-3` 2245 passed, 1 skipped (984 s); foundation `20261022-000649-d6558ccb-2` 471 passed, 1 skipped (240 s); slow `20261022-000649-d6558ccb` 206 passed (280 s). No red test, so no recheck |
| stress, `-m stress` (run_suite, admission, exclusive) | `d6558ccb` | `20261022-002732-d6558ccb`: 34 passed (673 s) |
| serial (`-n 0`, run_suite): the core-set, editor settings and flow settings e2e files, the editor flow context, error window, flow settings, help (`tests/test_help.py`, `tests/fault/test_help_role.py`) | `d6558ccb` | `20261022-003849-d6558ccb`: 108 passed (392 s) |
| gui tests | not run (the owner's, part G of manual check 11) | |

An earlier run of the same code before the rebase (`cc5ad63a`, run `20261021-235734-cc5ad63a-2`, 206 passed, about 285 s) was stopped on purpose and is not a result.

## 4. Decisions taken by the implementer

- **Parameters of the editor flow:** the element of each case is built with its initial parameters (the defaults where none is given), and the probes exist in part B only. Reason: the editor runs the product entry, which has no Test package, so a probe element would be unknown there.
- **The run of the saved file** is compared with the rebuilt flow by the names of its steps (probes excluded). Reason: the rebuilt flow alone would not prove that the saved file runs.
- **Loop rounds are read from the log** (a trace point in the body), not from the step names (HOW-TO tests-and-tools).
- **REQ-EDT-200 back to `partial`:** the requirement was `done`; the lead's instruction and the owner's manual check 11, part A, decide its look. Status change only, no Prio or Scope change.
- **Eight provisional findings** (F-9001* to F-9008*) for the points the handover names and that no entry had. Renumbering is done by the integrator.
- **No measurement added** (not asked by the item; the run time of the core test is above).

## 5. Known open items of S0007 and their status

| ID | What | Status |
|---|---|---|
| F-0171 | Real mouse and keys of the editing actions have no gui test | open, owner's manual check 10 |
| F-0172 | ko and ru texts of the editor and the assistants are missing (fallback to English) | open, low |
| F-0173 | F-0158 (UTF-16 language files) not reproduced | open, owner to close or confirm |
| F-0162 | The drag of 30 elements is above the frame budget | decision needed |
| F-0175 | REQ-USE-080 names REQ-USE-070 for the switch of the notices | decision needed |
| F-0176 | Show log without a running manager starts the manager; the log is not filtered | open, low; manual check 11 step 31 |
| F-0178 | The help request of a role that is still starting is not tested end to end | open |
| F-0179 | The WebView2 viewer does not handle a new-window request | open, low |
| F-0167 | The general v1 help pages are not in the repository | decision needed (owner) |
| F-9001* | The slider is fixed to the range 0 to 100 (v1 passes field options) | open |
| F-9002* | The mouse and colour assistants and the field types that no core element uses | open, for S0008 |
| F-9003* | The tracker mode is relative to the tracker window itself | open, assumed (handover) |
| F-9004* | The colour dialog with the pipe is not measured (proposal: extend E0076) | open, owner decides |
| F-9005* | The error window shows variable values in clear text | decision needed (NEEDS-ATTENTION.md) |
| F-9006* | String texts are not checked as expressions | decision needed (owner) |
| F-9007* | The WebView2 loader hashes come from one download | open, repeat with S0009 |
| F-9008* | A flow with its own working directory is not run end to end | open |
| (no entry) | ko and ru texts of the assistant keys | covered by F-0172 |

## 6. Retrospective (task 5)

- **Hard:** the form model and the window had to share one code path (the test drives `cmd.test.form`, the window calls the same functions), so the headless test proves the window's logic and not its drawing. The loop counts and the hidden variables gave wrong answers at first (HOW-TO tests-and-tools, two entries). The probes need a test element in the run session, so the editor session and the runner session are separate; the test writes the saved file between them.
- **Help viewers:** three viewers behind one interface and a setting (E0099) cost more than the pages; the WebView2 loader is a COM wrapper of our own (E0085). HOW-TO entries of WI-0111 and WI-0115 hold the details.

## 7. Proposal for S0008 (for the owner's session; not decided)

1. **Start with the converter** (E0036): the core set is the before/after set. The new core test (`tests/e2e/test_core_settings.py`) is the pattern: one case per class, initial parameters, changes, probes, expectation. Each S0008 element gets its case when it is ported.
2. **Field types the other elements need** (the core set uses none of them): slider (F-9001*, the range is fixed), combo box, hotkey, file, folder, week days, date and time, button. The test element `Action_TestForm` covers them headless; a gui check of their look is not planned yet.
3. **Assistants:** the mouse assistant and the colour assistant (no element uses them yet), and the window assistant beyond the Hotkey trigger (F-9002*). Their gui checks (`tests/fault/test_editor_assist_gui.py`) run once an element uses them.
4. **Help pages of WI-0112** (`work_items/phase3/WI-0112-result.md`, section "List for S0008"): AutoHotkey code in `AutoHotkey_script` and `AutoHotkey_Script`; AutoHotkey mentions in the mouse, keyboard and hotstring pages; `%name%` examples in the file pages and `Split_a_string` and `Trim_a_string`. The other pages are converted and unchecked.
5. **Open decisions that S0008 needs:** F-9006* (String texts as expressions) and F-9005* (clear-text values) before the elements with text fields come.

## 8. Not checked

- The look and the feel of every window of part G and of manual check 11 (owner).
- The dialog button "Help" and the three viewers in a real window (owner; gui tests and manual check 11, parts D and G).
- The defaults of the core set alone (the form check runs on the cases' parameters).
- The run of a flow with its own working directory (F-9008*).
- The fallback of `auto` without the loader DLL in a real session (only the routing test).
- The full serial fast tier (the serial run covers the S0007 files of section 3, not the other 2,200 tests; those ran in parallel in the verify run).
