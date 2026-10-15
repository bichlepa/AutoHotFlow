# WI-0044 Oracle of the expression language: native AHK v2

Size: M · Depends on: WI-0038 · Blocks: WI-0058

## Goal

The expression language gets an independent yardstick (E0035): generated expressions run once as real AHK v2 code and once in the evaluator (`src/expr/`), and the results may differ only by a fixed list of deliberate deviations. The v1 golden data of WI-0036 is frozen and stays as a regression test of the converter.

## Read first

README of this phase (E0022, E0025, E0029 to E0035), `doc/EXPRESSION-LANGUAGE.md` (all, in particular the differences to AHK v2 and section 17), `doc/TEST-STRATEGY.md` 6 and 7, `tests/golden/test_golden_v2.py`, `tests/golden/v2/harness.ahk`, `tools/golden_compare.py`.

## Tasks

1. **Subset.** List which parts of the language are valid AHK v2 code (operators, literals, function calls, assignments, objects/`Map`) and which are not (own rules such as E0029, dot paths into variables such as `list.1`, built-in variables of AutoHotFlow, the script form). Only the first part is compared with native AHK v2; the second part keeps its specification tests. The list goes into `doc/EXPRESSION-LANGUAGE.md`.
2. **Generator** (`tools/expr_oracle.py` or `tests/oracle/`): builds expressions from the grammar with a seed (reproducible), with initial variables (numbers, texts that look like numbers, empty text, `Map`), nesting, mixed types and edge values (`0x10`, `1e3`, `" 5 "`, very large integers, `-0`, division by zero). Inspired by the expressions of the example flows (`tests/golden/cases/corpus_flows.json`), but much wider.
3. **Native side:** the generator writes an AHK v2 script in which each case is a function with the variables as locals, wrapped in `try/catch`; the output per case is the type (`Type()`), the text form and the error class. It runs through `tools/ahkrun.py` in batches.
4. **Evaluator side:** the same cases with the same variables through the evaluator (in compatibility mode and in strict mode, E0034), via the existing v2 harness or an own one.
5. **Comparison** with a fixed, named list of deliberate deviations: E0025 (type error gives `""` in compatibility mode; in strict mode an element error, which must match the native `TypeError`), E0029 (exact division of two integers gives an integer), plus the deviations that task 1 finds. A deviation without an entry fails the test.
6. **Tiers:** a fixed corpus (checked in, a few thousand cases) runs in the fast tier; budget: measure, target under 10 s. A longer run with a random seed is marked `slow` or is a tool (`--seed`, `--count`); a failing seed is printed so that it can be reproduced.
7. **Freeze the v1 golden data:** `tools/golden_v1.py` and `tests/golden/test_golden_v2.py` stay as they are (regression test of the converter); no new groups or cases against v1. State this in `doc/TEST-STRATEGY.md` section 7 and in the docstring of the tools.
8. VS Code tasks (AGENTS rule 10): `Test: expression oracle (fixed corpus)`, `Tool: expression oracle with random seed`.

## Acceptance criteria

- The fixed corpus agrees with native AHK v2, except for the listed deviations; every deviation class has at least one case.
- A random run of at least 20,000 cases shows no deviation without an entry. Every finding is either fixed or recorded in `doc/OPEN-ITEMS.md`.
- The fast tier still runs in its time budget (state the measured time in the result).

## Docs

`doc/EXPRESSION-LANGUAGE.md` (subset and list of deliberate deviations), `doc/TEST-STRATEGY.md` 7 (frozen) and new section 8 (oracle), `.vscode/tasks.json`.

## Not part of this

Elements, the converter (unchanged), new v1 golden data.
