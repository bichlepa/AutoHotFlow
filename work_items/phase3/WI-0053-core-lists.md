# WI-0053 Core set B: lists

Size: M · Depends on: WI-0048, WI-0049 · Blocks: WI-0057

## Goal

The list elements run: `Action_New_List`, `Action_Add_To_List`, `Action_Get_List_Info`, `Condition_List_Contains_Element`, `Action_Delete_from_list`, `Action_Get_index_of_element_in_list`, `Action_Shuffle_list`. Together with WI-0052 this covers the v1 flow "List test". Requirements: REQ-ELM-230 (`Action_Get_from_list` and `Action_Convert_*` stay S0008), REQ-VAR-060.

## Read first

As WI-0052, plus `doc/EXPRESSION-LANGUAGE.md` 18 (object variables as `Map` with `CaseSense := "Off"`, E0028; keys `1` and `"1"`, HOW-TO), REQ-VAR-060 (a list is an object with the keys 1..n, keys ignore case, assigning copies), the v1 list elements and their help texts. The v1 file names are `Add_to_list.ahk` and `Get_list_info.ahk`; the class lookup ignores case (ELEMENT-API 1), so the spelling in a flow does not matter.

## Tasks

1. Port by hand as in WI-0052, tasks 1 and 2. Pay attention to the v1 list model (keys, positions, gaps after a delete, "simple list" versus object with keys) and to the conversion between `Array` and `Map` (ELEMENT-API 3, `SetVar` copies an Array into a `Map` with the keys 1..n).
2. **One implementation of the list logic.** Put the list operations (add, delete, index, contains, info, shuffle) into shared helper functions, not into the element classes: a later method or function of the script language (REQ-SCR-020, REQ-SCR-080) must be able to use the same code. Keep the copy semantics of REQ-VAR-060 in one place (REQ-VAR-150 may later add references).
3. `Action_Shuffle_list`: the test checks the content and the count, not the order; a seed for tests only if the element offers none.
4. e2e tests per element with the flow builder, including lists with gaps, nested objects, empty lists and texts that look like numbers as keys.

## Acceptance criteria

- **Load path (F-0073, README S0002):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- Smoke test and e2e tests green; the v1 flow "List test" (`Flow 1210127300.json`) runs (fixes documented in WI-0057).

## Docs

`doc/MIGRATION.md`, `doc/EXPRESSION-LANGUAGE.md` 18 if the list model is clarified. `doc/REQUIREMENTS.md` (AGENTS rule 12): REQ-ELM-230 (`v2`, `Plan`, table rows, `Evidence`), then `python tools/req_index.py`.

## Not part of this

`Get_from_list` and the conversion between lists and texts (`Convert_list_to_string` and others), all S0008.
