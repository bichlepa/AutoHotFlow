# WI-41 Persistent `global`/`static`, data folder

Size: M · Depends on: WI-40 · Blocks: WI-42, WI-43

## Goal

`global` and `static` variables survive a restart of the engine and of the session. For this, the engine never reads files itself and never blocks (M-06): `storage` reads and writes, the engine holds the working copy. v2 does not write to the data folder of the productive v1 (open question 4).

## Read first

README of this phase (E21, E28, open question 4), ARCHITECTURE 6.1 (staggered loading, waiting for `storage`) and 6.3 (shutdown), `src/engine/Engine.ahk` (loading of the flows), `src/storage/` (`VarFiles.ahk`, `AtomicFile.ahk`, `WriteQueue.ahk`), `doc/PROTOCOL.md` 4.6, observation list in `work_items/STATUS.md` (`deadlineMs`).

## Tasks

1. **Data folder** (per the decision on question 4): v2's default folder separate from v1. Today `A_AppData "\AutoHotFlow"` applies (`Supervisor.DEFAULT_DATA_SUBDIR`), the same folder as the productive v1. Test: without `--data`, v2 does not start in the v1 folder. Note for the project owner in the result: what v2 runs have already created there (`Flows/`, `Log/`, `Reports/`; do not delete without asking first).
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
