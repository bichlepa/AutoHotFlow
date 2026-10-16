# WI-0060 Enabled state of triggers

Size: L · Depends on: – · Blocks: WI-0062, WI-0065, WI-0066

## Goal

The engine knows, per trigger, whether it is enabled, keeps this state across starts and switches it on command, following the model of E0056. The state lives in `FlowState.json` (E0057); a flow file in the v1 format loads disabled (E0058). Nothing is armed yet (WI-0062): this package delivers the target state. Closes F-0099. Requirements: REQ-EXE-070, REQ-TRG-030, REQ-TRG-050 (the parts without manager and editor).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 1 to 6 (4: data ownership, 6.1: start and the loading of the variables, which is the pattern for the new file) and 7; `doc/CONVENTIONS.md`; `doc/PROTOCOL.md` 4.2 (`cmd.flow.enable/disable`, `cmd.trigger.enable/disable`, `evt.flow.state`) and 4.6 (storage commands, `cmd.storage.var.*` as the pattern); E0056 to E0058 in `doc/DECISIONS.md`; F-0099 in `doc/OPEN-ITEMS.md`; MIGRATION M-0063 (6); REQ-EXE-070, REQ-TRG-020, REQ-TRG-030; `src/engine/Engine.ahk` (`_CmdFlowEnable`), `src/engine/FlowRecord.ahk`, `src/engine/Executor.ahk` (`IsTriggerEnabled`), `src/engine/core/FlowDefinition.ahk`; v1 `v1/Source_Execution/Trigger/Trigger.ahk` and `v1/Source_Common/Flows/Manage Flows.ahk` (`EnableLoadedFlows`).

## Tasks

1. **Model (E0056)** in the engine, with an AHK unit test of every transition:
   - Every trigger of a loaded flow has a target state `enabled` (true/false).
   - `followsFlow` is read from the trigger element of the flow definition (key `followsFlow`; missing means true). It is part of the definition and is written back unchanged by `cmd.flow.save`.
   - A flow is active when at least one of its triggers with `followsFlow` is enabled (derived, not stored).
   - `cmd.flow.enable`: every following trigger is enabled. A flow without a following trigger answers `{ok, message}` with the reason and changes nothing.
   - `cmd.flow.disable {flowId, all?}`: every following trigger is disabled; with `all: true` every trigger, independent ones included (for the manager dialog of S0004). The answer names `independentActive`, the number of independent triggers still enabled.
   - `cmd.trigger.enable` / `cmd.trigger.disable {flowId, elementId}`: only this trigger. `bad_payload` if the element is not a trigger of the flow.
   - `evt.flow.state` carries `enabled` (the derived state) and `independentActive`. New `evt.trigger.state {flowId, elementId, enabled}` on `flow:<id>` for every change (WI-0062 adds `armed` and `message`).
   - Running instances are not affected by any switch (as v1).
2. **`FlowState.json` (E0057):** in the data folder, written only by storage, owned by the engine (as the variables, ARCHITECTURE 4). Format with `formatVersion` (1) and per flow ID the IDs of its enabled triggers. Storage commands to read and to write the whole file (atomic, `AtomicFile`), in PROTOCOL 4.6. The engine reads it after the flow files and before `evt.engine.ready`, with the same waiting for storage as the variables; a missing file means "nothing enabled", a broken file is logged (`a0`), kept as `FlowState.json.broken` and treated as missing. The engine writes after a change, coalesced (at most one write per second) and flushed in the shutdown before `sys.bye` (as the variables, WI-0041). An entry of a flow that is not loaded is kept (the file may come back); deleting a flow (S0004) removes its entry.
3. **v1 files (E0058):** a flow file without `formatVersion` gets nothing from its `enabled` keys; a flow without an entry in `FlowState.json` has all triggers disabled. `cmd.flow.save` does not write `enabled` keys into the elements any more (the state is in `FlowState.json`). MIGRATION entry: v1 enabled the triggers saved as enabled at the next start; v2 does not for v1 files (reason: REQ-SEC-060, v1 and v2 side by side).
4. **`IsTriggerEnabled`** (`Executor`, `ctx.IsTriggerEnabled`) reads the target state of the trigger, no longer the flag of the flow. F-0099 closed; M-0063 (6) and ELEMENT-API 3 updated. The corpus and the WI-0055 tests that call `cmd.flow.enable` keep passing; where a test enabled a flow only to call a trigger, it still works because the trigger follows the flow.
5. **Start by hand:** check in v1 (manager, `x_ManualTriggerExecute`, `executeFlow`) whether a disabled flow can be started by hand. v2 keeps `cmd.flow.start` allowed for a disabled flow; a different v1 behaviour goes into MIGRATION.
6. **Tests:** the unit test of task 1; e2e (`tests/integration/`): enable, disable, `all`, single trigger, `independentActive`; the state survives the end and a new start of the session (same data folder) and an engine restart (crash: at most the last second is lost, documented); a v1 file with `enabled` keys loads disabled; a broken `FlowState.json` does not stop the start.

## Acceptance criteria

- The tests of task 6 are green, serial and parallel.
- **Load path (F-0073):** `tests/stress/test_big_flows.py` at the end, time to ready and largest snapshot answer in the result, within the budget (3 s).
- F-0099 is closed in `doc/OPEN-ITEMS.md` / `doc/CLOSED-ITEMS.md` with the evidence.

## Docs

`doc/PROTOCOL.md` 4.2, 4.6 (own commit first, rule 5), `doc/ARCHITECTURE.md` 4 (owner table: `FlowState.json`) and 7 (files of the data folder), `doc/ELEMENT-API-V2.md` 3 (`ctx.IsTriggerEnabled`), `doc/MIGRATION.md` (task 3, task 5, M-0063), `doc/REQUIREMENTS.md`: REQ-EXE-070 (`v2` partial: triggers are not armed until WI-0062), REQ-TRG-030, REQ-TRG-050 (`v2` partial: manager and editor missing), then `python tools/doc_index.py`.

## Not part of this

Arming (WI-0062); the manager dialog and display (S0004); the checkbox `followsFlow` in the editor (S0007); the state of a trigger added by the editor (S0006).
