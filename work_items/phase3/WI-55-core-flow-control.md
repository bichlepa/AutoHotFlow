# WI-55 Core set D: flow control

Size: L · Depends on: WI-50, WI-52 · Blocks: WI-57

## Goal

Flows call each other: `Action_Execute_Flow` (start another flow or the own one, optionally with a given trigger, send local variables, wait for the end, return the local variables, skip disabled flows), `Action_Stop_Flow`, `Condition_Flow_Running`. The step brings the engine functions it needs (guiding principle 1). `Execute_Flow` is used 44 times in the "Automatic tests" flows.

## Read first

As WI-52, plus `doc/PROTOCOL.md` (`cmd.flow.start`, `cmd.flow.stop`, `evt.instance.*`, execution policies), `doc/ARCHITECTURE.md` 4 (instances, policies `default`/`parallel`/`skip`/`wait`/`stop`, E2), `doc/MIGRATION.md` M-11, the v1 elements and help texts, and how v1 implements them (`x_ExecuteFlow` or similar in `v1/Source_Execution/`).

## Tasks

1. Port the three elements by hand as in WI-52, tasks 1 and 2. They run inline: the engine starts the other instance itself, no message round trip through the supervisor.
2. **Engine functions:** start an instance with initial instance variables and a chosen trigger; notify the calling execution when the called instance ends, with its result and (if wanted) its local variables; stop all instances of a flow from an element. `ctx` functions for this in ELEMENT-API 3.
3. **Edge cases with tests:** a flow calls itself (with and without waiting; policies of the called flow, E2), the called flow is disabled (with and without `SkipDisabled`), does not exist (`flowID` of a deleted flow), ends with `exception`, is stopped while the caller waits, the caller is stopped while it waits (the called instance runs on, as in v1? decide by the help text, MIGRATION), recursion depth (limit or document).
4. `Condition_Flow_Running`: running and waiting instances (policy `wait`).
5. Note: enabling and disabling a flow (`Set_Flow_Status`, `Condition_Flow_Enabled`) is S3.

## Acceptance criteria

- **Load path (F-282, README S2):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- Smoke test and e2e tests green, including the edge cases of task 3.
- No call of an element blocks the engine while waiting for another flow (test: a third flow keeps running).

## Docs

`doc/ELEMENT-API-V2.md` 3, `doc/ARCHITECTURE.md` 4, `doc/PROTOCOL.md` if a message is added (own commit first), `doc/MIGRATION.md`.

## Not part of this

Triggers and enabling flows (S3).
