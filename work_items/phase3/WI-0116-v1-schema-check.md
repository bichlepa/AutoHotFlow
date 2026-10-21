# WI-0116 Check of the parameter schema against v1

Size: S · Depends on: – · Blocks: WI-0118 to WI-0133 (they use the check), WI-0135

## Goal

A ported class keeps the parameter IDs, field types, defaults, choices and enum values of v1, because the saved flows store them (ELEMENT-API-V2 7). Without a converter (E0102) a port by hand can miss a parameter or change a default unnoticed. A check compares the schema of every registered class with the schema of its v1 class and reports each difference; a known, deliberate difference is listed with its MIGRATION ID.

## Read first

`AGENTS.md`; `doc/ELEMENT-API-V2.md` 2.1, 7; `doc/TEST-STRATEGY.md` 7 (how `tools/golden_v1.py` runs v1 code in the v1 interpreter); `tools/golden_v1.py`, `tools/ahkrun.py` (`--interpreter`); `tests/ahk/element_smoke.test.ahk`; v1: `Element_getParametrizationDetails_*` of a few elements, `v1/Source_Elements/Default/common/`.

## Tasks

1. **v1 side:** a script for the v1 interpreter (`v1/AutoHotKey/AutoHotFlow.exe` through `ahkrun.py --interpreter`) includes the v1 element files with stubs for the `x_*` functions they call while building the schema (`x_lang` returns its key, `x_GetMyFlowID` a fixed text, ...) and writes, per class, the result of `Element_getParametrizationDetails_<class>` as JSON. The output is committed as test data (`tests/data/v1_schema.json`) and regenerated only on purpose (VS Code task `Testdata: ...`), as the golden data. Do not change anything in `v1/`.
2. **v2 side:** an AHK unit test or a small script writes the same for every registered class (`Parameters("")`, labels as keys where `Lang` allows it).
3. **Compare:** a pytest test compares the two per class: the set of `id`s, and per id the `type` (without case), `default`, `content`, `contentID`, `choices`/`enum`/`result`. A class that v2 does not have yet is skipped; a difference that is deliberate is in an allow list in the test with its MIGRATION ID; every other difference fails with class and id.
4. **The core set:** run the check on the 34 classes that exist; each difference found is either fixed (a wrong id or default is a bug) or entered in the allow list with a MIGRATION entry.
5. Entries in `tests/support/group_table.py`; a VS Code task for the regeneration.

## Acceptance criteria

- The test of task 3 is green for the core set; the allow list has a MIGRATION ID for every entry. `doc/TEST-STRATEGY.md` says how the check works and how a package uses it.

## Not part of this

Comparing the behaviour (`Run`) with v1 (E0035: v1 is not the yardstick).
