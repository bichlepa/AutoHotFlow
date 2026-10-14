# WI-52 Core set A: variables, conditions, trace points

Size: M · Depends on: WI-48, WI-49 · Blocks: WI-54, WI-55, WI-57

## Goal

The most used elements run: `Action_New_variable`, `Condition_Expression`, `Condition_Variable_content_is`, `Condition_NumberIs`, `Condition_Variable_Is_Empty`, `Action_Do_nothing`, `Condition_Do_nothing`, `Action_Trace_Point`, `Action_Trace_Point_Check`. The trace points record the path through a flow and serve as instrumentation for all later e2e tests.

## Read first

README of this phase (E20, E34, E35), `doc/ELEMENT-API-V2.md` (all), the v1 files in `v1/Source_Elements/Default/Actions|Conditions/` and their help texts in `v1/Source_Elements/Default/help/en/`, `doc/MIGRATION.md`, result of WI-48 and WI-49.

## Tasks

1. Port each element by hand into `src/elements/Default/` (E36): class ID, parameter IDs, defaults, language keys and result strings as in v1 (ELEMENT-API 7). Mode inline. `CheckSettings` is ported as code (the form API is tested in S7).
2. Specification per element: the v1 help text and the AHK v2 behaviour (E35), not the v1 code. Where the v1 code differs from its help text, the help text wins unless real flows depend on the v1 behaviour; each such case into `doc/MIGRATION.md`.
3. `Action_Trace_Point_Check` needs to read the elements and parameters of its flow (v1 `x_getAllElementIDsOfClass`, `x_getElementPars`) and to stop the instance (`x_InstanceStop`): add the needed `ctx` functions (inline, from the committed definition of the engine) and document them in ELEMENT-API 3.
4. e2e tests per element with the flow builder (WI-49): every result path (`yes`/`no`/`normal`/`exception`), every option of the parameters, strict and compatibility mode where an expression is involved (E34).

## Acceptance criteria

- **Load path (F-282, README S2):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- The smoke test (WI-48) is green for the new elements; the e2e tests are green inline.
- The v1 flow "variable test" (`tests/data/flows/v1_examples/Flow 1010290492.json`) runs; if it needs a fix, it is documented in WI-57.

## Docs

`doc/ELEMENT-API-V2.md` 3 (new `ctx` functions), `doc/MIGRATION.md`.

## Not part of this

Settings dialog in the GUI (S7).
