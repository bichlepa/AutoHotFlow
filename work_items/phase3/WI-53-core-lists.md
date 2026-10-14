# WI-53 Core set B: lists

Size: M · Depends on: WI-48, WI-49 · Blocks: WI-57

## Goal

The list elements run: `Action_New_List`, `Action_Add_To_List`, `Action_Get_List_Info`, `Condition_List_Contains_Element`, `Action_Delete_from_list`, `Action_Get_index_of_element_in_list`, `Action_Shuffle_list`. Together with WI-52 this covers the v1 flow "List test".

## Read first

As WI-52, plus `doc/EXPRESSION-LANGUAGE.md` 18 (object variables as `Map` with `CaseSense := "Off"`, E28; keys `1` and `"1"`, HOW-TO), the v1 list elements and their help texts.

## Tasks

1. Port by hand as in WI-52, tasks 1 and 2. Pay attention to the v1 list model (keys, positions, gaps after a delete, "simple list" versus object with keys) and to the conversion between `Array` and `Map` (ELEMENT-API 3, `SetVar` copies an Array into a `Map` with the keys 1..n).
2. `Action_Shuffle_list`: the test checks the content and the count, not the order; a seed for tests only if the element offers none.
3. e2e tests per element with the flow builder, including lists with gaps, nested objects, empty lists and texts that look like numbers as keys.

## Acceptance criteria

- Smoke test and e2e tests green; the v1 flow "List test" (`Flow 1210127300.json`) runs (fixes documented in WI-57).

## Docs

`doc/MIGRATION.md`, `doc/EXPRESSION-LANGUAGE.md` 18 if the list model is clarified.

## Not part of this

Conversion between lists and texts (`Convert_list_to_string` and others, S8).
