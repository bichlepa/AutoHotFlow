# WI-0134 Demonstration flows (E0105)

Size: M · Depends on: WI-0119, WI-0122, WI-0124 (the elements of the demos) · Blocks: WI-0135

## Goal

AutoHotFlow ships three demonstration flows of v1 (Loop tutorial, Pet guesser, Joke teller) in the category "Demonstration". They are read only: they cannot be renamed, moved, deleted or changed; the editor shows them read only and points to "Duplicate"; they are disabled until the user enables them; the setting "Hide demonstration flows" hides them. Requirements: REQ-MGR-060, REQ-SEC-050 (nothing contacts a server by itself).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0105; `doc/ARCHITECTURE.md` 4 (data ownership), 7 (loading v1 flows), 8; `doc/PROTOCOL.md` 4.2 (flow commands, `cmd.flow.patch`), 4.8 (manager), 4.11 (editor); `src/core/SettingsModel.ahk` (`HideDemoFlows` is skipped by the v1 import until now); the manager's flow list and category code (WI-0071, WI-0074); v1: `Saved Flows/demo flows/`, `Source_Common/Flows/Manage Flows.ahk`, `Source_Manager/User Interface/Manager GUI.ahk` (the category `demo`), `Source_Common/Flows/Flow actions.ahk` (the warning when a demo is opened).

## Tasks

1. **Docs first:** ARCHITECTURE 4 and 8 (where the demos live and who owns them), PROTOCOL (the mark `demo` in the flow list and the snapshot, the refusal code of a change), MIGRATION (the Update checker is left out; demos are read only also in the editor).
2. **Files:** the three flows in `assets/demo_flows/`, loaded as v1 flows (E0021); the fixes they need are MIGRATION places in the flow, as for every loaded v1 flow. Check each runs in v2 (the Joke teller needs the network: its test uses the local server of WI-0122 on a copy).
3. **Engine and storage:** the engine loads them with the mark `demo` from the program folder; their trigger states live in the data folder as for every flow, and start disabled; every change (`cmd.flow.patch`, rename, move, delete, category) is refused with a clear code; duplicate makes a normal flow in the data folder. A flow of the user with the same ID as a demo: decide and document (the demo wins, or it is not loaded, with a log line).
4. **Manager:** the category "Demonstration" (fixed name from the language file, not renamable, not deletable, always at the end or where v1 had it); delete or rename of a demo asks whether to hide all demos instead (as v1); the setting "Hide demonstration flows" in the settings dialog and in the import from v1 (`HideDemoFlows`).
5. **Editor:** a demo opens read only (no editing action, a hint in the status bar or a bar above the canvas with "Duplicate to change it"); the view (zoom, offset) is not written.
6. **Tests:** loaded with the mark, disabled at the first start, every change refused, duplicate editable, hidden by the setting, the editor refuses an edit (headless); the look is checked by the owner (manual check 12).

## Acceptance criteria

- The tests of task 6 are green; REQ-MGR-060 is updated; the documents of task 1 are updated.

## Not part of this

A check for updates (a feature of its own, off until the user switches it on, REQ-SEC-050); more demos than v1.

## Result

Status: **not accepted**. The implementation and the new tests are in; the final verification of `6ecf16a0` is red.

- Commits (prefix WI-0134): docs `e4da3205`; storage and engine `5facbb58`; manager `7ce67605`; editor `54726e35`; requirement, open points and group table `ce277a43`; run tests `4cb008ea`; test adjustments `ce9bcbe7`, `6ecf16a0`.
- New tests (all green when run serially at the commits named): `tests/integration/test_demo_flows.py` (9 passed at `5facbb58`, run 20261102-171323), `tests/e2e/test_manager_demo.py` and `tests/e2e/test_editor_demo.py` (8 passed at `54726e35`, run 20261102-171609), `tests/integration/test_demo_flows_run.py` (2 passed at `4cb008ea`, run 20261102-172554).
- Final verification `--auto --base v2-port` at `6ecf16a0`, run 20261102-183022-6ecf16a0 (fast), `-3` (foundation), `-2` (slow): red. Fast: 8 failed; foundation: 1 error and 1 failed; slow: 1 failed. Not all classified (recheck tool could not select the node IDs; classified by serial reruns instead).
  - Caused by the change, fixed: flow and settings counts (storage, engine start, manager flow tests, settings key set, import settings). Serial reruns green at `ce9bcbe7` and `6ecf16a0`.
  - Still red, not classified: `test_ahk_runner` core_settings (AHK unit test of the settings keys, not yet adapted), `test_manager_import::test_every_flow_of_the_folder_is_imported_with_its_id_and_disabled` (see decision 3), `test_editor_flow_ctx` force question, `test_worker` (two), `test_window_elements`, `test_worker_vars`, `test_pipe` (abrupt end, timing under load), `test_corpus` file link. The last four look like load effects; not verified.
- Decisions (for the owner):
  1. Demo flows keep their ID; a user file with the same ID is not loaded (M-0187). Alternative: the user's file wins.
  2. Hiding demos is a manager display setting; the engine keeps loading them (M-0186). Alternative: the engine does not load hidden demos.
  3. A v1 flow or `.ahf` entry with a demo ID is skipped by the import ("a flow with this ID exists already"). The example folder of the import test contains such IDs, so the test's expectation changed. Decision needed: skip, or import as a copy with a new ID.
  4. Group "Demonstration" first, as v1; the name is reserved for categories.
- Findings (in OPEN-ITEMS, provisional): F-0211 element settings dialog of a demo (refusal not shown, not checked); F-0212 import with a demo ID (not checked; now observed by the import test, see decision 3); F-0213 Joke teller's HTTP request does not reach the local server in the test (cause not found).
- Not done: manual check 12 is not written in `doc/MANUAL-CHECKS.md` (no section 12 exists); the look of the group, the question and the editor hint are for the owner. Loop tutorial is not run (endless loops). `tools/recheck.py` could not select node IDs with the `@` suffix (`tests/test_ahk_runner.py::...[...]@...`).
- Verified: classes of the three flows are known and have no migration marks (`tools/migration_report.py`); arch check 0 violations; test_groups, doc index and architecture tests green.
- Not checked: Loop tutorial run; Joke teller with the real site and voice; window look; the reds listed above.
