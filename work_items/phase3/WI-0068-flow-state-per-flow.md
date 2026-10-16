# WI-0068 Enabled state per flow file, unknown state

Size: M · Depends on: WI-0060 · Blocks: WI-0062 (arming reads the state), S0004 (the manager shows `stateError` and asks before `force`)

## Goal

WI-0060 keeps the enabled state of all flows in one `FlowState.json`. A file that cannot be read then disables every flow, and a switch can only be written for all of them. This package keeps one file per flow (`FlowStates/<flowId>.json`, E0063) and gives a flow whose file cannot be read an explicit **unknown** state: its triggers are not armed, nothing is written for it, and the next switch reads the file once more. The owner's decisions: no timer retry after the start, `force` for the overwrite.

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 4, 6.1, 7; `doc/PROTOCOL.md` 4.2 (unknown state of a flow), 4.3 (`stateError`), 4.6 (`FlowStates/<flowId>.json`); E0057 and E0063 in `doc/DECISIONS.md`; WI-0060 (what is already built); `src/engine/FlowStateFile.ahk`, `src/storage/StateFiles.ahk`, `src/engine/Engine.ahk` (switch commands, `EmitFlowState`, load sequence).

## Tasks

1. **Docs first (own commit):** E0063, PROTOCOL 4.2, 4.3, 4.6, ARCHITECTURE 4, 6.1, 7, MIGRATION M-0070, F-0109 (done in the first commit).
2. **Storage:** `cmd.storage.flowstate.read/write/keepBroken` take `flowId`; the file is `FlowStates/<flowId>.json`; the folder is created by storage on the first write and at start; the flow ID is checked as a file name (bad_payload otherwise); the start cleanup of temp files covers `FlowStates/` (closes F-0109).
3. **Engine, load:** one read per loaded flow, two at a time. A real read error is retried at 250, 500 and 1000 ms; then the flow is unknown (`evt.storage.error` op `flowstate.read`, `stateError` in `evt.flow.state`). Missing file: nothing enabled, known. Broken file: kept as `.broken`, known and empty. Storage gone: the start waits again, as now.
4. **Engine, switches:** a switch of a known flow applies at once. A switch of an unknown flow reads the file first (deferred answer through `Deferred.Marker()` and `peer.Reply`); a switch while a read of that flow is in flight or while the start still reads it answers `ok: false` at once. `force: true` applies to the session state and writes it.
5. **Engine, writes:** one write per changed flow, coalesced per flow (at most once per second); flushed at shutdown for the changed flows only; no write for an unknown flow.
6. **Tests:** AHK unit tests of the file format (per flow) and the state transitions (known, unknown, forced); e2e: every flow has its own file; one unreadable file (a folder at the path) leaves the other flows armed as before and marks only that flow with `stateError`; a switch of that flow refused, then accepted once the file can be read again (the merge keeps the file's entries); `force` writes the session state; the state survives a restart; a broken file is kept per flow.

## Acceptance criteria

- The tests of task 6 are green, serial and parallel.
- `tests/stress/test_big_flows.py` at the end, time to ready within the budget (3 s) with per-flow reads.
- F-0109 is closed in `doc/OPEN-ITEMS.md` / `doc/CLOSED-ITEMS.md` with the evidence.

## Not part of this

The manager dialog for the unknown state and the question before `force` (S0004); a timer retry after the start (not decided, see E0063); deleting the state file of a deleted flow (S0004).
