# WI-39 Conversion of old expressions (converter)

Size: L · Depends on: WI-36, WI-37, WI-38 · Blocks: WI-42, WI-43

## Goal

A v1 expression (or v1 script) is converted into the new language, so that it returns the same result in v2 as in v1 (E22). Where that is not possible, the deviation is known, documented and justified. The conversion runs automatically when old flows are loaded.

## Read first

README of this phase (S1, E21, E22, E29 to E32), `doc/AUSDRUECKE.md` (WI-37), result of WI-36 (list of findings), ARCHITECTURE 7 (flow file format).

## Tasks

1. **Deviation catalog first:** a pytest test evaluates every golden data case unchanged with the new evaluator and compares with v1. Every deviation gets a class (e.g. "number format", "type error", "text comparison", "v1 error", "comment in string"). Result: a table in the section "Differences from v1 and conversion" in `doc/AUSDRUECKE.md`, per class: example, v1, v2, handling (rewrite, accept, do not reproduce v1 errors). **This table is the first result of the package** and goes to the project owner for review before the rewrite rules are built.
2. **Converter** `src/expr/` (e.g. `V1ExprConverter`): parses the v1 text with the v1 rules (its own small v1 parser or tokenizer variant; the v1 peculiarities that determine the result, such as concatenation by space and cutting off at ` ;`, belong to it) and writes text in the new language. Rewrite only as much as necessary; the output text should remain readable for humans. If a text cannot be converted (already a parse error in v1, E22), it stays unchanged, and the converter reports it.
3. **Rewrite rules** from the catalog. Known candidates (to be confirmed): reproduce the cut-off at ` ;`; number literals whose text form v1 passes on as text (`1.50`); `//` with negative or float operands, if v1 rounds down. Not rewritten (decided, entries in MIGRATION instead): `/` (E29), text comparisons with `<` and the like (E30), `&&`/`||` as value (E31), the text form of floats (E32).
4. **Check against the golden data:** for each case: `v2(convert(text))` against `v1(text)`. Comparison: same value; numbers numerically (so that `2.000000` and `2` are equal, text form per E24 and E32); deviations only with a class from the catalog that says "accept". Applies to the checked-in cases (full run) and locally to the private ones (own task).
5. **Convert on load (design to be fixed in the package, proposal):**
   - Only the element class knows which parameters are expressions (`Parameters()`: `content`, `contentID`). The converter therefore runs in the engine on load, using the registry. Parameters that the element itself evaluates as an expression or script (v1: `x_EvaluateExpression`/`x_EvaluateScript` on a `RawString`, e.g. `Action_Script`) are reported by the class via a property (e.g. `static V1Syntax := Map("Script", "script")`).
   - **Marker in the flow:** the flow file gets a format version at the root. An element whose class is unknown on load (in S1 to S7 most of them, E20) keeps its v1 texts and a marker per element, so that it is converted as soon as the class is available, even if v2 has meanwhile saved the flow. Without this marker, v1 texts would remain unconverted forever after the first save.
   - The text `%var%` in `String` parameters is not expression syntax and stays unchanged.
   - Every conversion is in the log (`f2`: flow, element, parameter, old, new), so that the project owner can follow it.
6. **Test elements:** in `src/elements/skeleton/` an element with one parameter of each content type (also used by WI-42), so that loading with conversion can be checked end to end.

## Acceptance criteria

- Catalog exists and has been reviewed by the project owner.
- All checked-in golden data cases: same result or a deviation of an "accept" class. Private cases locally likewise (result as a number in the package report, no content).
- e2e: a v1 flow with the test element is loaded, converted, saved, loaded again: no double conversion, element with unknown class keeps text and marker.
- Conversion is checked for idempotence (an already converted flow does not change on load).

## Documentation

`doc/AUSDRUECKE.md` (conversion), `doc/ARCHITECTURE.md` 7 (format version, marker; E21), `doc/MIGRATION.md` (one entry per accepted class), `doc/ELEMENT-API-V2.md` (property for self-evaluated parameters).

## Not part of this package

Import UI and data folder change (S4), conversion of the real element classes (comes with each class in S2/S8 via its `Parameters()`).
