# WI-0092 Result: acceptance of S0005 (agent part, 2026-10-20)

Code state of the runs: commit `cc86de86` (documents and tests of this item; the code of S0005 is the state of WI-0091 integrated on `v2-port`, not changed here). Commits of this item: `85bdc747` (tests, tools, tasks, renderer bench window series, batch test), `cc86de86` (documents: requirements, measurements MS-0048 to MS-0050, manual check 9, findings, ARCHITECTURE, HOW-TO). Status words: verified (read or run, number in the source), assumed, not checked.

## 1. The acceptance of S0005, point by point

| # | Criterion (README "Acceptance S0005") | Evidence | Status |
|---|---|---|---|
| 1 | R0002: a frame of 300 elements and about 350 connections below 16 ms on average at 1920 × 1080 with the whole flow visible; 3840 × 2160 and zoom 1 measured | MS-0048 (headless, real renderer, `renderer_bench.ahk`): 1920 × 1080 whole 6.70 ms mean (p95 7.26), zoom 1 4.62 ms; 3840 × 2160 whole 14.51 ms mean (p95 17.89, max 29.0), zoom 1 10.89 ms. Window variant: owner (manual check 9, part E) | **met on average, headless**; the 4K whole case has a small margin (p95 above 16 ms). The window variant is open (owner) |
| 2 | REQ-PRF-060: a state change of the engine is drawn by a non-blocked editor within 50 ms | MS-0047 (loop at the guard's limit, WI-0089): median 34 ms, p95 46 ms, editor answers at once. MS-0050 (this item): a flow of 300 elements that all change in one interval: median 43.8 ms, **p95 68.8 ms** | **not met for the 300-element case** (p95 above 50 ms). F-0156 stays open; the owner decides the next step |
| 3 | Memory with 5 open editors measured (Default package and 150 synthetic classes, MS-0033); editors outside the budget (E0040); background processes do not grow with editors open | MS-0049 (`tools/measure_editors.py`, 3 runs per variant): five headless editors 52.8 MB (Default) and 113.8 MB (150 classes); background 58.6 MB before, 58.9 MB with the editors; equal within 0.3 MB 20 s later; processes unchanged | **met (verified, headless)**. Window cost of an editor not measured (owner) |
| 4 | An editor that hangs or is killed harms no other editor and no running flow; after an engine restart every open editor shows the current state (REQ-ROB-040, REQ-EDT-010) | e2e: `tests/e2e/test_editor.py::test_killed_editor_is_not_restarted_and_the_flow_and_the_other_editor_go_on`, `::test_two_editors_of_two_flows_run_at_once`, `::test_killed_engine_restarts_and_the_editor_shows_the_state_again`; the editor menu held 8 s is not "hung": `tests/fault/test_editor_tray_icon_gui.py` (gui, not run by agents, its case is in the test name and asserted) | **met (verified, headless)**; the window part by the owner (manual check 9, parts A and D) |
| 5 | Every e2e test of the editor runs headless in the normal tiers; windows by gui tests of the owner and the manual check | `tests/e2e/test_editor*.py` (headless); gui: `tests/fault/test_editor_window.py`, `test_editor_tray_icon_gui.py`, `test_editor_mouse_gui.py` (new: real wheel and drag with SendInput, status bar layout on the shown window; written, not run) | **met** for the headless part; the gui part is the owner's run |
| 6 | The owner's imported v1 flows open and look right; the owner accepted the look (E0088); tray icon and menu, zoom, moving and tooltip at 100 % and 225 % (manual check) | Manual check 9 (new, `doc/MANUAL-CHECKS.md`, parts A to E, 25 steps, VS Code task "Start: manual check 9 ..."). Screenshots of the look: VS Code task "Tool: editor screenshots of two example flows" (PNG in `temp/editor-screenshots`; the tool ran headless in this item) | **open: the owner's check.** The look is accepted only when the owner writes it into step 3 |
| 7 | Serial, parallel, `-m stress`, foundation and slow runs are green | section 3 | **met with one known load flake**: the serial run has one red test (cold worker start, green alone); the others are green |

**Requirements of S0005 (AGENTS rule 12):** `v2`, `Plan` and `Evidence` updated for REQ-EDT-010, 020, 030, 040, 110, 230, REQ-ROB-040, REQ-PRF-060 and REQ-USE-090. Only REQ-ROB-040 is `done` (headless evidence: the engine restart test); every other S0005 requirement stays `partial` until the owner closes the manual check 9 (look, zoom, tray, scaling). REQ-EDT-150 and REQ-VAR-100 were `done` before (WI-0089) and are unchanged. REQ-PRF-060 is `partial` (F-0156).

## 2. Measurements (task 2 and 3, MS-0048 to MS-0050)

- **Frame (MS-0048):** see criterion 1. The frame of a state change with `Scene.WithStates` is 4.6 ms; `SceneBuilder.Build` costs about 21 ms and is not on the state path any more (F-0150 closed earlier).
- **Rebuild of the static layer:** 113 ms at 1920 × 1080, 182 ms at 3840 × 2160 (F-0151, accepted by the owner).
- **Latency and batch (MS-0050):** criterion 2. The batch of 300 entries is about 35 KB at most per batch, two or three batches per start, no element lost.
- **Memory (MS-0049):** criterion 3.
- **Difference to MS-0046:** the 4K whole frame measured 14.5 ms now against 11.8 ms in MS-0046 (same case, same code). The cause is not known (assumed: machine load, not recorded).

## 3. Runs

| Run | Commit | Result |
|---|---|---|
| fast, parallel (`verify.py --tiers fast`) | `cc86de86`, run 20261020-200811-cc86de86 | 1785 passed, 1 skipped (5:28) |
| foundation (`verify.py`) | `cc86de86`, run 20261020-200811-cc86de86-2 | 471 passed, 1 skipped (4:41) |
| slow (`verify.py`) | `cc86de86`, run 20261020-200811-cc86de86-3 | 204 passed (8:32) |
| `verify.py` VERDICT | `cc86de86` | green |
| fast, serial (`python -m pytest tests -q -n 0`) | `cc86de86` | 1784 passed, 1 skipped, 689 deselected, **1 failed**: `tests/fault/test_worker_lifecycle.py::test_time_to_the_first_job_when_the_worker_has_to_be_started_cold` (the owner's list of load-sensitive tests; `1 passed` when run alone at the same commit). Not chased (task 8 of the owner's rule (g)) |
| stress (`run_suite.py --ref cc86de86 -- -m stress`) | run 20261020-203757-cc86de86 | 33 passed, 2442 deselected (10:55); includes the batch test (MS-0050) |

Gui tests were not run (no `gui` marker in any run). The memory measurement (MS-0049) and the renderer bench (MS-0048) were run by hand, not in these runs.

## 4. Decisions taken by the implementer

- The gui test for real mouse input is written next to `tests/fault/test_editor_window.py` as `tests/fault/test_editor_mouse_gui.py` (two tests: status bar layout; wheel and left drag). It declares the test process DPI aware so that the window rectangles and `SetCursorPos` agree. The status bar text (SB_GETTEXTW) is the read-out of zoom and offset, because cmd.test.* exists only headless. Not run.
- The review of WI-0091 asked whether the tray gui test covers "an open menu is not judged hung": it does (`test_the_real_icon_of_an_editor_opens_its_menu_and_a_menu_open_for_8_seconds_does_not_make_the_editor_hung`, the same pattern as `tests/fault/test_tray_role.py`). No case was added.
- The owner's feedback (E0088) is in the manual check 9, step 3, with the screenshots of the tool; the owner writes the acceptance there.
- The window measurement of the renderer is a bench option (`window` as the eighth argument), run by the owner (manual check 9, part E); the agent did not run it.
- The memory measurement is a tool (`tools/measure_editors.py`), not a pytest test, because the synthetic variant needs its own editor entry.
- F-0156 stays open (not closed): the number is not fine (p95 68.8 ms, above 50 ms).
- F-0158 (language files UTF-16 read as UTF-8) is an open finding and is not fixed here; it is reported in section 5.
- Load-sensitive tests named by the owner (settings log thresholds, worker busy, worker cold start, tray role restart, pipe latency F-0157) were not chased.
- The manual check 9 uses the manual-check data folder (section 1 part B imports the v1 flows there), as sections 1 to 5 do.

## 5. Owner questions (decision needed; also for NEEDS-ATTENTION)

1. **Batches of element states (design question from WI-0089, open):** inside one 33 ms batch the entries are in the order of the first change, so an instant element can come after its neighbour; and a fast element that repeats and fails shows only its last state in the batch. Decision needed: keep, or change (order by time of change, or count the failures).
2. **F-0156 (decision needed):** the editor's latency for a flow of 300 elements that all change in one interval is median 43.8 ms and p95 68.8 ms (MS-0050). Options: a smaller batch interval, a state path without a scene build, or the render process of ARCHITECTURE 2.1. The owner decides which.
3. **F-9001 (decision needed):** "Close" in the tray menu table of REQ-EDT-230 asks about unsaved changes, REQ-EDT-100 says closing asks nothing. Manual check 9, step 15 expects no question.
4. **Manual check 9 (owner):** the look (step 3, E0088, with the screenshots), zoom, move, tooltip, live states, tray menu, scaling and the screen move; the three gui tests (part D); the window measurement (part E, 1920 × 1080 and 3840 × 2160).
5. **F-0158 (open finding, owner):** `basic/de.ini`, `ko.ini` and `ru.ini` are UTF-16 but read as UTF-8; the languages are probably not loaded. Not fixed here.

## 6. Findings

- **F-0156** (open, measured): see criterion 2 and section 5.
- **F-9001*** (open, owner decision): see section 5.
- **F-9002*** (open, low): the renderer bench warns about a local variable `type` (`Trigger_Start_up.ahk` line 47) under `#Warn All`.
- **F-0158** (open, not fixed here): see section 5.
- **Own mistakes, fixed in this item:** (a) `cmd.editor.open` is reserved for the manager, so the first batch test could not open its editor; the test starts the editor itself. (b) The batch test read the batches of the client's expanded events; it groups them again by their sequence number. (c) The renderer bench had `#` comments and a load error that did not change the exit code of the chain (HOW-TO, drawing category).

## 7. Retrospective (task 7)

- **Hard:** the drawing cost was almost all GDI+ per-call work (icon scaling per draw, 108 ms of 300 ms; names 53 ms) and not the pixels. The fix was caching (icons, fonts, the static layer), measured at each step (HOW-TO `howto/drawing-gdip.md`, four entries).
- **Hard:** the batch of element states makes the editor's latency depend on the batch interval (33 ms) as well as the build. The measured p95 is above the requirement for 300 changes at once (F-0156).
- **For S0006 (editing):** the geometry (`FlowHit`, `FlowHitTest`, `FlowGeometry`) and the scene model (`SceneBuilder`, `Scene.WithStates`) are the base for selection, moving and connections; the view (zoom, offset) is read from the flow settings and is written from S0006 (E0086); the editor has no undo or draft yet; the menu bar (REQ-EDT-110) comes with S0006.
- **For S0006 and the owner:** the batch of element states is a per-flow stream; an editing operation must not depend on the state batches (they carry the states only).

## 8. Not checked

- The window variants (frame with BitBlt to a window, the look, the scaling 225 % and the screen move, the tray icon, the gui tests): owner.
- The renderer and the editor on a real 4K screen; the number of 4K values in MS-0048 is headless.
- The load of the machine during MS-0048 to MS-0050 (not recorded).
- PROTOCOL 4.11 and MIGRATION were not read section by section for S0005 changes; PROTOCOL 4.3 (the batch) matches the code (read); no new message type was added in this item.
- The gui tests were not run (by rule).
