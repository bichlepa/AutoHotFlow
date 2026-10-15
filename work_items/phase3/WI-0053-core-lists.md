# WI-0053 Core set B: lists

Size: M · Depends on: WI-0048, WI-0049 · Blocks: WI-0057

## Goal

The list elements run: `Action_New_List`, `Action_Add_To_List`, `Action_Get_List_Info`, `Condition_List_Contains_Element`, `Action_Delete_from_list`, `Action_Get_index_of_element_in_list`, `Action_Shuffle_list`. Together with WI-0052 this covers the v1 flow "List test".

## Read first

As WI-0052, plus `doc/EXPRESSION-LANGUAGE.md` 18 (object variables as `Map` with `CaseSense := "Off"`, E0028; keys `1` and `"1"`, HOW-TO), the v1 list elements and their help texts.

## Tasks

1. Port by hand as in WI-0052, tasks 1 and 2. Pay attention to the v1 list model (keys, positions, gaps after a delete, "simple list" versus object with keys) and to the conversion between `Array` and `Map` (ELEMENT-API 3, `SetVar` copies an Array into a `Map` with the keys 1..n).
2. `Action_Shuffle_list`: the test checks the content and the count, not the order; a seed for tests only if the element offers none.
3. e2e tests per element with the flow builder, including lists with gaps, nested objects, empty lists and texts that look like numbers as keys.

## Acceptance criteria

- **Load path (F-0282, README S0002):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- Smoke test and e2e tests green; the v1 flow "List test" (`Flow 1210127300.json`) runs (fixes documented in WI-0057).

## Docs

`doc/MIGRATION.md`, `doc/EXPRESSION-LANGUAGE.md` 18 if the list model is clarified.

## Not part of this

Conversion between lists and texts (`Convert_list_to_string` and others, S0008).
