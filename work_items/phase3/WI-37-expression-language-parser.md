# WI-37 Expression language v2: specification, tokenizer, parser

Size: M · Depends on: – · Blocks: WI-38, WI-39

## Goal

The new expression language is described and can be parsed. It follows AHK v2 (E22), as far as the language feature makes sense in AutoHotFlow, and has two forms: **expression** (one value, for parameters) and **script** (several statements, for `Action_Script` and similar; v1: `var_evaluateScript`).

## Read first

README of this phase (S1, decisions E22 to E25, open questions 1 to 3 and 6), `v1/Source_Common/Variables/Code tokenizer.ahk` and `Code parser.ahk` (as a starting point for the language scope, not as a template for the semantics), AHK v2 documentation `Variables.htm` (operators, precedence).

## Tasks

1. **Specification `doc/AUSDRUECKE.md`** (new permanent document): literals (integer, float, `0x`, exponent; strings in `"..."` and `'...'` with escape character `` ` `` as in AHK v2), variable names (character rules as in v1, `Var_CheckName`), paths (`a.b`, `a[expression]`, `a%i%` as dynamic name), operators with precedence (at least: `+ - * / //`, unary `-`, `! not`, `&& and`, `|| or`, `= == != !==`, `< > <= >=`, `.` and concatenation by space, brackets, assignments `:= += -= *= /= .=`), function calls (list of built-in functions: initially those from v1, `round`, `object`, `print`, plus whatever the converter needs), script form (`if`/`else`, blocks `{}`, lines as statements, comments `;`). What is deliberately missing (e.g. `%` as modulo, ternary `?:`, `**`): as a list with "possible later". A section "Differences from AHK v2" (the own rules from WI-38) and a section "Differences from v1 and conversion" (filled by WI-39).
2. **Location:** new library module `src/expr/` (ARCHITECTURE 8: folder = role or library). No GUI, no file I/O, includes only `src/core/`. Editor (syntax check), engine and worker may use it.
3. **Tokenizer** and **parser** (recursive descent or precedence parser) in v2, one class per file. The result is an AST made of `Map`s with a fixed schema (described in the document: node types, fields, position). Errors with line, column and the line with a marker (like v1 `wholelinehighlighted`), collect several errors, never throw except for internal errors.
4. **Parse cache:** the engine evaluates the same parameter texts over and over. A cache text → AST (upper limit, e.g. 2000 entries, oldest removed) with measurement: parsing a typical expression without and with cache.
5. **L1 tests** `tests/ahk/expr_*.test.ahk`: every rule from the specification, precedence, error positions, empty input, very long input, Unicode in names and strings.

## Acceptance criteria

- `doc/AUSDRUECKE.md` describes the language completely enough that the editor (S7) and a human can use it without reading the code.
- All expressions and scripts of the golden data (WI-36) that v1 parses without errors are also parsed by the new parser **after conversion** (WI-39); the check for this lies in WI-39.
- Architecture checker green, one class per file.

## Not part of this package

Evaluation (WI-38), conversion (WI-39).
