# WI-54 Core set C: loops

Size: M · Depends on: WI-48, WI-49, WI-52 (trace points) · Blocks: WI-57

## Goal

The loops run: `Loop_SimpleLoop`, `Loop_Condition`, `Loop_Work_through_a_list`, `Loop_Parse_A_String`, with the entry points `head`/`tail`, `break`, loop variables (`A_Index` and the others of v1), nesting and stop. Together with WI-52 this covers the v1 flow "Loop test".

## Read first

As WI-52, plus `doc/ELEMENT-API-V2.md` 7 (loop entry points, `ctx.entryPoint`, loop variables), `doc/ARCHITECTURE.md` 4 (execution of loops in the executor), `doc/EXPRESSION-LANGUAGE.md` 18 (loop scope), `src/engine/Executor.ahk`, the v1 loop elements and their help texts, v1 `HeightOfVerticalBar` and the connection parts of a loop (`fromPart`/`toPart`).

## Tasks

1. Port by hand as in WI-52, tasks 1 and 2.
2. Check that the executor supports what the loops need (loop scope per nesting level, `break` from the body, a stop while the body runs, a change of the flow during the loop, E1); missing parts are added in the engine with tests.
3. e2e tests with the flow builder and trace points: 0, 1, many passes, `break` in the first and in the last pass, nested loops with the same loop variable names, a list changed in the body (behaviour as in the v1 help text, MIGRATION otherwise), parsing with every delimiter option, a long loop (100,000 passes) that does not block the engine (other flows and the UI stay responsive; measure time per pass).

## Acceptance criteria

- Smoke test and e2e tests green; the v1 flow "Loop test" (`Flow 634320780.json`) runs (fixes documented in WI-57).
- Time per pass of `Loop_SimpleLoop` with an empty body in `doc/MEASUREMENTS.md`.

## Docs

`doc/ELEMENT-API-V2.md` 7, `doc/ARCHITECTURE.md` 4 if the executor changes, `doc/MIGRATION.md`, `doc/MEASUREMENTS.md`.

## Not part of this

`Loop_Loop_Through_Files` (S8).
