# WI-36 Golden data from v1

Size: M · Depends on: – (starts after WI-34, because it changes `tools/ahkrun.py`) · Blocks: WI-39, WI-43

## Goal

For every expression, every script and every variable substitution that can occur in v1, it is established what v1 actually returns. The data comes from the v1 code itself, run with the v1 interpreter (E23), not from reading the code. It is the yardstick for the converter (WI-39): a converted expression must return the same in v2.

Side result: the list of suspected v1 bugs (README, "Findings") is confirmed or refuted.

## Read first

README of this phase (section S1), `doc/TEST-STRATEGY.md` (L6 characterization), `v1/Source_Common/Variables/*.ahk`, `v1/Source_Execution/Variables/Variables.ahk`, `v1/Lib/Json` (Jxon).

## Tasks

1. **`ahkrun.py` for the v1 interpreter:** option `--interpreter <exe>` (dialog guard and timeout as before). Check whether AutoHotkey_H 1.1.32 understands `/ErrorStdOut=UTF-8` (the suffix `=Encoding` probably only came with 1.1.33, not checked); otherwise use only `/ErrorStdOut` for v1. Never pass unknown options to the interpreter (AGENTS.md).
2. **Harness script `tests/golden/v1/harness.ahk`** (v1 syntax, runs only with `v1/AutoHotKey/AutoHotFlow.exe`): includes the v1 sources read-only via `#Include` (tokenizer, parser, evaluator, `Expression evaluator.ahk`, `Variables.ahk`, `Global variables.ahk`, Jxon). Placeholders for everything these files need from outside: `_EnterCriticalSection`/`_LeaveCriticalSection`, `_getThreadProperty` etc. (with a simple object store and the v1 `parseObjectPath`), `logger`, `lang` (returns keys and arguments), `_WorkingDir` (temp folder per run), `_getFlowProperty`, `_getElementProperty`. No `MsgBox`, no dialogs. The file must not be named `*.test.ahk` (otherwise pytest collects it as a v2 test).
3. **Case format** `tests/golden/cases/*.json`: per case `id`, `kind` (`expression`, `script`, `replace`, `checkname`, `destination`, optional `evalparam`), `text`, initial variables per scope (with type: number, text, object) and, for `evalparam`, the parameter description. **Result format** `tests/golden/expected/*.json`: value, kind of value in v1 (pure number, text, object; determined the way Jxon does it), text form (`"" . value`), error texts from parser and evaluator, variables after the run (assignments!), log lines.
4. **Cases by hand** (checked in), by groups: arithmetic (integer, float, text with number, empty, non-numeric), `/` and `//` (also negative and float), comparisons (number, text, mixed, case, `=` and `==`), `and`/`or`/`not`/`!`/`&&`/`||` (also as value), concatenation (explicit and by space), numbers (negative, decimal, `0x`, `1e3`), strings (escapes, `""`, ` ;` inside the string), variables (all scopes, paths `a.b`, `a[1]`, `a[x]`, `a%i%`, missing variable), assignments (`:=`, `+=`, `.=` ...), function calls (`round`, `object`, `print`, unknown), errors (brackets, empty expressions), script mode (`if`/`else`, blocks, multiple lines, comments).
5. **Corpus from flows:** `tools/golden_corpus.py` collects all parameter values of the elements from flows. The tool roughly reads the content type per `(class, parameter)` from the v1 element files (`Element_getParametrizationDetails_*`, entries with `content:`); unclear cases (user-selectable content type via `contentID`, not found) run as expression **and** as substitution. Variables that an expression reads get plausible initial values (number and text as two cases). Example flows from `v1/AppData/Saved Flows` → checked in. Private flows and variables of the project owner (E27) → `tests/golden/private/`, entry in `.gitignore`, never checked in.
6. **Tool and task:** `tools/golden_v1.py` generates the results from the cases. Generation only on purpose (task `Testdaten: Goldendaten aus v1 erzeugen`, a second one for the private data), not in every test run. The results are checked in; every change is visible in the diff.
7. **List of findings:** In the result of this file, for each suspected v1 bug from the README: confirmed / refuted, with case ID. Also what the corpus shows: which operators and patterns occur in real flows, which cases already fail in v1.

## Acceptance criteria

- `python tools/golden_v1.py` generates the results reproducibly (generated twice → no diff, except for time values such as `A_Now`, which are marked as such).
- At least the groups from task 4 have cases, plus all expressions and substitutions of the example flows.
- A test in pytest checks that every case file has a result and that the format is correct (the comparison with v2 comes in WI-39).
- No dialog, no file outside the temp folder and of `tests/golden/`, nothing in `v1/` changed.

## Documentation

`doc/TEST-STRATEGY.md` (L6: location, generation, private data), `AGENTS.md` (tool, `--interpreter`), `.vscode/tasks.json` (rule 10), `doc/HOW-TO.md` (experiences with the v1 interpreter).

## Not part of this package

Comparison with v2 (WI-39), running v1 elements.
