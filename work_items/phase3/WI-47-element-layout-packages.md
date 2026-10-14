# WI-47 Element layout per package, generated include block

Size: M · Depends on: WI-46, WI-42 · Blocks: WI-48, WI-51, all core-set packages

## Goal

Real elements have their place: `src/elements/<package>/` (E37), an include block generated per package, the test elements only in the test entry point. `Action_Sleep` and `Trigger_Manual` move to `Default` with the parameters of v1.

## Read first

README of this phase (E35, E37), result of WI-46, `doc/ELEMENT-API-V2.md` 1, 2, 7 and 8, `doc/ARCHITECTURE.md` 8, `src/AhfBoot.ahk`, `tests/integration/helpers/AutoHotFlowTest.ahk`, `src/elements/`, `v1/Source_Elements/Default/` (folders `language`, `Icons`, `help`), `tools/arch_check.py`.

## Tasks

1. **Layout:** `src/elements/base/` stays; `src/elements/Default/` with the subfolders `Actions`, `Conditions`, `Loops`, `Triggers` (as in v1) and a package description (name, version as in v1, so that `package`/`packageVersion` of flows can be checked). If WI-46 asks for a split, follow the decision of the project owner.
2. **Generated include block:** `tools/gen_element_includes.py` writes one file per package (for example `src/elements/Default/_includes.ahk`) that `AhfBoot.ahk` includes. A check (arch check or test) fails when the block does not match the files. Rule in `doc/CONVENTIONS.md`: the block is never edited by hand.
3. **Test elements out of the product:** `Action_Test*` move to `tests/`, are included only by the test entry point, and register in the same way. A test checks that the product entry knows no `Action_Test*` class.
4. **Language and icons of the package:** the language files of the elements (`v1/Source_Elements/Default/language/*.ini`) are copied unchanged to the package; `Lang()` (WI-42) finds keys of the package. The icons go to the package (`static Icon`).
5. **`Action_Sleep` and `Trigger_Manual`** to `Default`, with the parameters, `GenerateName` and language keys of v1 (`Sleep` as in ELEMENT-API 4). Old flows with these classes load and run as before.
6. **Elements of unknown packages:** a flow with an element of another package (for example the dropped Chrome package) loads; the element is marked as unknown (as `v1Text`), runs into `exception` with a clear message, and is written back unchanged.
7. VS Code task `Tool: generate element include blocks`.

## Acceptance criteria

- **Load path (F-268, README S2):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- All tests green, including those that use the test elements (now from `tests/`).
- A stale include block fails the check.
- `Lang()` returns the texts of the element language files (test with a key of `Default`).

## Docs

`doc/ELEMENT-API-V2.md` 2 (registration, include block per package) and 8, `doc/ARCHITECTURE.md` 8, `doc/CONVENTIONS.md`, `.vscode/tasks.json`.

## Not part of this

The core-set elements, help texts in the editor (S7).
