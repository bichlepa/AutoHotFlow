# WI-57 Test corpus: v1 test flows and synthetic flows

Size: M · Depends on: WI-45, WI-49, WI-52 to WI-56 · Blocks: WI-58

## Goal

A fixed list of flows runs headless and green and is the acceptance of S2 and the regression of later steps: three "Automatic tests" flows of v1, adapted where needed (E35), and synthetic flows that use the core set much more widely than the v1 flows do. Every fix of a v1 flow is documented like a later AI-assisted import would need it.

## Read first

README of this phase (E35), result of WI-45 (markers, report), WI-49 (builder, runner), WI-52 to WI-56, `doc/TEST-STRATEGY.md` 4, `tests/data/flows/v1_examples/`.

## Tasks

1. **v1 flows:** "variable test" (`Flow 1010290492.json`), "List test" (`Flow 1210127300.json`), "Loop test" (`Flow 634320780.json`). Load them, read the migration report (WI-45), run them. What a test flow checks is read from the flow (it usually signals success or failure itself); the pytest test checks that signal. A fix of the flow is made on a copy (`tests/data/flows/v2_adapted/`); the original stays. Every fix gets a line in a fix list next to it: element, parameter, v1 text, new text, MIGRATION ID, reason. This list is the trial of what an AI-assisted import would have to do.
2. **Synthetic flows** with the builder (WI-49), each with trace points and a checked result: arithmetic and text in conditions (strict and compatibility mode), lists in loops in loops, a flow that calls itself recursively with variables, a flow that waits for two called flows, dialogs with scripted answers in a loop, `global_` and `static_` variables across two runs and an engine restart. At least 15 flows; the list is in the test file.
3. The other 13 "Automatic tests" flows: per flow the elements that are missing and the step that brings them (S3, S8). Into the result, so that S3 and S8 can extend the list.

## Acceptance criteria

- All flows of the list are green in the parallel and the serial run; the fix list is complete.
- The fix list contains no fix without a MIGRATION ID.

## Docs

`doc/TEST-STRATEGY.md` 4 (acceptance flows), `doc/MIGRATION.md` (new IDs found by the fixes).

## Not part of this

The remaining "Automatic tests" flows (S3, S8).
