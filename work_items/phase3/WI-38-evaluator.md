# WI-38 Evaluator of the new language

Size: M · Depends on: WI-37 · Blocks: WI-39, WI-40, WI-42

## Goal

An AST from WI-37 is evaluated. The operators compute with AHK v2 (E22), with a few own, documented rules. The evaluator never throws because of a user error: runtime errors are collected and logged.

## Read first

README of this phase (E22, E24, E25, open questions 1 to 3 and 6), `doc/AUSDRUECKE.md` (WI-37), `v1/Source_Common/Variables/Code evaluator.ahk`.

## Tasks

1. **Variable access via an interface** (`resolver.Get(path)`, `Set(path, value)`, `Has(path)`; `path` is an array of the evaluated parts). For the tests a simple resolver; the real one comes from WI-40. This keeps the evaluator free of engine code.
2. **Operators** with the v2 operators, wrapped in `try`: a `TypeError` (e.g. `"" + 1`) yields `""`, an `f1` log via a callback function (E25) and an entry in the warnings of the result. Likewise division by zero (AHK v2 throws `ZeroDivisionError`, verified); what v1 returns here is shown by the golden data.
3. **Own rules** (one line each in `doc/AUSDRUECKE.md`, "Differences from AHK v2"), subject to the open questions:
   - `/` with two integers that divide exactly returns an integer (question 1).
   - `<`, `>`, `<=`, `>=` compare text alphabetically, case-insensitive, if one operand is not a number (question 2; AHK v2 throws here).
   - `&&`/`||` return the operand as AHK v2 does (question 3).
   - Text form of floats (question 6): AHK v2 writes `0.1+0.2` as `0.30000000000000004` and `1/3` as `0.33333333333333331` (verified). Proposal: at most 15 significant digits, trailing zeros removed, an integer-valued float keeps `.0`.
4. **Missing variable:** as in v1 an empty value and a log (v1: `f0` "Retrieving variable ... failed. It does not exist"); whether this is a warning in the result is decided by the caller (WI-42).
5. **Functions** from the list in `doc/AUSDRUECKE.md`, via a table name → function (extensible), unknown function = error with position. `object()` returns a `Map` with `CaseSense := "Off"` (E28). `print` goes to the log.
6. **Script form:** statements in order, `if`/`else`, blocks; return of the last value as in v1.
7. **Result object:** `{value, errors, warnings}`; errors with line, column, text. No exception to the outside except for internal errors (which `Role._OnUnexpected` reports).
8. **L1 tests** per operator and rule, with the values from the table "Behavior of AHK v2" in the README as a cross-check.

## Acceptance criteria

- Every rule in `doc/AUSDRUECKE.md` has a test.
- No user expression makes the evaluator throw (test with all golden data texts, including those that fail in v1).
- Runtime: a typical parameter expression (variable, arithmetic, comparison) takes on average under 0.2 ms with parse cache (measure and record in the result; the engine must not block, ARCHITECTURE 2.3).

## Not part of this package

Variable scopes (WI-40), conversion (WI-39).
