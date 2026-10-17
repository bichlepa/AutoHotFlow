# WI-0073 Manager: window, model, resync, headless driver, replaces the stub

Size: L · Depends on: WI-0069, WI-0072 · Blocks: WI-0074, WI-0077, WI-0080

## Goal

The real manager replaces the stub: a model that holds the UI state from the engine's events and resyncs as the stub does, a view (the main window) built on `ui_common/`, and a headless driver so that every operation can be tested without a window. Closing the window only hides it (E0014); the "Exit" button ends the application. Requirements: REQ-MGR-080, REQ-EXE-140 (manager part), REQ-USE-040 (part), REQ-USE-090 (manager).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 3, 5, 6; `doc/PROTOCOL.md` 4.2, 4.3, 4.8 (the stub's resync rules), 5, 5a; `src/manager/StubManager.ahk`, `src/manager/StubGui.ahk`; `tests/e2e/test_ui_stub.py`; the v1 manager `v1/Source_Manager/User Interface/Manager GUI.ahk` (layout, buttons) and the screenshot `v1/Documentation/screenshots/Manager.png`; WI-0069 (result); `doc/TEST-STRATEGY.md` 6 (`gui` tier).

## Tasks

1. **Docs first:** PROTOCOL 4.8 becomes "Manager" (the subscriptions, the resync, the test commands of the headless driver), ARCHITECTURE 8 (`src/manager/` layout: model, view, driver).
2. **Model** (`ManagerModel`): flows, their state (`enabled`, `independentActive`, `executing`, `stateError`, triggers), categories and order (WI-0071), the connection state of the engine. Resync rules of the stub (epoch, `seq` gaps, `evt.engine.restarted`, duplicates). Commands to the engine with a timeout; every answer and error reaches the view as an event of the model. No GUI code in the model.
3. **View** (`ManagerWindow`): the main window with the tree (filled in WI-0074), the buttons as v1 (enabled by the selection), "Exit". DPI correct (WI-0069). Closing hides; `cmd.manager.show` shows and activates. Window position and size kept (in the settings once WI-0077 exists; until then in memory).
4. **Headless driver:** with `--headless` the manager has no window; `cmd.test.*` commands call the operations of the model and return its state, so that the e2e tests of WI-0074 to WI-0081 run in the normal tiers.
5. **The stub goes:** the tests that use `--ui=stub` move to the real manager headless, or the stub moves to the test entries (`tests/integration/helpers/`) if a test still needs it; nothing in `src/` refers to it any more. `doc/MANUAL-CHECKS.md` section 1 is rewritten for the real manager in WI-0076.
6. **Measurement:** the time from `cmd.manager.show` to the filled list with 200 big flows (`tests/stress/test_big_flows.py` data), and the private memory of the manager with them (REQ-PRF-030). In the result and `doc/MEASUREMENTS.md`.
7. **Tests:** the resync tests of the stub with the real manager; closing the window keeps the application running (a test closes it by `WM_CLOSE`, `gui` tier or through the window handle as in `tests/fault/test_debug_role.py`); "Exit" ends cleanly; a crash of the manager leaves the rest running.

## Acceptance criteria

- The tests of task 7 are green; the former stub tests are green with the real manager; foundation tier green.
- The measurement of task 6 is recorded.

## Not part of this

The tree and the operations (WI-0074), notices (WI-0075), settings (WI-0077), the log window (WI-0080).
