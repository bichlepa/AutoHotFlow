# WI-0070 Engine and storage: create, rename, duplicate, delete a flow

Size: L · Depends on: – · Blocks: WI-0071, WI-0074, WI-0076

## Goal

The engine commands that the manager needs for the life of a flow exist and are tested: `cmd.flow.create` (empty or with a definition, also a v1 definition for the import), `cmd.flow.meta.update` (name, category), `cmd.flow.duplicate` and `cmd.flow.delete`. Storage can delete a flow file and the files that belong to it. Requirements: REQ-MGR-020, REQ-EXE-060 (part).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 3, 4, 6.1, 7; `doc/PROTOCOL.md` 4.2, 4.3, 4.6; E0009, E0058, E0063, E0065, E0066 in `doc/DECISIONS.md`; `src/engine/Engine.ahk` (load sequence, `FlowDeleted`), `src/engine/FlowTable.ahk`, `src/engine/FlowRecord.ahk`, `src/engine/core/FlowDefinition.ahk`, `src/storage/Storage.ahk`, `src/storage/FlowFiles.ahk`, `src/storage/StoragePaths.ahk`; v1 `v1/Source_Common/Flows/Manage Flows.ahk` (`NewFlow`, names) and the v1 delete in the manager.

## Tasks

1. **Docs first (own commit):** PROTOCOL 4.2 (`cmd.flow.create`, `cmd.flow.meta.update`, `cmd.flow.duplicate`, `cmd.flow.delete` with payloads, answers and errors), 4.6 (`cmd.storage.flow.delete`), MIGRATION (new flow IDs independent of the language).
2. **Names:** one check in the engine for every command that sets a name: not empty, no character that v1 forbids (read the v1 check), no second flow with the same name (ignoring case, as v1; check in the v1 code). Error `bad_payload` with a message the manager shows.
3. **Create:** `{ name?, category?, definition? }`. Without a name the engine picks "New flow n" (as v1, the text through `Lang`). New ID `Flow <random>` that exists neither in the table nor as a file. Without a definition: an empty flow with a `Trigger_Manual` (as v1; check), `strictTypes` true. With a definition: it is loaded like a file (conversion of v1 expressions, MIGRATION markers, E0058 disabled), then written. The answer comes after storage wrote the file; then `evt.flow.list.changed`.
4. **Rename and move:** `cmd.flow.meta.update` changes the definition (a new revision, `evt.flow.committed` with `byMeta`) and writes the file at once (E0065: no unsaved state).
5. **Duplicate:** `{ flowId, name? }`: a copy with a new ID and the name "<name> 2" (or the next free number), all triggers disabled, static variables not copied (check what v1 does; deviation into MIGRATION).
6. **Delete (E0066, E0009):** stops the instances at once, removes the flow from the table and its armed triggers, and has storage delete the flow file, `FlowStates/<flowId>.json` (closes the open point of WI-0068) and the static variables (`Variables/<flowId>/`); the backups of the flow in `Flows/backup/` stay. The variables in the memory of the engine go too.
7. **Tests:** e2e for every command and error (name taken, bad characters, unknown flow, storage error while writing: nothing changes in the table); delete of a running flow; delete of a flow with an unknown state (E0063); a created flow survives a restart; an imported v1 definition loads disabled with its markers.

## Acceptance criteria

- The tests of task 7 are green, serial and parallel; foundation tier green if `src/core/` changed.
- REQ-MGR-020 has the evidence of the engine part (the manager part follows in WI-0074).

## Not part of this

Categories and order (WI-0071), the manager (WI-0074), the import UI (WI-0076).
