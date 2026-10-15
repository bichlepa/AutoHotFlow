# WI-0055 Core set D: flow control

Size: L · Depends on: WI-0050, WI-0052 · Blocks: WI-0057

## Goal

Flows call each other: `Action_Execute_Flow` (start another flow or the own one, optionally with a given trigger, send local variables, wait for the end, return the local variables, skip disabled flows), `Action_Stop_Flow`, `Condition_Flow_Running`. The step brings the engine functions it needs (guiding principle 1). `Execute_Flow` is used 44 times in the "Automatic tests" flows. Requirements: REQ-EXE-120, REQ-ELM-250.

## Read first

As WI-0052, plus `doc/PROTOCOL.md` (`cmd.flow.start`, `cmd.flow.stop`, `evt.instance.*`, execution policies), `doc/ARCHITECTURE.md` 4 (instances, policies `default`/`parallel`/`skip`/`wait`/`stop`, E0002), `doc/MIGRATION.md` M-0011, REQ-EXE-050 (until S0004 the policy `default` means `parallel`), REQ-EXE-070 (the enabled state exists, triggers do not react yet), E0047 (an element of a missing package fails with `exception` when run), the v1 elements and help texts, and how v1 implements them (`x_ExecuteFlow` or similar in `v1/Source_Execution/`).

## Tasks

1. Port the three elements by hand as in WI-0052, tasks 1 and 2. They run inline: the engine starts the other instance itself, no message round trip through the supervisor.
2. **Engine functions:** start an instance with initial instance variables and a chosen trigger; notify the calling execution when the called instance ends, with its result and (if wanted) its local variables; stop all instances of a flow from an element. `ctx` functions for this in ELEMENT-API 3. **Design for reuse:** "start an instance with arguments, wait, return the result and variables" is the operation that a flow used as a function needs (REQ-SCR-040, `later`: an expression calls a flow and waits). Keep it an engine function with the result as data, not tied to the element class. A waiting call must be cancellable from outside like a stopped instance (REQ-EXE-110; a per-element time limit, REQ-EXE-160, comes `later`).
3. **Edge cases with tests:** a flow calls itself (with and without waiting; policies of the called flow, E0002), the called flow is disabled (with and without `SkipDisabled`), does not exist (`flowID` of a deleted flow), ends with `exception`, is stopped while the caller waits, the caller is stopped while it waits (the called instance runs on, as in v1? decide by the help text, MIGRATION), recursion depth (limit or document), the called flow contains an element of a missing package (E0047: the called instance ends with `exception`, the caller gets that result).
4. `Condition_Flow_Running`: running and waiting instances (policy `wait`).
5. Note: `Set_Flow_Status` is S0003; `Condition_Flow_Enabled` is S0008 (REQ-ELM-250).

## Acceptance criteria

- **Load path (F-0073, README S0002):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- Smoke test and e2e tests green, including the edge cases of task 3.
- No call of an element blocks the engine while waiting for another flow (test: a third flow keeps running).

## Docs

`doc/ELEMENT-API-V2.md` 3, `doc/ARCHITECTURE.md` 4, `doc/PROTOCOL.md` if a message is added (own commit first), `doc/MIGRATION.md`. `doc/REQUIREMENTS.md` (AGENTS rule 12): REQ-EXE-120 and REQ-ELM-250 (`v2`, table rows, `Evidence`), then `python tools/req_index.py`.

## Not part of this

Triggers, `Set_Flow_Status` and enabling flows (S0003); a flow as a function (REQ-SCR-040, `later`).
