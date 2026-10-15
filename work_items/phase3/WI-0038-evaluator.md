# WI-0038 Evaluator of the new language

Size: M · Depends on: WI-0037 · Blocks: WI-0039, WI-0040, WI-0042

## Goal

An AST from WI-0037 is evaluated. The operators compute with AHK v2 (E0022), with a few own, documented rules. The evaluator never throws because of a user error: runtime errors are collected and logged.

## Read first

README of this phase (E0022, E0024, E0025, E0029 to E0032), `doc/EXPRESSION-LANGUAGE.md` (WI-0037), `v1/Source_Common/Variables/Code evaluator.ahk`.

## Tasks

1. **Variable access via an interface** (`resolver.Get(path)`, `Set(path, value)`, `Has(path)`; `path` is an array of the evaluated parts). For the tests a simple resolver; the real one comes from WI-0040. This keeps the evaluator free of engine code.
2. **Operators** with the v2 operators, wrapped in `try`: a `TypeError` (e.g. `"" + 1`) yields `""`, an `f1` log via a callback function (E0025) and an entry in the warnings of the result. Likewise division by zero (AHK v2 throws `ZeroDivisionError`, verified); what v1 returns here is shown by the golden data.
3. **Rules** (one line each in `doc/EXPRESSION-LANGUAGE.md`, "Differences from AHK v2"; decided 2026-10-13):
   - `/` with two integers that divide exactly returns an integer (E0029). This is the only own rule; everything else is AHK v2.
   - `<`, `>`, `<=`, `>=` as in AHK v2 (E0030): a non-numeric text operand throws a `TypeError`, which by E0025 gives `""` and an `f1` log.
   - `&&`/`||` return the operand as in AHK v2 (E0031).
   - Text form of floats as in AHK v2, no own formatting (E0032): `0.1+0.2` gives `0.30000000000000004`.
4. **Missing variable:** as in v1 an empty value and a log (v1: `f0` "Retrieving variable ... failed. It does not exist"); whether this is a warning in the result is decided by the caller (WI-0042).
5. **Functions** from the list in `doc/EXPRESSION-LANGUAGE.md`, via a table name → function (extensible), unknown function = error with position. `object()` returns a `Map` with `CaseSense := "Off"` (E0028). `print` goes to the log.
6. **Script form:** statements in order, `if`/`else`, blocks; return of the last value as in v1.
7. **Result object:** `{value, errors, warnings}`; errors with line, column, text. No exception to the outside except for internal errors (which `Role._OnUnexpected` reports).
8. **L0001 tests** per operator and rule, with the values from the table "Behavior of AHK v2" in the README as a cross-check.

## Acceptance criteria

- Every rule in `doc/EXPRESSION-LANGUAGE.md` has a test.
- No user expression makes the evaluator throw (test with all golden data texts, including those that fail in v1).
- Runtime: a typical parameter expression (variable, arithmetic, comparison) takes on average under 0.2 ms with parse cache (measure and record in the result; the engine must not block, ARCHITECTURE 2.3).

## Not part of this package

Variable scopes (WI-0040), conversion (WI-0039).
