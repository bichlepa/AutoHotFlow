# WI-0086 Engine: run states of a flow, the connection taken, warnings per element

Size: M · Depends on: – · Blocks: WI-0088, WI-0089

## Goal

The engine gives an editor what it needs for the live display: the states of all elements of one flow at once (for the resync), the connection a thread took to an element, and the warnings of the evaluation per element. Requirements: REQ-EDT-040, REQ-EDT-150 and REQ-VAR-100 (engine part), REQ-ROB-040, REQ-EXE-140.

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 4, 5; `doc/CONVENTIONS.md`; `doc/PROTOCOL.md` 4.2, 4.3; `doc/ELEMENT-API-V2.md` (the log of the evaluator); `src/engine/Executor.ahk` (`_ElementStarted`, `_ElementStopped`, `_EmitElement`, the selection of the next connection); `src/elements/base/ExecContext.ahk`, `src/elements/base/ParamEvaluator.ahk`, `src/expr/ExprEvaluator.ahk` (`_Warn`); `doc/CLOSED-ITEMS.md` (the two events per element pass, owner 2026-10-16).

## Tasks

1. **Docs first** (PROTOCOL 4.2, 4.3): `cmd.flow.runstate {flowId}` answers `{ ok, epoch, seq, flow: {enabled, independentActive, executing, instances, stateError?}, triggers: [ {elementId, enabled, armed, message} ], elements: [ {elementId, state, countRuns, lastRun, message?, warnings, lastWarning?} ] }` (only elements that ran or have warnings), `not_found` for an unknown flow. `evt.element.state` with state `running` carries `connectionId`, the connection the thread took (missing for the start at a trigger). `evt.connection.state` is removed from the protocol (replaced by the field; it was never sent). The wording of `cmd.flow.get` is corrected: it returns `flowSettings` with the view (zoom, offset).
2. **Connection taken:** the executor passes the ID of the selected connection to `_ElementStarted`; nothing else changes per pass.
3. **Warnings per element:** the warnings of the evaluation of an element (and its errors in compatibility mode, E0025) are counted per flow and element, with the last text (parameter, line, column; at most 500 characters). `evt.element.warning {flowId, elementId, count, text}` is sent at most once per second per element (coalesced, the count is exact). The counts stay until the element is removed or the flow is deleted or reloaded; `cmd.flow.runstate` returns them. The log lines stay as they are.
4. **Tests** (`tests/integration/`, the engine alone): runstate while an element runs and after the end (states, counts, `lastRun`); `connectionId` on the yes and no branch of a condition and into a loop; a type warning in compatibility mode in a loop of 1000 passes gives the exact count and at most a few events; strict mode gives an exception and no warning; runstate of an unknown flow is `not_found`; an engine restart starts with empty counts.
5. **Cost:** the time of 10,000 element passes with and without the change, within 5 % (one measurement, in the result).

## Acceptance criteria

- The tests of task 4 are green; PROTOCOL is updated in the same commit; REQ-EDT-150 and REQ-VAR-100 name the engine part as done in `v2` (the display follows in WI-0089).

## Not part of this

Showing the states and warnings (WI-0088, WI-0089); a command that resets the warning counts (S0006 if needed).
