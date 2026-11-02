# Open Points

Status: 2026-10-21, branch `v2-port`. Findings are carried in the summary table below; closed ones are in `doc/CLOSED-ITEMS.md`.

This document lists everything that is still open, observed, or deferred. History of the early findings (F-0001 to F-0043): tag `v2-phase2-final`, table "Funde" in `v2-phase2-final:work_items/STATUS.md`. The work-item files that this document cites were removed from the working tree; they can be read with `git show v2-phase2-final:<path>`.

Entries marked **(phase 3)** matter for the phase 3 plan.

Closed and accepted findings are in `doc/CLOSED-ITEMS.md`. Entries that wait for the project owner are in `NEEDS-ATTENTION.md` (repository root), not here.

Status words follow the sources: *verified* (read or tested), *assumed* (suspected, not proven), *not checked*. "Read in code" means the source was read but the behavior was not reproduced.

## Summary

Entries that only observe (not for the bug hunter) are in the chapter "Observed only (not for the bug hunter)" below the findings.

| ID | Title | Status | Phase 3 |
|---|---|---|---|
| F-0180 | The slider of the settings form is fixed to the range 0 to 100; v1 passes the options of the field (WI-0105 form model, WI-0106 window) | open, not checked for a real v1 slider; the owner decides whether the options of a field are needed for the elements of S0008 | S0007 |
| F-0181 | The mouse and colour assistants have no element of the product yet, and the window assistant is used by the Hotkey trigger only (WI-0110); the field types Slider, ComboBox, Hotkey (apart from the trigger), File, Folder, weekdays, DateAndTime and Button of the form are shown in the product by no element of the core set | open for S0008: the elements that use them come with S0008; until then they are checked by the test element `Action_TestForm` (headless, `tests/ahk/editor_form.test.ahk`) only | S0008 |
| F-0182 | The window mode of the tracker of the mouse assistant is relative to the tracker window itself, not to the target window (WI-0110, from the handover of WI-0114) | open, assumed from the handover; not checked on screen | S0007 |
| F-0183 | The colour dialog behaves differently when the pipe is busy; it is not measured (WI-0110); proposed as a extension of E0076 | open, not measured; the owner decides on the extension | S0007 |
| F-0184 | The window of an unhandled error shows the values of the variables in clear text (WI-0113); a secret in a variable is shown on screen | decision needed: the owner, see NEEDS-ATTENTION.md | S0007 |
| F-0185 | Text fields with the content type String are not checked as expressions (WI-0108): a `%name%` or a `{` in a text is not a warning | decision needed: the owner confirms that the content String is no expression | S0007 |
| F-0189 | The settings window draws every slider from 0 to 100: the range of a v1 slider option (e.g. -10 to 10) is ignored (WI-0124, found while porting the speech and volume elements; the sound elements use number fields for those ranges, M-0132) | open, low; the element types that need another range use a number field | later |
| F-0190 | Blocking waits of the sound elements have no deadline: `SystemOps.Real.SpeechWait` loops with Sleep(50) without a limit or stop check, a synchronous speech, `SoundPlay` with wait and `SoundBeep` with a very long duration block the worker in one call (WI-0124 review); the cancel is answered only when the job yields, otherwise the job deadline and the supervisor kill apply | open, read in code, real behaviour not checked; cheap follow-up: cap the SpeechWait loop and clamp the Beep duration; also the upper Beep frequency bound 32767 has no test | WI-0124 |
| F-0191 | Worker and force-question tests that fail under load and pass alone: `test_worker.py` (`..._reports_not_busy_after_a_cancel_too`, `..._reports_busy_when_a_job_begins_and_ends`, `test_shutdown_with_a_job_and_a_hub_that_reads_late_...`), `test_editor_tray.py` / `test_editor_flow_ctx.py` (the force question of an unreadable state), `test_worker_lifecycle.py` (cold start); each was red in a full run and green in `recheck.py` several times during S0008 (2026-10-22 and 2026-10-23, runs of several agents at the same time) | open, observed; candidates for a hunter round: the tolerance of these tests under load, not the product | tests |
| F-0192 | Input blocked by `Action_Block_User_Input` may stay blocked when its worker is killed: the release (`SystemOps.ReleaseInput`) runs only at the orderly shutdown of the worker (WI-0126, M-0156); whether AutoHotkey or Windows release a block of a killed process is not checked | open, not checked; the owner's manual check: block the input in a flow, kill the worker (hang) and see whether the keyboard works; the fix would be a release from another process (not possible with the block) or a warning in the help | Phase 3 (S0008, WI-0126) |
| F-0186 | The WebView2 loader DLL hashes (WI-0115) come from one download; a second download was not compared | open, not checked; the hashes are checked again when the loader is updated (S0009) | S0007 |
| F-0187 | A flow with its own working directory (flow settings, DefaultWorkingDir off) is not run end to end: `BuiltInVars.WorkingDirOf` is tested as a function (`tests/ahk/vars_model.test.ahk`) and the global working directory is tested in a run (`tests/integration/test_settings.py`) | open, not checked end to end (WI-0114) | S0007 |
| F-0188 | The path guards of the file and folder elements (WI-0120, M-0119) miss the extended-length prefix and UNC share roots as roots, check only the raw parameter for an empty path (a `%var%` that expands to empty reaches the working directory; only Delete_Folder refuses the working directory), and allow Move_Folder and Rename_Folder on the working directory itself | open, found in the review of WI-0120; read in code, not tested | WI-0120 |
| F-0175 | REQ-USE-080 names REQ-USE-070 for the switch of the notices, but REQ-USE-070 is the requirement of hints (WI-0109; PROTOCOL 4.7 follows the same wrong reference) | decision needed (correct the reference, or give the switch its own requirement); the owner decides | WI-0109 |
| F-0178 | The help request of the supervisor for a role that is still starting (the page sent at its hello) and the requests of the manager and the editors are not tested end to end: the tests can only send as an observer, which the supervisor refuses (WI-0111) | open, not checked | WI-0111 |
| F-0179 | The WebView2 help viewer does not handle a new-window request (`target=_blank`): the runtime would open its own unfiltered window; the handlers of the viewer are kept for the process (WI-0115) | open, low: no help page has such a link | WI-0115 |
| F-0176 | Show log with no running manager starts the manager, and the log window is not filtered to the flow (WI-0109, PROTOCOL 4.11) | open, low; the manager is normally running | WI-0109 |
| F-0162 | The frame of a drag of 30 elements in a flow of 300 is 25 ms at 1920 × 1080 (budget 16 ms); one element meets it (WI-0097, MS-0051) | decision needed, measured; WI-0097 | WI-0097 |
| F-0171 | Real mouse and real keys of the editing actions (select, move, add, connect, delete, the menus) are not in any gui test; only the wheel, the drag of the view and the menus have one (WI-0104, REQ-EDT-050 to REQ-EDT-080) | open; owner's manual check 10 covers it | S0006 |
| F-0172 | The editor texts of the Korean and Russian language files are missing; these languages show the English text (fallback of LangTable) (WI-0104) | open, low; translation not done | later |
| F-0173 | Finding F-0158 (language files UTF-16) is not reproduced: `assets/language/basic/*.ini` and the manager files have no NUL bytes and are read as UTF-8 (WI-0104, checked by bytes) | open, to be closed or confirmed by the owner | S0006 |
| F-0163 | The rename of a flow (`cmd.flow.meta.update`) writes the file at once, from the revision of the request; a patch committed while storage writes it is in memory only until the next `cmd.flow.save` (WI-0093, meta race) | closed, verified (WI-0095: the engine writes again after every commit; option (a)) | S0006 (WI-0093, WI-0095) |
| F-0164 | A patch that changes the text of an element that still waits for its class (`v1Text` marker) keeps the marker: the new v2 text is converted when the class appears (WI-0093) | decision needed | S0006 (WI-0093) |
| F-0154 | `verify.py --auto` (also `select_tests.py --from`, `pytest --changed-from`) refused every range that deletes a file with "not classified by any test rule": a deleted path has no rule once it is gone (WI-0088 removed `src/core/PlaceholderRole.ahk`) | closed, verified (`tests/test_groups.py`, a deleted path selects everything) | tooling |
| F-0129 | A `.ahf` written by tar.exe is not read by 7-Zip or by v1 in any test (v1 writes a flat ZIP with 7-Zip, tar writes the same layout). Reading a real v1 `.ahf` is tested (`tests/data/ahf/v1_export_two_flows.ahf`) | open, WI-0081; ask the owner for a v1 file of another kind (more flows, statics) | WI-0081 |
| F-0130 | Drag and drop of an `.ahf` file onto the manager and the file dialogs of the import and export are not automated (the gui tier is not run by agents) | open, WI-0081; only MANUAL-CHECKS part D checks them by hand | WI-0081 |
| F-0167 | The general pages of the v1 help (Welcome, Variables, Key list, Color chart) are not in the repository: `v1/Help/en/` is ignored by git. They were converted from the owner's working copy (WI-0112); the Markdown is the only copy in the repository now, and the converter needs that copy again | open, WI-0112; the owner decides whether the v1 text is kept anywhere besides the repository | WI-0112 |
| F-0131 | A name outside the ANSI code page may make the listing of tar fail: the listing is read as text in the ANSI code page, and a failed listing reads as "not a ZIP archive" | open, not reproduced (WI-0081) | WI-0081 |
| F-0132 | UNC paths (`\\server\share\x.ahf`) are refused: the path must start with a drive letter | open decision for the owner | WI-0081 |
| F-0139 | The windows of the log and of the notices are relabelled on a language change (`LogWindow.Relabel`, `NoticeWindow.Relabel`), no test reads their texts; checked by hand only (MANUAL-CHECKS section 8, step 50) | open, verified in code, not checked on screen | WI-0078 |
| F-0133 | The link branch of `ArchiveUnpack._CheckTree` and the link refusal of `ArchiveEntries.CheckListing` have no test (a junction, `mklink /J`, would test the tree check) | open, WI-0081 | WI-0081 |
| F-0134 | The flow JSON of an `.ahf` file is parsed in the manager without a depth limit (the unpacked size is limited to 4 MB, nesting is not): very deep nesting could exhaust the parser | open, not checked, WI-0081 | WI-0081 |
| F-0135 | A second start without elevation cannot reach a running elevated session (WI-0079): the instance mutex of the elevated process is not accessible (access denied), the start ends with exit 1 and a log line about higher rights; the pipe DACL (`PipeListener.SDDL`: system and owner) was not checked for a not elevated client. The second start from the Explorer shows no window and no message to the user | open, found in the design, not run for real (UAC is a manual check, MANUAL-CHECKS 7 step 14); possible fix: a mutex and a pipe that a not elevated process of the user may open | WI-0079 |
| F-0137 | The second start that is denied by an elevated session (F-0135) is silent when it has no console (double click, the shortcut): no window, no notice. A MsgBox is not allowed in the supervisor (no dialog rule), so a tray notice of the elevated session cannot be sent either (it cannot be reached). Possible follow-up: a small message from the failing start through a mechanism outside the supervisor role | open, WI-0079 review | WI-0079 |
| F-0138 | UAC over the shoulder (the administrator account differs from the user) and the working directory of the elevated start are not checked: the elevated process may see another `A_AppData` and `A_Startup`, so the default data folder and the shortcut may differ from the user's. `Run` passes `A_WorkingDir`, relative paths are not tested for real | open, not checked, manual check 7 step 11 | WI-0079 |
| F-0136 | The shortcut of Start with Windows has the icon of the interpreter (no own icon file exists in `assets/`), and the working directory is the folder of the script | open, minor, WI-0079 | WI-0079 |
| F-0141 | The storage and import commands of S0004 have no test that sends them directly | open, low, found in WI-0082 | WI-0082 |
| F-0073 | The stress test with 200 big flows fails its snapshot budget (largest snapshot answer during loading 2326 ms, budget 1000 ms); every flow file is parsed twice in the engine (F-0020 merged in) | budget raised to 3 s (E0042, owner 2026-10-15); stays open as an optimization after the port (pre-filter for inactive flows, one parse instead of two); measurements in WI-0046 | yes |
| F-0111 | Fast tier: `tests/integration/test_worker.py::test_worker_reports_busy_when_a_job_begins_and_ends` saw `[False, True, False]` as the `sys.busy` values instead of `[True, False]` | observed once (run 20261016-225151-4328, commit a3c0dad plus WI-0063 changes that do not touch workers); not reproduced; open, watch the history | |
| F-0126 | Import from v1 (WI-0076): the manager's choice "Import from v1" (button "Import and export"), its folder dialog, the report window and the two questions are not tested by any automated test (the window module is gui tier, not run by agents); the e2e tests drive the same chain through cmd.test.op | not checked; owner's manual check 1 (`doc/MANUAL-CHECKS.md`, part B) covers them | WI-0076 |
| F-0127 | Import from v1: a v1 shortcut counts as v1 when the target is named `AutoHotFlow.exe` or `AutoHotFlow.ahk` and lies in the imported folder or in a folder with the v1 layout (`Saved Flows` or `Variables`), and is not the running v2 product. An installed v1 whose install folder is neither the imported folder nor has that layout is kept, not removed | assumed: the portable layout is what the rule is made for; the installed case is not checked by hand | WI-0076 |
| F-0123 | A trigger that is not available after the user enabled its flow is shown as a dialog (`ManagerWindow._NoticeTrigger`, `UiDialogs.Confirm`), not as a notice; REQ-USE-030 asks for notices (tray or list) for messages without a window of their own | open; the flow is not blocked, but the window waits for a click; the change needs the trigger message routed through the notice path (WI-0075 built it) | WI-0075 |
| F-0124 | `ManagerModel.unseenIds` keeps an entry for a flow that is deleted before the user looks at its error (a tiny leak; the mark is never shown again) | open, found in WI-0075; the entries are small and bounded by the flows deleted in one session | WI-0075 |
| F-0125 | No test provokes a storage-error notice (`Notice_storage`, `Engine._StorageError`) | open, found in WI-0075; the path is built but not checked | WI-0075 |
| F-0114 | Load warnings in the trigger host and in `Trigger_Start_up`: a local `message` (`TriggerHost._CmdArm`, `ReportCallbackError`) and a local `type` (`Trigger_Start_up.Enable`) are reported as the same name as a global variable on every start of the trigger host (seen in the engine and triggerhost logs, WI-0064); the same trap as in `doc/howto/gui-and-hotkeys.md` (case-insensitive names) | observed, not checked whether it changes behaviour; a rename of the locals removes the warnings | |
| F-0118 | The question for an unknown state recognises the refusal by its text ("cannot be read (") instead of an error code | open, assumed; robust option needs an owner decision (`code: state_unknown`) | WI-0074 |
| F-0119 | A multi-selection of flows is not visible in the tree (only the focused item is highlighted) | open, verified in code; the owner decides on a mark | WI-0074 |
| F-0121 | The tree label of a running flow (`ManagerWindow._FlowLabel`) has no automated test | open, verified in code | WI-0074 |
| F-0122 | A multi-selection was lost on a later rebuild of the tree (fixed; no automated test, the path is only reachable through a real tree) | open, verified in code, not checked on screen | WI-0074 |
| F-0145 | The status "planned" of the oldest MIGRATION entries (M-0001 to M-0005, M-0010, M-0012 to M-0014) was never re-checked against the code | open, found in the documentation review; M-0014 is implemented in `LoopStack.Pop` (read) | documentation review |
| F-0146 | The `README.md` in the repository root describes v1 (downloads, installer, `find modules.ahk`, screenshots of v1) while the branch is the v2 port | open, low; rewrite at the end of the port (S0009/S0010) | documentation review |
| F-0148 | A thread of a flow that was just deleted may call `Executor._ElementStopped` after `ForgetFlow` and re-create a run-state record (a small leak and a stale `finished` event) | open, found in the review of WI-0086; read in code, not reproduced; a guard for a flow that is no longer in `flows` would close it | WI-0086 |
| F-0149 | WI-0087 tests: the two tests with a running editor (`test_a_second_edit_of_a_running_flow_starts_no_second_process`, `test_the_editor_limit_refuses_a_new_editor_with_busy`) depend on the manager sending its requests back to back, because the placeholder editor ends within about 200 ms; under heavy load they can fail. Also untested: `FlowIdOk` (quote, control character, trailing backslash, non-text), a clean bye as planned end, a crashed editor not restarted, the slot of a dead editor in the limit. Race: an editor that just died but is not yet judged still counts as running, so `cmd.editor.show` goes nowhere and the click shows nothing (at most 200 ms) | closed in WI-0088 (9832583f): long-lived editor, deterministic tests, the missing tests added, a dead editor's show is `busy` until judged | WI-0087 |
| F-0147 | The GDI leak check of `tests/ahk/gdip.test.ahk` counts only GDI handles (`GetGuiResources`): GDI+ brushes, pens, fonts and paths are not GDI handles, so a missing `GdipDelete*` would not fail it | open, found in the review of WI-0083; the deletes were verified by reading the code | WI-0083 |
| F-0150 | `SceneBuilder.Build` takes about 18 ms for 300 elements (MS-0046), more than the frame of a state change (6 ms): the window builds a new scene at every state change, so a state change costs about 25 ms before it is on the screen. A build that changes only the run states would save it | closed in WI-0089: `Scene.WithStates` takes a mean of 4.0 ms for 300 elements with 60 changed states, against 18.7 ms for a build (MS-0047) | WI-0085 |
| F-0152 | The word "break" in the break field of a loop is a literal in the renderer, not a language text | open, low | WI-0085 |
| F-0155 | The restart test after an editor death (`test_the_editor_of_a_flow_that_just_died_is_started_again_and_its_slot_is_free`) expected a started answer on a later request; since WI-0088 the first request is often the one that starts the editor, so the test failed under load in every full fast run | closed (test parametrized and robust; the old assertion fails in the judged-first case) | WI-0088, WI-0089 |
| F-0156 | The element states of a flow go out in batches: at most one `evt.element.states` per flow and 33 ms (WI-0089, owner decision). The message count is bounded for any flow. The size of a batch grows with the number of elements that change in one interval; for a flow of 300 elements at once it is not measured (MS-0047 measures a loop of three elements at the guard's limit: hub queue 0, latency p95 46 ms) | postponed by the owner on 2026-10-20; measured (MS-0050, WI-0092): a flow of 300 elements that all change in one interval sends 2 or 3 batches per start, the largest about 35 KB and up to 235 to 300 entries; the editor's latency is median 43.8 ms and p95 68.8 ms, above the 50 ms of REQ-PRF-060; the next step is postponed by the owner | WI-0089 |
| F-0157 | `tests/integration/test_pipe.py::test_abrupt_end_of_client_process_is_seen_within_500_ms[2]` is red under load: 1819 ms measured (budget 1500 ms) while the machine ran at 99 % CPU. A wall-clock latency assertion that is not covered by the admission of the test runs; not checked alone | open, verified (one red run under load); the owner decides whether it is a gui-tier or idle-tier test | WI-0090 |
| F-0160 | `tests/ahk/helpers/renderer_bench.ahk` under `#Warn All` warns about a local variable `type` (same name as a global) in `src/elements/Default/Triggers/Trigger_Start_up.ahk` line 47; the product does not run under `#Warn All`, so it is not checked whether the product shows it | open, low, verified by the bench output | WI-0092 |
| F-0193 | The imported v1 scripts of `Action_AutoHotkey_script` and `Trigger_AutoHotkey_Script` are not marked (MIGRATION M-0049): a v1 script of a migrated flow runs as v2 code and ends with an exception only when v2 cannot load it. Needed: the loader marks the script parameter, the element ends with "port it to v2" until the user changes it (WI-0093). | open, found by WI-0130 |
| F-0194 | The element list of another flow in the settings of `Action_Set_element_parameter` is kept until the settings window opens again (`EditorFlowCatalog.Refresh`): a change of the other flow while the window is open is not shown in its list until then. The value and the parameter list follow the list of the flow at the next check. | open, found by WI-0129 |
| F-0161 | Order inside a batch of element states: entries inside one 33 ms batch are in the order of the first change; a fast repeating failing element shows only its last state | postponed by the owner (2026-10-20), a note, no requirement | WI-0089 |
| F-0153 | The tint of a running element is drawn after all elements, so where a running element overlaps a later element of the scene, the tint lies over that element; v1 draws the tint with its element, so the later element covers it | open, low; the sample flows show no such overlap, not checked on a larger flow | WI-0085 |
| F-0195 | Trigger_Hotkey and Trigger_Hotstring carry the same window condition and registration code (ModeOf, Condition, the registration map, _SpecKey); the shared part belongs in `lib/` (WI-0131, ELEMENT-API-V2 shared code rule) | open, not changed in WI-0131 (the hotkey element is verified and was not touched) | S0008 |
| F-0196 | The language key "Omit the ending character after replacemenet" in en.ini and de.ini has the v1 typo; the label shows it (WI-0131, Trigger_Hotstring) | open, a text change in both language files; not a behaviour | S0009 |
| F-0197 | The "Dialog test" flow (Flow 130786371) has no gui part yet: the real input box is read by control and window title, its keys are sent to it, and the process name of the flow is `AutoHotFlow.exe` (WI-0128) | open, the owner's gui part with its fix list; the headless trigger runs (WI-0128) | S0008 (WI-0135) |
| F-0198 | MIGRATION has two rows with the ID M-0167 (the hotstring entry of WI-0131 and its registration case): WI-0128 uses M-0168 for the input box timeout | open, one of the two rows needs its own ID; the owner of WI-0131 decides which | S0008 |
| F-0199 | The DDC question: the WI-0127 description names resolution, colour depth, frequency and orientation, but v1 only changes the DDC/CI settings (brightness, contrast, gains, drives, colour temperature). Decision needed (owner): keep DDC only (as built), or add a DEVMODE function to the seam (`ChangeDisplaySettings`, not implemented). | decision needed | S0008 |
| F-0200 | Per-monitor DPI in the screen elements only: `ScreenOps.EnterPhysical` makes the coordinates of the screen elements device pixels; Click, Move mouse, Drag and the mouse tracker of the editor do not. Multi-monitor scales are not checked. | not checked | S0008 |
| F-0201 | The xdist INTERNALERROR of the selected run: the worker of `tests/test_ahk_runner.py::test_ahk_file_completes[json.test.ahk]` dies in full selected runs (WI-0127 runs 2 and 3, `--deselect` did not help); the test passes alone. Not reproduced in the verification run 20261102-123314-825e716a (2076 selected tests, no INTERNALERROR): probably a load or file-locking effect of parallel runs. | open | S0008 |
| F-0202 | Search pixel, Search image and Screenshot: the owner's manual check on a real desktop with several monitors and scales is open; the Search pixel mouse tracker sets the upper left corner only (the lower right corner is typed). | open | S0008 |
| F-0203 | The process triggers cost 8.7 % of one core with ten armed triggers at 100 ms (one process list per tick, MS-0044); the window triggers 2.3 %. The default interval of 1000 ms should cost about a tenth (assumed, not measured). Options: cache the base name per process ID (a reused ID must be checked, for example by the creation time) | open, decision for the owner: the default interval, and whether the cache is worth its risk | WI-0132 |
| F-0204 | Process triggers do not see processes that cannot be opened without the debug privilege (protected processes, a higher integrity level): their start and end are not seen (M-0176). v1 enabled `SeDebugPrivilege` and saw more | open, decision for the owner: whether the privilege is wanted (it needs the elevated program) | WI-0132 |
| F-0205 | The own-window helper of the window tests exists twice: `tests/integration/test_window_elements.py` (WI-0125) and `tests/support/ownwindow.py` (WI-0132); the process helper of `test_process_elements.py` (WI-0123) is the same kind of copy | open, low; move both into `tests/support/` when the next window or process test changes | WI-0132 |
| F-0206 | The label of the option of `Process starts` ("Do not trigger if a matching window exists when enabling the trigger") is the v1 text and says window; the help page explains it | open, low; a new language key for "process" needs the owner's decision on the text (en.ini and de.ini) | WI-0132 |
| F-0207 | `test_time_of_day_fires_at_its_time_and_not_again_that_day` fails when run alone: the test's fire time was 3 s ahead, but the session became ready about 5 s later (closed in 2ff5337d, see `doc/CLOSED-ITEMS.md`) | closed, verified | S0008 |
| F-9000* | The shortcut of a Shortcut trigger is written after the answer of its enable: a `Run` of the shortcut right after the enable finds no file ("Can't run" in the corpus flow, fixed in the test copy with a 2 s sleep) | open | S0008 (WI-0133) |
| F-9001* | A first start with `--command=debug` (not a trigger command) is ignored silently; only the second start opens the debug window | open, low | S0008 (WI-0133) |


## Findings

### F-0197: The "Dialog test" flow has no gui part yet

- **Found:** WI-0128 (read, the flow file): the trigger "Input Normal" (element 206) runs headless with the test provider; the other triggers (Confirmation Normal, Message Normal, Input Normal's checks, the debug dialogs) read `Get control text` of the windows `Dialog Test Title` (window class `AutoHotkeyGUI`, process `AutoHotFlow.exe`) and press buttons with `Send keystrokes to control` (`Button1` to `Button3`). Until S0009 the process is `AutoHotkey64.exe`, so the names of the flow do not find the window.
- **Open:** the copy in `tests/data/flows/v2_adapted/` with the process name and the control names of the v2 windows (`Edit1`, `Button1`...), and a gui test of the whole flow (the owner runs it, `-m gui`). The fix list gets an entry with a MIGRATION ID for each change. The keystrokes of the flow go to the real window: a gui test only.
- **Status:** not checked (the control names of the v2 windows were not read on a live window).

### F-0198: MIGRATION has two rows with the ID M-0167

- **Found:** WI-0128 (read, `doc/MIGRATION.md`): two rows of the end of the table are both "Hotstring: two triggers on one hotstring (WI-0131)" with the ID M-0167 in `v2-port` (the one row cites `tests/integration/test_hotkey_input.py`, the other `tests/ahk/element_hotstring.test.ahk`, registration case). The row before them is M-0166.
- **Open:** one of the two needs the next free ID. WI-0128 takes M-0168 for its entry; a later entry must take M-0169 or higher.
- **Status:** verified (read); the cause is not checked.


### F-0163: A rename writes the file from the revision of its request

**What:** `cmd.flow.meta.update` writes the whole flow file at once (E0065: a flow has no unsaved state). Since WI-0093 a patch can be committed while storage writes the file. The revision is then built on the current one (the meta race is fixed, `tests/integration/test_flow_patch.py::test_a_patch_committed_while_storage_writes_a_rename_is_kept`), but the file written at the request does not contain the patch until the next `cmd.flow.save`. A crash in that moment loses the patch, the rename is kept.
**Options:** (a) the engine writes the file again after such a commit (a second write per rename in that case); (b) a rename waits for the patch, or a patch is refused while a rename is pending (`busy`, as for a deletion); (c) the editor saves automatically a few seconds after every edit (WI-0095), which narrows the window to those seconds. The text of E0065 says that the file is always current, so (a) or (b) fits it best.
**Status:** closed, verified (WI-0095, option (a)): every commit, the one of a rename included, marks the flow for a write (`FlowSaver.NoteCommit`), and a commit during a write gives another write after it. `tests/integration/test_flow_patch.py::test_a_patch_committed_while_storage_writes_a_rename_is_kept` now waits until the file holds the rename and the patch; `tests/integration/test_flow_autosave.py::test_a_commit_during_a_write_gets_another_write_afterwards`. The window is now about 3 s, not until the next save. Not checked: a crash of the engine in that window (the old text is then in the file, the rename is kept in the file only after the write).

### F-0164: A pending element keeps its marker when a patch changes its text

**What:** an element whose class is not known yet keeps its v1 texts and the marker `v1Text` (E0021). WI-0093 keeps the marker when a patch changes the element (as the plan says). When the class appears, the loader converts the element's texts, which are then v2 texts that a conversion would change again, so the text the user typed may be converted as if it were v1.
**Status:** assumed; the conversion of a changed text was not run. Decision needed: a patch of such an element should drop the marker (then the new text is kept as typed, and the class of the element gets its texts from the editor), or the editor refuses to edit such an element.

### F-0129: A `.ahf` written by tar.exe is not read by 7-Zip or by v1

**What:** The export writes the ZIP with `tar.exe --format zip` (WI-0081 spike, decision in the work item). v1 writes the same flat layout with 7-Zip. Nothing in the tests opens a tar archive with 7-Zip or with v1. The owner's real v1 export is read by the tests (`tests/data/ahf/v1_export_two_flows.ahf`), the other direction is not.
**Status:** open, WI-0081. Ask the owner for a v1 file with statics, or a 7-Zip check by hand.

### F-0130: Drop and file dialogs are not automated

**What:** The drop of an `.ahf` file onto the manager window, the save and the open dialog of "Import and export", and the warning and conflict dialogs as shown are checked by hand only (MANUAL-CHECKS part D). The headless tests answer the questions of the chain themselves.
**Status:** open, WI-0081.

### F-0131: Names outside the ANSI code page and the listing of tar

**What:** `ArchiveTar.Text()` reads the listing of tar as text in the default code page. A name with characters outside it may come out wrong, and the entry check then refuses the archive with a text that suggests the file is not a ZIP archive at all.
**Status:** open, not reproduced (no such archive in the tests); the message is misleading in that case.

### F-0132: UNC paths are refused

**What:** `Storage._AhfPath` accepts only paths that start with a drive letter. A file on a network share (`\\server\share\x.ahf`) is refused with a message.
**Status:** open decision for the owner (the rule is simple to relax, but it would need tests on a share).

### F-0133: The link branches have no test

**What:** The refusal of a link in `ArchiveEntries.CheckListing` and in `ArchiveUnpack._CheckTree` is not covered by any test: tar writes no links from our archives, and an archive with a link is not in the tests. A junction (`mklink /J`, no privilege needed) would test the tree check.
**Status:** open, WI-0081.

### F-0134: No depth limit for the JSON of a flow in an archive

**What:** The unpacked size is limited (4 MB, `ArchiveEntries.MAX_UNPACKED_BYTES`), the number of entries (2000) and the file size (50 MB). The JSON parser of the manager has no nesting limit: a flow that nests very deeply could exhaust the recursion of `Json.Parse`. Not measured.
**Status:** open, not checked; a depth check before the parse (a scan of the brackets) or a measurement with a deep file would settle it.

### F-0123: The trigger-not-available message is a dialog, not a notice

**What:** After the user enabled a flow, a trigger that cannot be armed (REQ-MIG-070) is shown with `UiDialogs.Confirm` (`src/manager/ManagerWindow.ahk`, `_NoticeTrigger`). REQ-USE-030 asks that messages without a window of their own reach the user as notices, and WI-0075 built that path (`evt.ui.notice`, the list of notices). The dialog does not block the flows, but it waits for a click and does not appear in the list.
**Status:** open, found in WI-0075; the change is small (send the message as a notice of the manager, or mark the flow), but it changes what the user sees for REQ-MIG-070, so it needs the owner's decision.

### F-0124: The manager's error marks outlive deleted flows

**What:** `ManagerModel.unseenIds` gets an entry for every flow with an unhandled exception that the user has not looked at. A flow that is deleted before that happens keeps its entry (the snapshot does not remove it).
**Status:** open, found in WI-0075; a tiny leak, bounded by the flows deleted in one session. Clean the entry when a flow vanishes from a snapshot.

### F-0125: No test of the storage-error notice

**What:** `Engine._StorageError` sends a notice of kind `storage` (Notice_storage) when the engine is connected. No test makes storage fail that way, so the text and the path are not checked.
**Status:** open, found in WI-0075; the notice path is built, not checked.

### F-0126: The window parts of the import from v1 are not tested automatically

**What:** The manager's choice "Import from v1" (button "Import and export"), its folder dialog, the report window and the two questions of the import (WI-0076) are not covered by an automated test (the window module is gui tier, which agents run only on request). The e2e tests drive the same chain through `cmd.test.op`.
**Status:** not checked; the owner's manual check 1 (`doc/MANUAL-CHECKS.md`, part B) covers them.

### F-0127: The v1 autostart shortcut is recognised by rule, not by the installed v1

**What:** A v1 shortcut counts as v1 when its target is named `AutoHotFlow.exe` or `AutoHotFlow.ahk`, lies in the imported folder or in a folder with the v1 layout (`Saved Flows` or `Variables`), and is not the running v2 product. An installed v1 whose install folder is neither the imported folder nor has that layout is kept, not removed.
**Status:** assumed: the portable layout is what the rule is made for; the installed case is not checked by hand.

### F-0135: A second start without elevation cannot reach an elevated session

**What:** A second start without elevation cannot reach a running elevated session (WI-0079): the instance mutex of the elevated process is not accessible (access denied), the start ends with exit 1 and a log line about higher rights; the pipe DACL (`PipeListener.SDDL`: system and owner) was not checked for a not elevated client. The second start from the Explorer shows no window and no message to the user
**Status:** open, found in the design, not run for real (UAC is a manual check, MANUAL-CHECKS 7 step 14); possible fix: a mutex and a pipe that a not elevated process of the user may open

### F-0136: The shortcut of Start with Windows has the icon of the interpreter

**What:** The shortcut of Start with Windows has the icon of the interpreter (no own icon file exists in `assets/`), and the working directory is the folder of the script
**Status:** open, minor, WI-0079

### F-0137: A denied second start is silent without a console

**What:** The second start that is denied by an elevated session (F-0135) is silent when it has no console (double click, the shortcut): no window, no notice. A MsgBox is not allowed in the supervisor (no dialog rule), so a tray notice of the elevated session cannot be sent either (it cannot be reached). Possible follow-up: a small message from the failing start through a mechanism outside the supervisor role
**Status:** open, WI-0079 review

### F-0138: UAC over the shoulder and the working directory of the elevated start are not checked

**What:** UAC over the shoulder (the administrator account differs from the user) and the working directory of the elevated start are not checked: the elevated process may see another `A_AppData` and `A_Startup`, so the default data folder and the shortcut may differ from the user's. `Run` passes `A_WorkingDir`, relative paths are not tested for real
**Status:** open, not checked, manual check 7 step 11

### F-0141: The storage and import commands of S0004 have no test that sends them directly

**What:** `cmd.storage.ahf.pack/unpack`, `cmd.storage.startup.sync`, `cmd.storage.v1.list/read`, `cmd.import.scan` and `cmd.import.v1.vars` have no test that sends them directly (error answers of bad payloads are not tested); they run only through the manager chain and the supervisor.
**Status:** open, low, found in WI-0082

### F-0114: Load warnings in the trigger host and in `Trigger_Start_up`

**What:** (F-0113 is merged here: the same warning for a local `type` in `Trigger_Start_up.Enable`, seen on stdout of every test that loads the element classes, line 46 of `src/elements/Default/Triggers/Trigger_Start_up.ahk`, outside WI-0066, not a failure.) A local `message` (`TriggerHost._CmdArm`, `ReportCallbackError`) and a local `type` (`Trigger_Start_up.Enable`) are reported as the same name as a global variable on every start of the trigger host (seen in the engine and triggerhost logs, WI-0064). It is the same trap as in `doc/howto/gui-and-hotkeys.md` (case-insensitive names).
**Status:** observed, not checked whether it changes behaviour. A rename of the locals removes the warnings.

### F-0073: Stress test with 200 big flows: a snapshot answer during the load takes 2.3 s (budget 1 s)

**What:** `tests/stress/test_big_flows.py::test_many_big_flows_load_without_hung_and_with_a_responsive_engine[200]` failed in the stress run of the S0001 acceptance (WI-0043). Everything else in the test held (all 200 flows loaded, no `hung`, `crashed` or `restarted`, no storage error, no snapshot timeout); only the latency check failed: `n=251 median=148.45 p95=543.45 p99=1351.00 max=2325.93` ms against the budget of 1000 ms (`SNAPSHOT_BUDGET_S`, serial run, no scaling). The time until `evt.engine.ready` was 59.35 s.
**Status:** measured in WI-0046 (`doc/MEASUREMENTS.md` MS-0030), open. On a machine with the normal load the budget held in 3 of 4 runs of the plain case (3 runs with hooks and one unhooked run through `run_suite.py`: ready after 52 to 55 s, largest snapshot answer 576, 588 and 668 ms); one run broke it (1511 ms, not explained). Scheduled in S0002 (decision of the project owner, 2026-10-14): S0002 registers classes and so lets the conversion at load grow; WI-0045, WI-0047 and WI-0052 to WI-0056 run this stress test at their end and stop if the budget is broken (`work_items/phase3/README.md`, S0002, "Load path of the engine").
**Evidence:** stress run on the code of WI-0036 to WI-0042 plus the WI-0043 test (commit of the test `1783e67`); 14 other stress tests passed. Earlier measurement of the same test (MEASUREMENTS MS-0019, WI-0024, before phase 3): ready after 45.3 s, largest snapshot answer 506 ms (p99 495 ms, median 194 ms, n=199). So the median is about the same, the tail and the time to ready are worse (+14 s, max about 4.6 times).
**Cause (WI-0046, verified by hooks in the engine, 3 runs per variant):** the conversion is not the cause. With the product classes it costs 0.65 ms per flow (0.13 s of 54 s; 14,925 elements wait for their class). In the worst case after S0002 and S0008 (a stub for every class of the 8 flows, every parameter an expression) it costs 21 to 24 ms per flow on average, 4.3 s in total (about 8 % of the load time), 69 ms at most for one flow; time to ready and the largest snapshot answer stay the same within the spread (53.4 s, 555 to 791 ms). The variable phase is 1.9 s in total (answer handlers 40 ms). The load time is dominated by two parses of the same text: `Message.Parse` of the frame in the engine (about 160 ms per flow, about 32 s of the 52 s, assumed from MS-0020 and the difference to the handler time) and `FlowDefinition.FromText` (91 to 98 ms per flow, 19 s). They run with `LOAD_PARALLEL` = 2, so a ping waits behind up to two answers of about 160 + 100 to 300 ms each; the observed maxima of 0.56 to 0.79 s fit that, the 1.5 s run and the 2.3 s of the S0001 acceptance do not (assumed: load of the machine, not checked). Compared to MS-0019 (45.3 s, 506 ms) the time to ready is 15 to 20 % longer, the maximum about 1.2 times; the cause of this difference is not investigated (S0001 changed the loader and the evaluator; not checked).
**Decision (owner, 2026-10-15, E0042):** the budget is raised to 3 s; the finding stays open as an optimization after the port. The tail is a latency during the start, not a product requirement. Candidate: a conservative pre-filter for "has an enabled trigger" (`"enabled": "1"`, any doubt means parse) run by storage on the raw file text, so inactive flows are parsed on first use only. That saves both parses (frame and `FromText`) for inactive flows. Not checked: where the name for the snapshot would come from without a parse; whether files written by v2 use `true` instead of `"1"`.
**Options if the budget breaks again (for the project owner, none needed for the conversion):** the conversion needs no change (stagger, convert on first use and save converted flows would save at most 4.3 s of 53 s). What would help: a parse of the frame that does not escape the flow text twice (the flow text travels inside a JSON frame), reading flows lazily (the engine is ready before all 200 flows are parsed), or `LOAD_PARALLEL` = 1.
**Merged 2026-10-16:** F-0020 ("Flow file parsed twice in the engine", WI-0024: about 0.23 s per flow, 45 s for 200 flows) has the same cause and is closed in favour of this entry. Its alternatives: send the flow as an object instead of a text inside the frame, chunking, or a native parser.

### F-0111: the worker busy test sees an extra `sys.busy false` at the start

**What:** `test_worker_reports_busy_when_a_job_begins_and_ends` expects the `sys.busy` values `[True, False]` of one job. It got `[False, True, False]`: a `false` came before the job, most likely the idle report of the worker that started with the fixture, which arrived inside the one-second window of the test.
**Status:** observed once in the fast tier (run 20261016-225151-4328); not reproduced in the next run of the file alone (not repeated on purpose). The worker role was not changed by WI-0063; whether the test or the report is wrong is not checked.
**Action:** watch the history of the test; if it recurs, decide whether the test must skip the idle report or the worker must not send it at start.
**Evidence:** run 20261016-225151-4328 (fast tier, `python -m pytest tests -q`).

### F-0118: The question for an unknown state recognises the refusal by its text

**What:** The question "write the state of this session to the file?" (E0063, `ManagerOps._AfterSwitch`) is asked when the answer of the engine is `ok: false` with the text "cannot be read (". The engine gives this refusal no error code, so the text is the only mark. A change of the text in `Engine.ahk` would silently remove the question.
**Status:** open, assumed (the test `test_a_switch_refused_for_an_unknown_state_*` in `tests/e2e/test_manager_flows.py` would fail on such a change, but it was not checked against a changed text). Robust option (review, decision needed): `code: state_unknown` in the two refusal replies of `src/engine/Engine.ahk` (`_SwitchOrRead`, `_ReplyRefused`) and documented in PROTOCOL 4.2; the manager then checks the code instead of the text.
**Evidence:** `src/engine/Engine.ahk` (`_ReplyRefused`, `_SwitchOrRead`), `tests/e2e/test_manager_flows.py`.

### F-0119: A multi-selection of flows is not visible in the tree

**What:** The Ctrl click adds flows to the selection that the operations act on (`ManagerModel.selectedSet`). The Windows tree highlights only the focused item, and nothing else marks the other flows of the selection.
**Status:** open, verified in code (no mark is drawn), not checked on screen. Action: the owner decides on a mark (for example a prefix in the text of the item), or a note in the status line with the count.
**Evidence:** `src/manager/ManagerWindow.ahk` (`_OnTreeSelect`), `src/manager/ManagerModel.ahk` (`SelectToggle`).

### F-0121: The tree label of a running flow has no automated test

**What:** The state text of a tree item ("running", "enabled", ...) is built in `ManagerWindow._FlowLabel`. No test reads the text of a tree item: the headless tests read the model, and the gui tests check the structure of the tree only (the item text read with `TVM_GETITEMW` returned 0 in one gui run and the helper was removed).
**Status:** open, verified in code, not checked on screen. Action: a headless check of `_FlowLabel` with a record, or a gui test that reads the item text once `TVM_GETITEMW` is understood.
**Evidence:** `src/manager/ManagerWindow.ahk` (`_FlowLabel`), `tests/fault/test_manager_window.py`.

### F-0122: A multi-selection was lost on a later rebuild of the tree (fixed, no automated test)

**What:** A late `ItemSelect` event of a rebuilt tree called `ManagerModel.Select` and cleared the multi-selection. The fix in `ManagerWindow._OnTreeSelect` skips the event when the focused flow is already the model's selection. The rebuild path is only reachable through a real tree, so no headless test covers the fix.
**Status:** open, verified in code, not checked on screen. Action: a gui test that selects two flows and then creates a category.
**Evidence:** `src/manager/ManagerWindow.ahk` (`_OnTreeSelect`).

### F-0139: The log and notice windows follow a language change without a test (open)

**What:** `LogWindow.Relabel` and `NoticeWindow.Relabel` set the column titles and the drop-down lists again (ManagerWindow.Refresh). No test reads their texts: the headless tests have no window, the gui test covers the settings dialog and the about window only.
**Status:** open, verified in code, not checked on screen. Action: step 50 of MANUAL-CHECKS section 8 by the owner; a gui test later.
**Evidence:** `src/manager/LogWindow.ahk`, `src/manager/NoticeWindow.ahk`, `src/manager/ManagerWindow.ahk` (`Refresh`).

### F-0145: MIGRATION entries from phase 1 still say "planned"

**What:** M-0001 (restart of the engine), M-0002 (dialogs in a worker), M-0004 (errors of elements as exceptions), M-0005 (`storage` is the only log writer), M-0010 (two-phase exit), M-0012 (deadline 2 s for policy `stop`), M-0013 (dangling connections reported) and M-0014 (empty loop stack) have the status `planned` in `doc/MIGRATION.md`. Most of them are built (read: `LoopStack.Pop` throws `AhfError` on an empty stack, `Instance.StopDeadlineMs` is 2000, `LogSink` in storage writes the log), but each needs its test named, as the newer entries have.
**Status:** open, not checked entry by entry. Action: for each entry find the test, then set the status `implemented (WI-..., test ...)` or correct the text. Rule 6 of AGENTS.md: no status without a read or a test.

### F-0146: README.md of the repository is the README of v1

**What:** `README.md` in the root describes v1: the download of the installer, the screenshots in `Documentation/`, `find modules.ahk`. On the branch `v2-port` it is wrong for a visitor.
**Status:** open, low. Write the v2 README at the end of the port (S0009 distribution); until then `AGENTS.md` and `doc/README.md` are the entry points.

### F-0147: GDI+ object leaks are not tested

**What:** the unit test `tests/ahk/gdip.test.ahk` checks that 1000 frames leave the GDI object count of the process unchanged. GDI+ brushes, pens, fonts, paths and images are objects of the GDI+ library, not GDI handles, so a missing `GdipDelete*` stays invisible.
**Status:** open, verified by reading the wrapper (every object has its delete). Option: compare the private bytes of the process over many frames, or count the objects the wrapper creates and deletes.

### F-0148: run-state record of a deleted flow may be re-created

**What:** `StopFlow` is asynchronous. A thread that ends after `ForgetFlow` (flow deleted) calls `_ElementStopped`, which creates a record through `_Elem` again. The record is small, but a stale `finished` event may reach an editor.
**Status:** open, assumed harmless (the storage round trip of a delete comes first), not reproduced. Fix: ignore `_ElementStopped` for a flow that is no longer known.

### F-0149: editor open: tests depend on timing, gaps, a short race

**What:** see the table row. The placeholder editor ends with exit 3 after about 200 ms; the supervisor judges it at its next 200 ms tick.
**Status:** closed in WI-0088 (commit 9832583f, tests in `tests/e2e/test_manager_editor.py`): the editor is long-lived, so the two tests are deterministic; a dead editor frees its slot once judged; a request for an ended but not yet judged editor is answered `busy`; flow IDs a command line cannot carry are `bad_payload`.

### F-0150: A state change costs more in SceneBuilder.Build than in the frame

**What:** `SceneBuilder.Build` takes about 18 ms for 300 elements (MS-0046), more than the frame of a state change (6 ms). The window builds a new scene at every state change, so a state change costs about 25 ms before it is on the screen.
**Status:** addressed in WI-0088 (commit 7077e5b1): `Scene.WithStates` copies only the changed elements and connections on a state change. Not measured again (not checked).

### F-0152: The word "break" of the loop break field is a literal

**What:** the renderer draws the literal "break" in the break field of a loop, not a language text.
**Status:** open, low (WI-0085).

### F-0153: The tint of a running element lies over a later element

**What:** the tint of a running element is drawn after all elements, so where it overlaps a later element of the scene, the tint lies over that element; v1 draws the tint with its element.
**Status:** open, low (WI-0085); the sample flows show no such overlap, not checked on a larger flow.

### F-0154: a range that deletes a file is refused by the selection

**What:** `verify.py --auto`, `select_tests.py --from REF` and `pytest --changed-from` take the changed paths of a range (`--no-renames`), and every path had to match a rule. A deleted file has no rule once it is gone (WI-0088 deleted `src/core/PlaceholderRole.ahk` and its `SOURCE_AREAS` entry), so each such range ended with `not classified by any test rule` and the verdict `error`. A rename's old path behaves the same way.
**Fix:** a deleted path (from `groups.removed_paths`, `--diff-filter=D`) keeps its own rule when it has one (the groups of its area). A deleted path without a rule selects everything, because a deletion can break any test. A path that still exists and has no rule is still an error. Test: `tests/test_groups.py` (three tests, one with a real git repository in a temporary folder). Doc: `doc/TEST-GROUPS.md`, section 1.
**Status:** closed, verified by the tests (fail before, pass after). Not checked: a full `verify.py --auto` run over the WI-0088 range, which now selects everything because that range also touches `tests/support/`.

### F-0155: The restart test after an editor death waited for a started answer that never came

**What:** `test_the_editor_of_a_flow_that_just_died_is_started_again_and_its_slot_is_free` expected a started answer on a later request. Since WI-0088 the supervisor judges an ended editor before it answers a request (`OpenEditor` settles first). If the first request comes after the judgement, it starts the new editor (answer started); every later request is then answered as running (`cmd.editor.show`), so the wait ran into its timeout. Under load the first request came after the judgement in the full fast runs since the WI-0089 integration. Alone it passed, because the request came before the judgement.
**Status:** closed (test only; the supervisor behaves as designed): the test is parametrized ("at-once", "judged-first" with a 1 s pause) and keeps sending requests until a new editor runs. The old assertion fails in the judged-first case every time (checked). Verified: `tests/e2e/test_manager_editor.py` green serially (5 runs of the two new cases), and the e2e directory green under load (98 passed). Not checked: a full fast-tier run with this change.

### F-0156: The size of an element-state batch is not measured for large flows

**What:** the engine sends the element states of a flow in batches: at most one `evt.element.states` per flow and 33 ms (WI-0089, owner decision). The message count is bounded for any flow. The size of a batch grows with the number of elements that change in one interval. Measured in WI-0092 (MS-0050): a flow of 300 elements that all change in one interval gives 2 or 3 batches per start, the largest about 35 KB; the editor's frame latency (change to end of frame) has median 43.8 ms and p95 68.8 ms. The median is above the batch interval plus one frame, and the p95 is above the 50 ms of REQ-PRF-060 (MS-0047 measures a loop of three elements at the guard's limit: hub queue 0, latency p95 46 ms).
**Status:** postponed by the owner on 2026-10-20. Measured: the number is not fine, so the finding stays open; the owner postponed the next step (the batch interval, a faster path for the state change, or the render process of ARCHITECTURE 2.1); the message count is verified by `tests/stress/test_editor_event_load.py`.

### F-0157: The pipe latency test is red under load

**What:** `tests/integration/test_pipe.py::test_abrupt_end_of_client_process_is_seen_within_500_ms[2]` measured 1819 ms (budget 1500 ms) in one run while the machine ran at 99 % CPU. A wall-clock latency assertion that the admission of the test runs does not cover. Not checked alone.
**Status:** open (one red run under load); the owner decides whether it belongs in the idle tier.

### F-0161: Order inside a batch of element states

**What:** the engine sends the element states of a flow in batches of at most 33 ms (WI-0089). Inside one batch the entries are in the order of the first change of each element. A fast repeating failing element shows only its last state in the batch.
**Status:** postponed by the owner on 2026-10-20. A note only; no requirement depends on it.

### F-0167: the v1 general help pages are not in the repository

**What:** `v1/Help/en/` (`Welcome.html`, `Variables.html`, `Key list.html`, `Color chart.html`) is ignored by git (`v1/Help/en/.gitignore`), so the repository never had these four pages. WI-0112 converted them from the owner's working copy into `assets/help/en/` (Markdown). The converter `tools/convert_v1_help.py --general <folder>` needs that folder again. The page on variables was rewritten for v2 and is no longer the v1 text.

**Options:** (a) keep the Markdown as the only copy (now); (b) store the v1 text as a file in `v1/` next to the other reference material, which is removed after the port; (c) nothing: the Markdown is the source from now on.

**Status:** open, found by WI-0112. Decision for the project owner.

### F-0180: The slider of the settings form is fixed to the range 0 to 100

**What:** v1 passes the options of a slider field; the v2 form model (WI-0105) and the window (WI-0106) use the fixed range 0 to 100. No element of the core set has a slider, so no run shows it.
**Status:** open, found by WI-0114 (read in code, not reproduced).

### F-0181: Field types and assistants that no element of the core set uses

**What:** The mouse and colour assistants have no element yet; the window assistant is used by the Hotkey trigger, which is not in the core set (it is in the Default package). The field types Slider, ComboBox, Hotkey, File, Folder, weekdays, DateAndTime and Button are shown by no core element. The test `tests/ahk/editor_form.test.ahk` covers them with the test element `Action_TestForm`.
**Status:** open, for S0008 (the list of the next package). Verified by reading the element files.

### F-0182: The tracker of the mouse assistant is relative to the tracker window

**What:** The window mode of the tracker is relative to the tracker window itself, not to the window the mouse points at (WI-0110). Taken over from the handover of WI-0114.
**Status:** open, assumed; not checked on screen (the owner's gui check of the assistants).

### F-0183: The colour dialog and the pipe are not measured

**What:** How the colour dialog behaves while the pipe is busy (WI-0110) is not measured. Proposal: extend the measurement of E0076.
**Status:** open, not measured; the owner decides on the extension.

### F-0184: The error window shows variable values in clear text

**What:** The window of an unhandled error (WI-0113) shows the variables of the branch with their values in clear text, also a value that a flow stores as a secret.
**Status:** decision needed: the project owner, see NEEDS-ATTENTION.md.

### F-0185: Text fields are not checked as expressions

**What:** A field with the content type String is not expression-checked (WI-0108): a text such as `%name%` or `{` gives no warning, although the element may evaluate it.
**Status:** decision needed: the project owner confirms that a String is no expression.

### F-0186: The WebView2 loader hashes come from one download

**What:** The SHA hashes of the WebView2 loader DLL that the project pins (WI-0115) were taken from one download. A second download from the same source was not compared.
**Status:** open, not checked; to be repeated when the loader is shipped (S0009).

### F-0187: A flow with its own working directory is not run end to end

**What:** `BuiltInVars.WorkingDirOf` is tested as a function (`tests/ahk/vars_model.test.ahk`), the global working directory in a run (`tests/integration/test_settings.py`). A flow whose own folder is set (flow settings, WI-0109) is not run and its `A_WorkingDir` read.
**Status:** open, not checked end to end (WI-0114).

### F-0188: Gaps in the path guards of the file and folder elements

**What:** `FileOps.Guard` (WI-0120, M-0119) does not treat a path with the extended-length prefix and a UNC share root (server and share only) as roots. The empty-path check looks at the raw parameter only: a `%var%` that expands to empty reaches the flow working directory, which only Delete_Folder refuses. Move_Folder and Rename_Folder on the working directory itself are allowed.
**Status:** open, found in the review of WI-0120; read in code, not tested. Fix: check the expanded path and the roots after normalisation.

### F-0175: REQ-USE-080 names the wrong requirement for the switch of the notices

**What:** REQ-USE-080 and PROTOCOL 4.7 name REQ-USE-070 for the per-flow switch of the notices of unhandled errors (`flowSettings.notifyUnhandledErrors`, WI-0109), but REQ-USE-070 is the requirement of hints.
**Options:** (a) correct the reference to the requirement that fits; (b) give the switch its own requirement (a new requirement is a decision of the project owner).
**Status:** decision needed (the owner decides). Verified: the references were read in the documents.

### F-0176: Show log with no running manager starts the manager, and the log window is not filtered to the flow

**What:** the flow settings button "Show log" (WI-0109, PROTOCOL 4.11) asks the supervisor to open the log window of the flow in the manager. When no manager runs, the supervisor starts it and the log window opens without the filter of the flow.
**Status:** open, low priority: the manager normally runs. Verified by reading (the author of WI-0109 and the reviewer); not tested end to end.

### F-0178: The help request of a role that is still starting is not tested end to end

**What:** The supervisor (`Supervisor._OnHelp`) asks the help role with the page that waits for its hello (`_SendHelp`, called from `_OnHelpSent` / `_OnHello`), and the manager and the editors send cmd.help.show. The tests in `tests/fault/test_help_role.py` send as an observer, which the supervisor refuses (`denied`); the sender rule and the role's answers are tested, the path of a real manager or editor and the pending page are not.
**Options:** (a) a test that starts the headless manager and asks it to show a help page (the manager trace, as tests/fault/test_tray_role.py does for the tray); (b) a test entry that lets the observer send as manager.
**Status:** open, not checked.

## Observed only (not for the bug hunter)

Entries that the bug hunter does not take (`doc/ORCHESTRATOR.md` 3c): they were observed once or only under parallel load, were not reproduced when run alone, or are assumed and not checked. Each one has its sign (what to look for in a run) and its action. Hunter-eligible entries stay in the summary table and the findings above.

**Rule (owner, 2026-10-16):** the run history (`python tools/test_history.py --flaky`, `--test <id>`, WI-0059) records every recurrence of a failing test, so an entry here is not needed as a reminder. An entry whose test has passed in several runs since its fix or its observation is closed (moved to `doc/CLOSED-ITEMS.md` with the number of green runs). A recurrence is a new finding that cites the old ID.

- **Patch answers during a run take about 50 ms.** The round trip of `cmd.flow.patch` from a test client while a flow runs (300 sleeps of 20 ms, MS-0052): median 50 ms, p95 65 ms, max 75 ms, against 4.5 to 21 ms of engine time in the bench (MS-0051). The cause is not split (the engine's message handling during timers, the client, or the pipe); an idle engine answers a patch in 6 ms (the biggest v1 flow, test `test_a_patch_of_30_operations_on_the_biggest_flow_is_answered_within_the_budget`). *Sign:* an editor that feels slow while a flow runs. *Status:* not checked.
- **Warning of a local `elements` in `FlowDefinition.ahk` under `#Warn All`.** The benches `tests/ahk/helpers/flow_patch_bench.ahk` print `Warning: This local variable has the same name as a global variable` for `elements` in `FlowDefinition.__New` and `ToFileText` (line 78 and 119). The code is older than WI-0093. *Status:* observed in the bench output, not checked whether the product prints it; a rename of the locals removes it (compare F-0160).
None at the moment.

## Watch list (E0007)

These items were deliberately not fixed in phase 2b. Closed items (F-0004, F-0006, F-0010, F-0015, F-0018 and others) are not listed. The findings above are not repeated here.

- **`deadlineMs` of `sys.shutdown` is not used everywhere.** `Storage.OnShutdown` uses it, and since WI-0041 `Engine.OnShutdown` does for the variable writes (the rest of the deadline is the limit of each request); the instances still stop with a fixed 2 s each. `StubManager.OnShutdown` does not. The hard deadline is enforced by the supervisor, which is enough for now. *Sign:* a role needs more cleanup time than the deadline allows, and the supervisor kills it (for example the engine when many instances stop). *Action:* derive a partial deadline per instance (2 s, see `doc/ARCHITECTURE.md` 6.3) in `Engine.OnShutdown`. *Evidence:* `src/engine/Engine.ahk:76`, `src/manager/StubManager.ahk:99`, `src/storage/Storage.ahk:62` (as cited in `v2-phase2-final:work_items/STATUS.md`).
- **`tests/support/pyhub.py` sends no wake-up.** `PyHub` answers only by polling (fallback timer, latency about 250 ms). Only `tests/support/test_client_hub.py` uses it; all other tests use `WakingHub`. *Sign:* a new time-critical test uses `PyHub` and misses a deadline. *Action:* switch to `WakingHub`, or add the wake-up to `PyHub` (see `doc/ARCHITECTURE.md` 2.2).
- **Idle CPU.** The target is met: 0.23 % of the total system (E0005). The reading "sum in percent of one core" gives 1.8 %, which misses the target; the reading is still open. A possible improvement is to keep the engine's safety timer (`SAFETY_MS = 100`, `src/engine/Engine.ahk:33`) active only while instances run. *Sign:* idle CPU above 1 % in a measurement with an editor (phase 3). *Action:* re-measure with the WI-0016 method after the change.
- **Sporadic dialog test `test_msgbox_is_captured_and_closed`.** One timeout in phase 2 (the ctypes argtypes cause was fixed). In WI-0018 two dialog-watcher tests failed under parallel load. The cause is assumed (reused process IDs in the watcher), fixed in `tools/ahf_dialogwatch.py`, and not reproduced. *Sign:* a test exits with 0 instead of 97, or times out. *Action:* read the dialog report in `%TEMP%\ahf_dialogs\` (the file name contains the test PID since WI-0018).
- **Deadlines of a role after standby (WI-0033).** `Peer.Request` sets each deadline with `SetTimer`. After a standby, all due deadlines of one role fire at once (answer `timeout`, the caller retries). *Status:* not checked; only a freeze of the supervisor was tested (with `psutil`), not a real standby. *Sign:* many `timeout` answers or retries at the same time after wake-up. *Action:* use a deadline list per role, as in `Hub.Tick`/`Hub.Shift`, and measure the stall per role.
- **Empty `--data=` writes to `C:\Log` (E0015).** The owner decided that this is acceptable for now. *Sign:* unexpected files in `C:\Log`, or logs missing from the data folder. *Action:* reject an empty value at start (exit 2 with a message). Not rechecked in WI-0032; the item comes from the review.
- **Factor 3 of `scaled()` (E0017).** The owner decided to keep the factor 3 for parallel runs. Cycle 1 of the WI-0035 acceptance neither confirmed nor refuted it: no run showed that it is needed or too loose. *Sign:* a scaled limit fails in parallel runs. *Action:* observe; the decision (E0017) stays as it is.

## Not checked

- A real second Windows user connecting to the pipe (F-0017 is closed on the DACL test only).
- Standby (see the watch list item on deadlines after standby).
- Screenshots with a locked desktop.
- Real blocking dialog elements in a worker.
- Worker pool in a long run with more than 3 workers.
- AHK client (editor) as the other side of the latency measurement.
- Idle CPU and memory with a warm worker (not measured again).
- Editor memory with 5 open editors, and redraw time (no editor role yet).
- The report of the import from v1 as the user sees it (window, copy of the text, 225 % scaling): manual check 1, part B only (F-0126).

What is built and what is not: `doc/REQUIREMENTS-INDEX.md`.

## Open actions

Work that is open but is not a finding with an entry. Rule: a finished action is deleted from this list, not marked as done; its history is in the git log.

1. **Small test gaps of WI-0048 (verifier, `7007f78`).** (a) `Action_Do_nothing` with `executionResult` set to `Exception` has no test; the result `exception` is new behaviour. (b) `ProductRegistersElements` asserts only `Length >= 3`; a test should compare the registry with the element files of `src/elements/*/` (or check that `tools/gen_element_includes.py --check` covers it, not checked). Do it with the next element work, in one small commit.
2. **Distinct code for "flow not loaded yet".** Right after an engine restart `cmd.flow.start` is answered `not_found` while the flows are still loading (from F-0061, closed). A code such as `not_ready` would be clearer. Not decided; the manager of phase 3 follows the resync rule in PROTOCOL 4.8 meanwhile.

## Open decisions

None here. The decisions waiting for the project owner are in `NEEDS-ATTENTION.md` (repository root).

Decisions on entries are in the summary table (status `decision needed`, `accepted`, `closed`) and in the status book `work_items/phase3/STATUS.md`, section "Decisions of the project owner".

### F-0179: the WebView2 help viewer has a hole in its navigation filter (new-window requests) and keeps its handlers

**What:** the viewer cancels every navigation that is not `file:` and hands http and https links to the default browser (WI-0115). A link with `target=_blank` makes the runtime ask for a new window (`NewWindowRequested`), which the viewer does not handle: the runtime would open its own window, and the filter does not apply to it. No help page has such a link today. Besides, `ComHandler` keeps every handler (about four per mount of the viewer, `CallbackCreate` and buffers) for the whole process; a mount happens on a viewer change or on a failure only.
**Options:** (a) handle `NewWindowRequested`: cancel it and route its URI through the same filter; (b) let a test or the generator refuse `target=_blank` in the help pages; the handler leak is acceptable for a help role that does not run long.
**Status:** open, low priority. Verified by reading (the author of WI-0115 and the reviewer); not tested.

### F-0160: A warning of the renderer bench in a product script

**What:** the renderer bench (`tests/ahk/helpers/renderer_bench.ahk`, `#Warn All`) reports `Warning: This local variable has the same name as a global variable` for `type` in `Trigger_Start_up.ahk` line 47 (function `Enable`). The bench includes the product's element classes; the product itself does not use `#Warn All`.
**Status:** open, low; verified by the bench output, not checked whether the product shows the warning at run time.

### F-0162: The drag of 30 elements is above the frame budget

**What:** WI-0097 asks for a frame during a drag below 16 ms on average (1 and 30 elements, a flow of 300, 1920 × 1080). Measured with `tests/ahk/helpers/renderer_bench.ahk` (MS-0051, 100 frames, one run): 10.6 ms for 1 element (met), 25.0 ms for 30 elements (not met; the draw part is 20.0 ms, `Scene.WithDrag` 5.0 ms). The rebuilds at the start and after the drop are 90 to 107 ms, as for a flow change. The live drawing of the dragged items each frame is the cost; which part (elements or their connection labels) is not checked.
**Options (for the owner):** (a) draw the dragged elements once into a group layer at the start of the drag and copy it per frame, the connections stay live (expected to help the elements part; not measured); (b) accept the 25 ms for large drags (a drag of many elements is rare, the one-element drag is inside the budget); (c) reduce the work of `Scene.WithDrag` (it builds the whole scene again per frame).
**Status:** decision needed (the project owner), measured (MS-0051; again in MS-0056 of WI-0104: 26.9 ms mean for 30 elements, 12.6 ms for one, on a machine with other load). Not checked: the real window and the feel of the drag on the owner's machine.

### F-0171: Real mouse and real keys of the editing actions have no gui test

**What:** the gui tests of the editor send real input for the wheel, the drag of the view, the menus and the right click (`tests/fault/test_editor_mouse_gui.py`, `tests/fault/test_editor_menus_gui.py`). Select, rectangle, move, connect, add by a click on the field, delete and the keys Ctrl+Z, Ctrl+Y, Ctrl+S are tested headless only (through the window's handlers and `cmd.test.*`). The requirements REQ-EDT-050, 060, 070 and 080 stay `partial` for that reason.
**Options:** (a) write the gui test of the editing gestures as the menus test is written (the owner runs it); (b) the owner's manual check 10 (steps 1 to 16) is the acceptance and no gui test is added.
**Status:** open. Not checked: the feel of the gestures on the owner's screen (manual check 10).

### F-0172: The editor texts of ko and ru are missing

**What:** `assets/language/basic/ko.ini` and `ru.ini` hold about 80 keys each; the editor texts (`Editor_menu`, `Editor_view`, the "Create new ..." titles) are only in `en` and `de`. The language table falls back to English for a missing key (`LangTable.Fallback`), so the texts show in English.
**Status:** open, low. Translation is the owner's or a later step (S0009 for the help; the editor texts can follow the same way). Not checked: the look of the English texts in the Korean window.

### F-0173: F-0158 (language files read as UTF-16) is not reproduced

**What:** F-0158 says that `basic/de.ini`, `ko.ini` and `ru.ini` are UTF-16 but read as UTF-8. On 2026-10-21 the files `assets/language/basic/*.ini` and `assets/language/manager/*.ini` were checked by their bytes: none contains a NUL byte, and `LangTable._Read` reads them as UTF-8 (`FileRead(path, "UTF-8")`). The finding therefore does not match the files of this branch; the status book names commit `60b41ad0` ("F-0158") as the fix, which fits this.
**Status:** open, to be confirmed or closed by the owner (the finding is named in `work_items/phase3/WI-0092-result-s5.md`, not in this document; its text is not changed here). Verified (bytes read).

### F-0165: A plain request through the hub takes about 120 ms in the test client

**What:** while the patch round trip of the editor was measured (MS-0055), a plain `cmd.test.state` request from the test client to the editor took a median of about 120 ms, a patch about 130 ms, and a `cmd.flow.get` to the engine about 125 ms. MS-0054 measured 50 ms for a patch under stress. So the time sits in the path that every request takes (the client, the supervisor's hub or the send path), not in the patch code. Not checked where it goes.
**Options:** (a) find the cause with timestamps along the path (the client's read loop, the hub, the send queue of a connection); (b) accept it and measure the editor's frames only (REQ-PRF-060 counts the editor's own latency).
**Status:** open, not checked. Measured by MS-0055 (one run each, the machine shared with other agents' runs). The owner's machine is not checked.

### F-0166: A refused view patch clears the undo stacks, and the live zoom jumps back on a foreign definition

**What:** the review of WI-0096 found two behaviours of the editor draft. (1) A refused or lost patch that only carries the view (zoom, offset) goes through the same path as a content patch and clears the undo stacks, so the user loses the undo because of a zoom. (2) `EditorModel._OnDefinition` sets the view from the flow settings of every definition, also from an `evt.flow.committed` of someone else, so an unsaved zoom jumps back.
**Options:** (a) let view patches skip the clearing of the stacks, and keep the live view once the first definition has arrived; (b) accept it until the automatic saving (WI-0095) makes view patches rare.
**Status:** partly fixed in WI-0098 (not closed). (2) is fixed and tested: the view is read from the first definition only (`EditorModel._OnDefinition`; `tests/e2e/test_editor_select.py::test_a_wheel_zoom_survives_a_change_of_the_flow_by_someone_else`). (1) is changed in code (`EditorDraft._Refuse` and `_Lost` keep the undo steps when only a view patch was dropped) but not tested yet.

### F-0168: The cold-start timing test of the worker is flaky (not caused by WI-0101)

**What:** `tests/fault/test_worker_lifecycle.py::test_time_to_the_first_job_when_the_worker_has_to_be_started_cold` fails now and then: the worker element never reports its `running` state event (`started` is empty). Seen on the base commit `f58bb0b2` (1 of 3 serial runs, run_suite) and on the WI-0101 commit (2 of 3 serial runs); the same run in the fast tier failed too. The editor is not involved in the test.
**Options:** (a) find out where the `running` event of a cold worker is lost (the test's event filter or the engine's event order); (b) mark the test as timing-sensitive and run it in the idle tier.
**Status:** open, verified (repeated runs at both commits), cause not checked.

### F-0169: A wheel over the settings window also zooms the canvas beneath it

**What:** EditorWindow._OnWheel takes every WM_MOUSEWHEEL whose pointer lies over the canvas, whichever window received it (WI-0090, by design). The settings window of an element (WI-0106) is an owned window over the canvas and has its own wheel handler for its scroll area. A wheel notch over the settings window therefore scrolls the settings and also zooms the flow under it.
**Options:** (a) the editor window ignores wheel messages whose target window is not its own while a settings window is open; (b) accept it until the owner's gui check of the settings window shows whether it matters.
**Status:** fixed in WI-0106 (EditorWindow `_OnWheel` returns when the pointer is over the settings window, `ElementSettingsWindow.Owns`); verified by reading the code only, not checked in a real window.

### F-0192: A blocked input may stay blocked when its worker is killed

**What:** `Action_Block_User_Input` blocks the input in the worker process and keeps it blocked after the element has finished (as v1). The worker releases the block when it shuts down in an orderly way (`SystemOps.ReleaseInput`, WI-0126, M-0156, tested with the provider). A worker that is killed after the deadline of its shutdown releases nothing. Not checked: whether AutoHotkey or Windows release a block of a process that has ended.
**Status:** open, not checked on the real desktop. Next step (owner's manual check): a flow blocks the input and then hangs (or the worker is killed), and the keyboard and the mouse are used afterwards. Fallback if the block stays: the warning of the help page (already there, "not checked"); a release from another process is assumed not to be possible.

### F-0194: The element list of another flow is kept while the settings window is open

**What:** WI-0129 (`Action_Set_element_parameter`) asks the engine for the elements of another flow (`cmd.flow.elements`) and keeps the answer until the next opening of a settings window (`EditorFlowCatalog.Refresh`). Like the trigger lists (WI-0107), the lists do not follow a change of that flow that another editor makes while this window is open.
**Status:** open, found by WI-0129 (read, not run). Next step: refresh the element lists on `evt.flow.committed` of the other flow, as the flow list follows `evt.flow.list.changed`.

### F-0193: Imported v1 AutoHotkey scripts are not marked and not held back

**What:** WI-0130 builds the script action and trigger for v2 code (M-0049 says an imported v1 script ends with an exception until it is ported). The loader does not write the mark yet (no `migration` entry with `M-0049` for the script parameter, and the element does not check for it), so a v1 script runs as v2 code: a v1 line like `sleep, 10000` is an exception of the interpreter, but code that v2 accepts runs.
**Status:** open. Next step: a V1Syntax kind for the script text in the converter that marks it with M-0049, and the element check that ends with the text "port it to v2" while the mark is there.

### F-0191: Tests of the worker and the force question fail under load

**What:** `test_worker.py` (not busy after a cancel, busy when a job begins and ends, shutdown with a job and a late hub), `test_editor_tray.py` and `test_editor_flow_ctx.py` (the force question of an unreadable state) and `test_worker_lifecycle.py` (cold start) were red in full runs several times and green alone in `recheck.py` each time (with up to three agents running tests at once).
**Status:** open, observed only under load. Next step: a hunter round on the tolerance of these tests (timing, ordering), not on the product.

### F-0190: Blocking waits of the sound elements have no deadline

**What:** `SystemOps.Real.SpeechWait` loops with `Sleep(50)` and no limit or stop check. A synchronous speech, `SoundPlay` with wait and `SoundBeep` with a very long duration block the worker in one call. The worker answers a cancel only when the job yields; otherwise the job deadline and the kill of the supervisor apply. The upper bound 32767 of the beep frequency has no test.
**Status:** open, found in the review of WI-0124; read in code, real behaviour not checked. Fix: cap the wait loop, clamp the duration, test the upper bound.

### F-0189: The settings window draws every slider from 0 to 100

**What:** a `Slider` field of an element takes its range from the parameter's options in v1 (`options: "Range-10-10 TickInterval1"`). In v2 the settings window (`src/editor/ElementSettingsWindow.ahk`, `AddSlider("Range0-100")`) draws every slider from 0 to 100 and ignores the range. The sound elements of WI-0124 avoid the problem: relative volume, speed and pitch are number fields (M-0132). Another element with a negative or a larger range would show the wrong range.
**Options:** (a) the window reads the range of the field (a `range` key in the description, or the `options` text of v1) and draws it; (b) keep number fields for every range that is not 0 to 100.
**Status:** open, low. Found in WI-0124; the fix belongs to the editor (E0076 settings window). Not checked: how the window looks with a negative range (no window test runs here).

### F-0195: Window scope and registration code of the two hotkey-like triggers

**What:** `Trigger_Hotkey` and `Trigger_Hotstring` (WI-0131) hold the same window-condition and registration code. The rule for shared code says it goes into `lib/` of the package.
**Options:** (a) move it to `src/elements/Default/lib/` in a later change with its own tests; (b) keep both copies.
**Status:** open. Not changed in WI-0131 to keep the verified hotkey element untouched.

### F-0196: Typo in the language key of the hotstring option

**What:** the key "Omit the ending character after replacemenet" (v1 text) has a typo, kept as the key so that the translation lookup works.
**Options:** (a) correct the key in en.ini, de.ini (ko and ru in S0009); the key changes everywhere it is used.
**Status:** open, not checked in the product view.

### F-0199: The DDC question of the screen settings (decision needed)

**What:** WI-0127 names "monitors, resolution, colour depth, frequency, orientation" for the screen elements. v1 `Action_Get_Screen_Settings` and `Action_Set_Screen_Settings` only read and set the DDC/CI settings of a monitor (brightness, contrast, gains, drives, colour temperature, `Class_Monitor` on dxva2). Resolution, colour depth, frequency and orientation are not in v1. The v2 seam function `ChangeDisplaySettings` was reserved for them and is replaced by the monitor functions (commit 43d35956).
**Options:** (a) keep the DDC settings only (as built, E0035: v1 is the reference); (b) add a DEVMODE function to the seam for the four values (new elements or new parameters, MIGRATION if v1 flows change).
**Status:** decision needed (owner). The DDC reads were probed on the development machine (verified: brightness 70, contrast 75, gains 50 on one monitor); the writes are not run on a real monitor.

### F-0200: Per-monitor DPI awareness only in the screen elements

**What:** `ScreenOps.EnterPhysical()` sets per-monitor DPI awareness for the screen elements (pixel, image, screenshot). Click, Move mouse, Drag with mouse and the mouse tracker of the editor do not, so on a monitor whose scale is above 100 % the two kinds of coordinates may not agree.
**Options:** (a) the same call in the mouse elements; (b) the editor's mouse tracker reads the same coordinates as the worker.
**Status:** not checked (one scale on the development machine). Found in WI-0127.

### F-0201: The xdist INTERNALERROR of the selected run

**What:** `python -m pytest tests -q --changed-from v2-port` aborts with an INTERNALERROR: the xdist worker that runs `tests/test_ahk_runner.py::test_ahk_file_completes[json.test.ahk]` dies, so the run reports no tests. Reproduced in three runs of WI-0127 (`--deselect` of that id did not help); the test passes alone (`-n 0`, 81 passed).
**Status:** open, not reproduced: the verification run 20261102-123314-825e716a (2076 selected tests on the branch) had no INTERNALERROR and `test_ahk_file_completes[json.test.ahk]` was green; probably load or file locking of parallel runs. Use `tools/verify.py` for selected runs.

### F-0202: Manual checks of the screen elements are open

**What:** the search and screenshot elements are tested on an own window at one scale. The real desktop with several monitors and scales is not checked; the Search pixel mouse tracker sets the upper left corner only.
**Status:** open, not checked. Next step: the owner's check of Search pixel, Search image and Screenshot on the real desktop.

### F-0203: The process triggers cost CPU in proportion to the ticks

- **Found:** WI-0132 (measured, MS-0044, run 20261102-115353-6700): ten `Trigger_Process_starts` at 100 ms take 8.65 % of one core in the trigger host (baseline 0.83 %, ten window triggers 2.29 %). The test timer kept its schedule in every variant (median 109 ms, max 110 ms).
- **Open:** the owner decides the default interval (1000 ms now) and whether the base name of a process is cached per process ID. A cache must check that the ID is still the same process (PID reuse), for example with the creation time.
- **Status:** verified (one run, one machine, the machine was not idle); the 1000 ms cost is assumed.

### F-0204: Protected processes are not seen by the process triggers

- **Found:** WI-0132 (read, `src/elements/Default/lib/ProcessSnapshot.ahk`): the process list opens every process with `PROCESS_QUERY_LIMITED_INFORMATION` and does not enable the debug privilege, which v1 did. A process that cannot be opened is not in the list.
- **Open:** whether the process triggers must see such processes; the elevated start of AutoHotFlow would be needed. Recorded in MIGRATION M-0176.
- **Status:** verified (read); not checked on a protected process (no such process was used in a test).

### F-0205: Own-window and own-process helpers exist twice

- **Found:** WI-0132 (read): `tests/integration/test_window_elements.py` (WI-0125) and `tests/integration/test_process_elements.py` (WI-0123) keep their own helpers; `tests/support/ownwindow.py` and `tests/support/ownprocess.py` are the copies of WI-0132 (the same kind of helper, simpler).
- **Open:** move the helpers into `tests/support/` and let the tests import them, one change at a time.
- **Status:** verified (read).

### F-0206: The option label of Process starts says "window"

- **Found:** WI-0132 (read, `src/elements/Default/Triggers/Trigger_Process_starts.ahk`): the v1 label of NotTriggerOnEnable reads "Do not trigger if a matching window exists when enabling the trigger". The v1 help text describes a process.
- **Open:** a language key with "process" in en.ini and de.ini, decided by the owner. The help page explains the label until then.
- **Status:** verified (read).

### F-9000*: The shortcut file comes after the answer of the enable

- **Found:** WI-0133 author (corpus "File link test", run 20261102-155032-13536): the flow enables its Shortcut trigger and runs the shortcut at once; the trigger host answers the arming before storage has written the file, so `Run` fails with "Can't run ...lnk".
- **Open:** the arming could wait for storage (the answer of cmd.flow.enable would then wait too), or the shortcut could be written at the save of the flow. The corpus copy waits 2 s instead.
- **Status:** open, the design decision is the owner's (a flow that runs the shortcut right after enabling it is rare).

### F-9001*: The debug command on a first start is ignored

- **Found:** WI-0133 author (code reading, `src/supervisor/Supervisor.ahk` `Start()`): `--command=debug` works only for a second start; a first start with it starts the normal roles.
- **Open:** let a first start with `debug` open the debug window like a second start (or drop the option).
- **Status:** not checked on the desktop; no test.
