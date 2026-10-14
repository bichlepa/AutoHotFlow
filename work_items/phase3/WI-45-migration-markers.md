# WI-45 Migration markers with MIGRATION ID and v1 original

Size: S · Depends on: WI-39 · Blocks: WI-57

## Goal

Every place of a loaded v1 flow that the loader cannot convert, or that behaves differently in v2, is marked with the ID of its MIGRATION entry, and the v1 original is kept (E35). This is the interface for a later AI-assisted import ("here is the list of changes, adapt the flow") and for the manual fixes that E35 allows. A report lists these places per flow.

## Read first

README of this phase (E21, E35), `doc/ARCHITECTURE.md` 7 (format version, `v1Text`, `strictTypes`), `doc/EXPRESSION-LANGUAGE.md` 15 (deviation catalog, conversion, unsupported syntax), `doc/MIGRATION.md`, `src/engine/core/FlowExprConvert.ahk`, `src/expr/V1ExprConverter.ahk`, `tools/golden_classes.py`.

## Tasks

1. **Mapping class → MIGRATION ID.** Each class of the deviation catalog (EXPRESSION-LANGUAGE 15.1) with the handling "accept" or "unsupported" gets the ID of its MIGRATION entry (new entries where one is missing). The mapping lives in one place in `src/` and is checked by a test against `tools/golden_classes.py`.
2. **Detection in the converter:** for each converted parameter, the converter reports which classes can apply to the text (as far as it can see that from the text: `<` with a text operand, `&&` as a value, unsupported syntax, ...). Where it cannot decide from the text, it reports nothing; no guessing.
3. **Marker in the flow:** an element with at least one such place gets a key (proposal: `migration`, a list of `{par, ids, v1}` with the parameter id, the MIGRATION IDs and the original v1 text). It is written when the flow is saved and stays until the place is resolved (resolving is S6/S7 or the AI import; here only the data). An element whose class is unknown keeps `v1Text` as before. Unknown keys are kept (ARCHITECTURE 7).
4. **Report:** `python tools/migration_report.py <flow file or folder> [--json]` lists per flow: elements with unknown class, places with MIGRATION IDs and the v1 text. The information comes from the converter in `src/` (run through `tools/ahkrun.py`), not from a second implementation in Python.
5. VS Code task `Tool: migration report of a flow folder`.

## Acceptance criteria

- **Load path (F-282, README S2):** `tests/stress/test_big_flows.py` was run at the end; the time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.
- For every example flow in `tests/data/flows/` the report runs without error; counts in the result (not the private flows, only their counts, E27).
- Load, save, load: the markers are stable, a converted text is not converted twice, the v1 original is unchanged.
- A test per marker kind (unknown class, accepted deviation, unsupported syntax).

## Docs

`doc/ARCHITECTURE.md` 7 (new key), `doc/MIGRATION.md` (IDs where missing), `.vscode/tasks.json`.

## Not part of this

Resolving a marker (editor, AI), the import UI (S4).
