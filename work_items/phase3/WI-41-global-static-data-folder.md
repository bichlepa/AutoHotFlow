# WI-41 Persistent `global`/`static`, data folder

Size: M · Depends on: WI-40 · Blocks: WI-42, WI-43

## Goal

`global` and `static` variables survive a restart of the engine and of the session. For this, the engine never reads files itself and never blocks (M-06): `storage` reads and writes, the engine holds the working copy. v2 does not write to the data folder of the productive v1 (E33).

## Read first

README of this phase (E21, E28, E33), ARCHITECTURE 6.1 (staggered loading, waiting for `storage`) and 6.3 (shutdown), `src/engine/Engine.ahk` (loading of the flows), `src/storage/` (`VarFiles.ahk`, `AtomicFile.ahk`, `WriteQueue.ahk`), `doc/PROTOCOL.md` 4.6, observation list in `work_items/STATUS.md` (`deadlineMs`).

## Tasks

1. **Data folder:** done before this package (E33, 2026-10-13): the default is `%APPDATA%\AutoHotFlow v2` (`Supervisor.DEFAULT_DATA_SUBDIR`), separate from the folder of the productive v1. Check only that the variable files go below the resolved data folder. Earlier v2 runs left `Flows/`, `Log/` and `Reports/` in `%APPDATA%\AutoHotFlow`; do not delete them without asking the project owner.
2. **Messages** (new in PROTOCOL 4.6): e.g. `cmd.storage.var.list`, `cmd.storage.var.read`, `cmd.storage.var.write`, `cmd.storage.var.delete`, with `scope` (`global`, `static` + `flowId`). Check and use the existing `VarFiles.ahk`.
3. **File format** (E28): pair of `.ahfvd` (JSON `{name, type}`) and `.ahfvar` (text or JSON). Reading: v1 files are UTF-8 with BOM (verified on a file of the project owner; v1 sets `FileEncoding utf-8`). Writing: atomic (`AtomicFile`), define the encoding (proposal: UTF-8 without BOM as in M-16; reading accepts both). Types: text, number (as text as in v1; stays text when loaded, see golden data), object (JSON).
4. **Loading at startup:** The engine loads all `global` and `static` variables before it reports `evt.engine.ready`, staggered like the flows (ARCHITECTURE 6.1, waiting for `storage`, continuing after an abort). Reason: an expression reads variables synchronously, and loading on demand would only work by blocking.
5. **Delayed writing:** collect changes and write only the latest state per variable (e.g. at most every 200 ms per variable); deletions likewise. Errors from `storage` → `evt.storage.error`; the working copy stays (ARCHITECTURE 6.2).
6. **Shutdown:** `Engine.OnShutdown` writes open changes before `sys.bye` and uses `deadlineMs` for this (closes the item of the observation list for the engine). Test: set a variable, shut down immediately, value present after restart.
7. **Engine restart** (crash): What was not written is lost (like running instances, M-01); add this to MIGRATION at entry M-06. Test: after `kill` of the engine, all values are present that are older than the write delay.

## Acceptance criteria

- Round trip of the v1 variable files from `tests/data/` (copies of examples; private ones only locally): load, change, write, reload, same value and type.
- Fault: `storage` frozen during writing → engine does not block, error is reported, after thawing the writing happens.
- Serial and parallel green (the package changes timing at startup and shutdown).

## Docs

`doc/PROTOCOL.md` 4.6, `doc/ARCHITECTURE.md` 4, 6.1, 6.3, 7, `doc/MIGRATION.md` M-06, `AGENTS.md` (data folder), `.vscode/tasks.json` (if the `Start:` tasks change due to the data folder).

## Not part of this

Import of the v1 data via the UI (S4).

## Result

- **Code:** `src/engine/vars/VarLoader.ahk` (list and get through storage, 2 requests at a time, continues after an abort), `VarWriter.ahk` (delayed write of the latest state per variable, retry, flush at shutdown), `EngineVars.Touch`/`OnChange` and `VarAccess._Touch` (every change of a global or static variable is reported), `Engine` (loading between the flow files and `evt.engine.ready`, `OnShutdown`, options `--var-write-delay-ms` and `--var-write-timeout-ms`, passed on by the supervisor). Test element `Action_TestSetVar` (set, delete, probe).
- **Decisions taken here:** the existing messages `cmd.storage.var.get/set/delete/list` are used (no new type; the work item named them read/write). Texts from the files stay texts, numbers are written as their text (M-39). v2 writes without BOM. No wait for acknowledgements at shutdown: the frames precede `sys.bye` and storage ends last; the rest of `deadlineMs` is the limit of each request. A flow that starts before `evt.engine.ready` can see missing variables (the manager waits for ready; not changed). Statics of a flow that is not loaded are not read.
- **Tests:** `tests/ahk/engine_var_files.test.ahk` (13 cases, stand-in engine), `tests/fault/test_var_persistence.py` (round trip of the v1 files over two sessions, delayed write and kill of the engine, write at shutdown and loss after a kill, frozen storage). `tests/integration/test_engine.py` stand-in storage answers `var.list`.
- **Data folder (task 1):** checked by reading: the variable files go below the resolved data folder (`VarFiles` and `StoragePaths` take `dataDir` of storage, which gets `--data`). No change to the default folder; existing `Flows/`, `Log/` and `Reports/` in `%APPDATA%\AutoHotFlow` were not touched.
- **Not checked:** a real data folder of the project owner (private data), the start of the product by hand, a very large number of variables (hundreds) under load, the GUI.

