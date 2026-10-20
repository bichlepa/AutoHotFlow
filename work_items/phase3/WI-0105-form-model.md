# WI-0105 Form model and the `form` API (headless)

Size: L · Depends on: – · Blocks: WI-0106, WI-0107

## Goal

The settings of an element exist as a model without a window. The model is built from the parameter schema of the class, filled with the parameters of the element, and checked by the element while the user edits. It gives back the parameters and the name. Requirements: REQ-EDT-120 (the model part), REQ-ELM-010 (the editor part).

## Read first

`AGENTS.md`; `doc/ELEMENT-API-V2.md` 2, 3; `src/elements/base/AhfElement.ahk`, `src/elements/base/ParamEvaluator.ahk` (field types, content types); the 13 classes with `CheckSettings` (e.g. `Action_Add_To_List`); v1: `v1/Source_Editor/User Interface/Element settings.ahk` (the fields, `fieldWithContentType`, the name field, the call of `CheckSettings` with `staticValues`), `v1/Source_Editor/API/API for Elements.ahk` (lines 319 to 355).

## Tasks

1. **Docs first:** ELEMENT-API-V2 3 gets the `form` API (`Enable`, `Disable`, `SetValue`, `GetValue`, `SetChoices`, `SetLabel`, `FirstCall`, mapped to the v1 names `x_Par_*` and `x_FirstCallOfCheckSettings`), and section 2 the field types and their keys as in v1 (`id`, `type`, `label`, `default`, `content`, `contentID`, `contentDefault`, `choices`, `result`, `enum`, `WarnIfEmpty`, `size`, ...). ARCHITECTURE 8 gets the folder of the settings code in `src/editor/`.
2. **`ElementForm`:** the fields of all 15 v1 types plus the name field. Values come from the element's `pars`, defaults fill the missing ones. An edit field has a content type, fixed or chosen by `contentID`. The model holds the enabled state, labels and choices of every field. Type names are compared without regard to case (the core set writes `edit` and `Edit`, `multiLineEdit` and `multilineEdit`).
3. **`CheckSettings`** runs at the start (`FirstCall` true once) and after every change of a value; `staticValues` lives as long as the dialog. An exception of the element becomes a warning of the form plus a log line, and the form goes on (rule 8).
4. **Checks:** `WarnIfEmpty`, variable names (the rules of the expression language), the number content types. They are warnings, not refusals (v1 warned).
5. **Result:** the parameters as a Map in the types the file uses, and the name: with `StandardName` it comes from `GenerateName` under `try/catch`, otherwise it is the user's name.
6. **Test class** with every field type in the test package (`tests/elements/Test/`).
7. **Tests** (AHK unit):
   - Every core element: the form opens with its defaults, and `CheckSettings` runs without an error for the defaults and for every choice of its radio and drop-down fields.
   - The round trip `pars` → form → `pars` gives the same parameters.
   - The test class covers all field types.
   - An element that throws in `CheckSettings` gives a warning, and the form goes on.

## Acceptance criteria

- The tests of task 7 are green. ELEMENT-API-V2 is updated. REQ-EDT-120 is updated (model part).

## Not part of this

The window (WI-0106); the editor `ctx` for other flows (WI-0107); the expression check while typing (WI-0108); the assistants (WI-0110).
