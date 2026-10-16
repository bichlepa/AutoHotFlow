# WI-0057 Test corpus: v1 test flows and synthetic flows

Size: M · Depends on: WI-0045, WI-0049, WI-0052 to WI-0056 · Blocks: WI-0058

## Goal

A fixed list of flows runs headless and green and is the acceptance of S0002 and the regression of later steps: three "Automatic tests" flows of v1, adapted where needed (E0035), and synthetic flows that use the core set much more widely than the v1 flows do. Every fix of a v1 flow is documented like a later AI-assisted import would need it. Requirements: REQ-TST-040 (three flows now, all of them in S0008), REQ-TST-030.

## Read first

README of this phase (E0035), result of WI-0045 (markers, report), WI-0049 (builder, runner), WI-0052 to WI-0056, `doc/TEST-STRATEGY.md` 4, `tests/data/flows/v1_examples/`.

## Tasks

1. **v1 flows:** "variable test" (`Flow 1010290492.json`), "List test" (`Flow 1210127300.json`), "Loop test" (`Flow 634320780.json`). Load them, read the migration report (WI-0045), run them. What a test flow checks is read from the flow (it usually signals success or failure itself); the pytest test checks that signal. A fix of the flow is made on a copy (`tests/data/flows/v2_adapted/`); the original stays. Every fix gets a line in a fix list next to it: element, parameter, v1 text, new text, MIGRATION ID, reason. This list is the trial of what an AI-assisted import would have to do.
   Needs of the three flows (counted in the flow files): "variable test" lists and `Execute_Flow` (WI-0053, WI-0055), "List test" lists (WI-0053), "Loop test" loops and lists (WI-0053, WI-0054).
2. **Synthetic flows** with the builder (WI-0049), each with trace points and a checked result: arithmetic and text in conditions (strict and compatibility mode), lists in loops in loops, a flow that calls itself recursively with variables, a flow that waits for two called flows, dialogs with scripted answers in a loop (the debug dialog included, with a changed variable, REQ-DBG-060), a loop left through `exception`, a flow that calls a flow with an element of a missing package (E0047), `global_` and `static_` variables across two runs and an engine restart. At least 15 flows; the list is in the test file.
3. The other 13 "Automatic tests" flows: per flow the elements that are missing and the step that brings them (S0003, S0008). Into the result, so that S0003 and S0008 can extend the list.

## Acceptance criteria

- All flows of the list are green in the parallel and the serial run; the fix list is complete.
- The fix list contains no fix without a MIGRATION ID.

## Docs

`doc/TEST-STRATEGY.md` 4 (acceptance flows), `doc/MIGRATION.md` (new IDs found by the fixes). `doc/REQUIREMENTS.md` (AGENTS rule 12): REQ-TST-040 (`v2`, `Evidence`) and REQ-TST-030 (the e2e tests of all core elements exist), then `python tools/req_index.py`.

## Not part of this

The remaining "Automatic tests" flows (S0003, S0008).

## Result

- Three v1 flows of "Automatic tests" run green: "variable test" (on the copy `tests/data/flows/v2_adapted/`, one fix, M-0069), "List test" and "Loop test" as saved. The fix list is `FIX_LIST` in `tests/integration/test_corpus.py`; it has one fix (two elements, the same kind), with its MIGRATION ID.
- Sixteen synthetic flows (test_1 to test_16 of `tests/integration/test_corpus.py`) cover: arithmetic and text in conditions (strict and compatibility), `<` between texts (exception in strict, false with f1 in compatibility, M-0025), nested loops over lists, a break in a list loop, recursion with variables, a flow that waits for two called flows, message and confirmation dialogs in loops, the debug dialog with a changed variable, a loop left through `exception`, a call of a flow with a missing package (E0047; the caller ends with the outcome, M-0063), globals and statics across two runs and across an engine restart.
- The other 13 "Automatic tests" flows: the table `PENDING` of the test file lists per flow the missing element classes and the step. Summary: S0003 brings Set_flow_status, Condition_Flow_Enabled, Trigger_Hotkey, Trigger_Periodic_Timer and Trigger_Start_Up; S0008 brings everything else (file, window, process, string, math, dialog input, ini, shortcut and process triggers, user idle time, AutoHotkey script under E0039, sound and speech, HTTP).
- Not part of the corpus: the trigger state of a loaded flow. A v1 trigger with `enabled` does not enable its flow in v2 (the flow flag is set by `cmd.flow.enable` only); the corpus enables the flows it calls (REQ-EXE-070, S0003).
