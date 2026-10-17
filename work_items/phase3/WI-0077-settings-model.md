# WI-0077 Settings: file, engine commands, live effect, settings of v1 in the import

Size: L · Depends on: WI-0073, WI-0076 · Blocks: WI-0078, WI-0079

## Goal

AutoHotFlow has global settings, kept in `Settings.json` in the data folder and applied without a restart where possible. Storage owns the file, the engine owns the runtime copy and reports changes; every role takes what it needs. The import of v1 takes over the settings of E0068. Requirements: REQ-SET-010 (model), REQ-SET-020, REQ-SET-050, REQ-SET-070, REQ-EXE-050, REQ-EXE-130, REQ-EXE-170 (global defaults), REQ-LNG-010, REQ-LNG-020, REQ-USE-010 (setting).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 3 (owners of the settings), 6.1, 6.4 (worker pool), 9; `doc/PROTOCOL.md` 4.2 (`cmd.settings.*`), 4.3 (`evt.settings.changed`), 4.6 (`cmd.storage.settings.*`), 4.6 log threshold; E0028, E0044, E0048, E0062, E0069, E0071 in `doc/DECISIONS.md`; `src/core/LangTable.ahk`, `src/core/Log.ahk`, `src/engine/WorkerBridge.ahk`, `src/engine/core/RunawayGuard.ahk`, `src/supervisor/Children.ahk` (`WORKER_LIMIT`); v1 `v1/Source_Common/Settings/Settings.ahk`.

## Tasks

1. **Docs first:** PROTOCOL 4.2, 4.3, 4.6 (format of `Settings.json` with `formatVersion`, every key with type, default and range); ARCHITECTURE 6.4 and 9 (pool size default 8, 1 to 16, `WORKER_LIMIT` 24, E0048); MIGRATION ("Log to file" dropped, E0069; any key that differs from v1).
2. **Keys:** language (empty = language of Windows, REQ-LNG-020), default execution policy, working directory (default `A_MyDocuments "\AutoHotFlow"`, E0028), number of workers, the three log thresholds (E0069), the three default limits of the runaway guard (E0071), the user level (Beginner, Advanced, Programmer; used by S0007), "notify unhandled errors" (WI-0075), start with Windows and run as administrator (used by WI-0079), the window positions of the manager (UI state, WI-0073). A missing or invalid value counts as its default and is logged.
3. **Storage:** read and write the file atomically; a broken file is kept as `.broken` and the defaults are used.
4. **Engine:** loads the settings before the flows; `cmd.settings.get` and `cmd.settings.set` (a partial set, checked; `bad_payload` with the key); writes through storage; sends `evt.settings.changed` with the whole set; `cmd.engine.snapshot` carries `settings`. Applies at once: policy `default`, working directory, the limits (flows whose value is `default`), the pool size (grows or shrinks; a worker with a job ends after its job).
5. **Every role:** takes the log thresholds and the language from `evt.settings.changed` (`Log`, `LangTable.Code` and reload, `UiTexts.Reload()` of WI-0069); the supervisor for its tray menu (WI-0072) and for the options of new children. The command-line options (`--workers`, `--log-level`) stay for tests and win over the file; document the order.
6. **Import of v1:** the import of WI-0076 takes over the keys of E0068 from `settings.json` of v1 (without autostart and administrator).
7. **Tests:** unit tests of the checks; e2e: a set changes the behaviour at once (policy, working directory, limit, log threshold, language of a `Lang` text in two roles, pool size up and down); the settings survive a restart; a broken file; the v1 import of the settings.
8. **Load path:** `tests/stress/test_big_flows.py` at the end.

## Acceptance criteria

- The tests of task 7 are green, serial and parallel; foundation and slow tiers green (the change touches the supervisor, the worker pool and storage).
- The stress test within the budget.

## Not part of this

The dialog (WI-0078); the autostart entry and the elevation themselves (WI-0079).
