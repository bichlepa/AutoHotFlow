# WI-0093 Engine: patch operations, shared `FlowPatch`, revisions that share, the meta race

Size: L · Depends on: – · Blocks: WI-0094, WI-0095, WI-0096

## Goal

The engine applies the operations of `cmd.flow.patch` atomically as a new revision (E0001, ARCHITECTURE 4.2). There is one implementation of the operations, and the editor uses it too, for its draft and for undo. Requirements: REQ-EDT-100 (the commit part), REQ-EXE-080 (changes during execution).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 4.2, 7, 8; `doc/PROTOCOL.md` 4.2 (patch, flow lifecycle), 4.3 (`evt.flow.committed`); `src/engine/Engine.ahk` (`_CmdFlowPatch`), `src/engine/FlowRecord.ahk`, `src/engine/core/FlowDefinition.ahk`, `src/engine/FlowLifecycle.ahk` (`_OnMetaWritten`), `src/engine/Executor.ahk` (`_DefOf`); `doc/MIGRATION.md` M-0017, M-0018; v1: `v1/Source_Common/Elements/Manage Elements.ahk` (`Element_New`, `Element_Remove`, `Element_checkAndFixDefaultTrigger`).

## Tasks

1. **Docs first:** PROTOCOL 4.2: every operation with its fields, its rules and its errors, the answer; the new operation `connection.update`. ARCHITECTURE 4.2: the revisions that share unchanged maps, and the meta race. ARCHITECTURE 8: `src/core/FlowPatch.ahk`.
2. **`FlowPatch`** (`src/core/`, no engine code, no GUI): `Apply(raw, ops)` returns the new definition, or an error that names the operation and the reason. `Inverse(raw, ops)` returns the operations that undo them (the editor needs it in WI-0096). The operations:
   - `element.add {element}`: the whole element with the v1 keys (ARCHITECTURE 7).
   - `element.update {id, fields}`: changes the named keys; `pars` is merged by parameter ID.
   - `element.remove {id}`: the connections of the element go with it.
   - `connection.add {connection}`.
   - `connection.update {id, fields}`: type, ends, parts.
   - `connection.remove {id}`.
   - `flow.settings {settings, view?}`: the keys are merged; `view: true` marks a change of the view only (WI-0095, WI-0096).

   Rules: REQ-EDT-070 (no connection into a trigger, none from an element to itself, no second identical connection), both ends exist, IDs unique and in the v1 format, known kinds and connection types (the v1 spellings are kept). A flow that has manual triggers keeps exactly one `DefaultTrigger`: when the default trigger is removed, the first remaining manual trigger becomes the default (as v1). A list of operations is applied all or nothing.
3. **Engine:** `_CmdFlowPatch` applies the list and commits it, answers `{ok, rev}` and sends `evt.flow.committed {flowId, rev, byMeta: false}`. A refused operation is `bad_payload` with the message, and nothing changes. The command is `busy` while a deletion of the flow is pending. A used ID is refused, and `ElementIDCounter` stays above every number used. New texts are v2 texts (no conversion); an element with `v1Text` keeps the marker. A changed parameter loses its entry in the element's `migration` list, because the place is resolved (ARCHITECTURE 7, E0035).
4. **Revisions that share:** the new revision copies only the maps that change; the indexes of `FlowDefinition` are rebuilt cheaply. Nothing changes a committed map. Add a test that a revision stays the same after later patches.
5. **The meta race (finding of the plan):** `cmd.flow.meta.update` commits the name or the category on top of the revision that is current when storage answers, not the definition built before the write. Add a test: a patch committed between the request and the answer of storage is kept.
6. **Measurement first** (stop and report if the mean is above 50 ms): on the generated flow of 300 elements, measure the engine time of a patch that moves one element, one that moves 30, and one that adds 30 elements with their connections (mean and p95), and the delay of the executor's steps during 100 patches in a row. Record it in `doc/MEASUREMENTS.md`, with a proposal for the budget.
7. **Tests:** AHK unit tests for every operation and every rule, and for `Inverse` (applying the operations and then their inverse gives the original, for random lists of operations on the corpus flows). Integration tests: commit, conflict, a refused operation, the meta race, a running instance that follows a connection added during the run (E0001), and a removed next element (M-0017). At the end, `tests/stress/test_big_flows.py` (F-0073, budget 3 s).

## Acceptance criteria

- The tests of task 7 are green and the measurement is recorded. PROTOCOL and ARCHITECTURE are updated. REQ-EDT-100 and REQ-EXE-080 are updated.

## Not part of this

The effect on triggers (WI-0094), saving (WI-0095), the editor side (WI-0096).
