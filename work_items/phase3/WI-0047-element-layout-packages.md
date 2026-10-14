# WI-0047 Element layout per package, generated include block

Size: M · Depends on: WI-0047-PREP, WI-0046, WI-0042 · Blocks: WI-0048, WI-0051, all core-set packages

## Goal

Real elements have their place: `src/elements/<package>/` (E0037), an include block generated per package, the test elements only in the test entry point. `Action_Sleep` and `Trigger_Manual` move to `Default` with the parameters of v1.

## Read first

README of this phase (E0035, E0037), result of WI-0046, `doc/ELEMENT-API-V2.md` 1, 2, 7 and 8, `doc/ARCHITECTURE.md` 8, `src/AhfBoot.ahk`, `tests/integration/helpers/AutoHotFlowTest.ahk`, `src/elements/`, `v1/Source_Elements/Default/` (folders `language`, `Icons`, `help`), `tools/arch_check.py`.

## Tasks

1. **Layout:** `src/elements/base/` stays; `src/elements/Default/` with the subfolders `Actions`, `Conditions`, `Loops`, `Triggers` (as in v1) and a package description (name, version as in v1, so that `package`/`packageVersion` of flows can be checked). The role entries and the split per role are made in WI-0047-PREP (E0041); this package builds on them.
2. **Generated include block:** `tools/gen_element_includes.py` writes the include blocks per package and per role (E0041, for example `src/elements/Default/_includes.ahk` for the package and the role of the engine), which the role entry scripts include. A check (arch check or test) fails when the block does not match the files. Rule in `doc/CONVENTIONS.md`: the block is never edited by hand.
3. **Test elements out of the product:** `Action_Test*` move to `tests/`, are included only by the test entry point, and register in the same way. A test checks that the product entry knows no `Action_Test*` class.
4. **Language and icons of the package:** the language files of the elements (`v1/Source_Elements/Default/language/*.ini`) are copied unchanged to the package; `Lang()` (WI-0042) finds keys of the package. The icons go to the package (`static Icon`).
5. **`Action_Sleep` and `Trigger_Manual`** to `Default`, with the parameters, `GenerateName` and language keys of v1 (`Sleep` as in ELEMENT-API 4). Old flows with these classes load and run as before.
6. **Elements of unknown packages:** a flow with an element of another package (for example an extension package that is not installed) loads; the element is marked as unknown (as `v1Text`), runs into `exception` with a clear message, and is written back unchanged.
7. VS Code task `Tool: generate element include blocks`.

## Acceptance criteria

- **Load path (F-0282, README S0002):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- All tests green, including those that use the test elements (now from `tests/`).
- A stale include block fails the check.
- `Lang()` returns the texts of the element language files (test with a key of `Default`).

## Docs

`doc/ELEMENT-API-V2.md` 2 (registration, include block per package) and 8, `doc/ARCHITECTURE.md` 8, `doc/CONVENTIONS.md`, `.vscode/tasks.json`.

## Not part of this

The core-set elements, help texts in the editor (S0007).
