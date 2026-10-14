# Phase 3: v1 feature scope in the new architecture, plan

Status: 2026-10-13, plan of the project owner with Claude. Branch `v2-port`. Located in `work_items/phase3/` (temporary, delete after the port). **Phase 3 is approved by the project owner (2026-10-13).**

Basis: Phase 2 (walking skeleton), Phase 2b (hardening) and the fix block up to WI-34. What already exists: processes, IPC, supervisor, storage, engine with state machines and latest revision, worker pool, diagnostics, debug window, skeleton elements. What is missing: see `work_items/HANDOVER.md`, "Offene Punkte" (Open points).

## Goal of the phase

AutoHotFlow v2 can do everything v1 can: load flows (including old v1 flows), edit them, run them, triggers, all elements, manager, editor. Afterwards (Phase 4) debugger, compilation and installer follow.

## Guiding principles

1. **Vertical steps.** Each step ends with something that runs and is tested, and brings the engine commands it needs.
2. **Test early.** The element scope stays small until the editor is finished. This way the project owner can try things out by hand early. The remaining elements come in S8.
3. **Measure risky things early** (R3 in S2, R2 in S5), before much code relies on them.
4. **v1 stays in everyday use until v2 is finished.** v2 only needs to be able to **read** old flows and variables. What v2 writes is free (E21). v2 works in its own data folder; old data comes in through an import (S4).

## Procedure per step

Each step is worked through individually: **detail** (package files WI-xx with tasks and acceptance criteria), **decide** (questions for the project owner, numbers from E18 onward), **implement**, **test** (acceptance run serial, parallel, stress), then the next step. Only the next step is detailed at any time; the others stay rough so that findings can flow in.

## Steps

| # | Step | Content (rough) | Acceptance | Status |
|---|---|---|---|---|
| **S1** | Expressions and variables | new expression language (AHK v2 semantics), conversion of old expressions, golden data from v1, variable model, `global`/`static` permanent, parameter evaluation | see below, packages WI-36 to WI-43 | implemented, acceptance open (F-268) |
| S2 | Element foundation and core set | `elements/default/`, generated include block per role, R3 measurement (parse time, memory), converter `tools/convert_element.py`, R4 (`ctx.Request`, variables in the worker), L1 smoke test per element (`Parameters`, `GenerateName`). Core set: few elements per kind, enough to try things out (e.g. set variable, condition, loops, sleep, message, start flow) | core set runs headless, smoke tests green | rough |
| S3 | Trigger host and a few triggers | role `triggerhost` (WI-14), `cmd.trigger.arm/disarm`, `evt.trigger.fired/error`, re-arming after engine restart, activate/deactivate flow. Triggers: Manual, Hotkey, Periodic_Timer, Start_up | trigger e2e and fault tests | rough |
| S4 | UI foundation and manager | `ui_common/`, manager (category tree, start/stop/activate, new/rename/delete/duplicate, settings, log display, hints), **import from v1** (flows, variables), `.ahf` export/import, engine commands `cmd.flow.create/delete/meta.update`, `cmd.category.*`, `cmd.settings.*`. Closing the window only hides it (E14) | operation by hand, e2e of the commands | rough |
| S5 | Editor I: display | `Renderer`/`Scene`, GDI+ in v2, zoom, panning the view, live states, resync | R2 measurement (300 elements, under 16 ms per frame), memory with 5 editors | rough |
| S6 | Editor II: editing | selection, moving, connecting, copy/paste, undo/redo, patch operations, `baseRev` conflict, saving, prompt when quitting | e2e: editing during execution (E1) | rough |
| S7 | Editor III: settings dialogs | parameter schema to GUI, `form` API for `CheckSettings`, flow settings, wizards (window info, color, mouse), help | every element of the core set editable | rough |
| S8 | Remaining elements | in groups: dialogs/worker, file/drive/process/internet/power/sound, window/user simulation/image, unsafe elements (AHK script, DllCall, TTS, Eject, Monitor, screen, input block), remaining triggers | the v1 flows of the category "Automatic tests" run green | rough |
| S9 | Phase 3 completion | overall acceptance, equality list with v1, performance budgets, documents, scope of Phase 4 | serial, parallel, stress green | rough |

Not in Phase 3 (E19): debugger (do not block the execution gate, ARCHITECTURE 4.3), compilation and installer (R7), Chrome package (dropped).

## Decisions of the project owner (2026-10-12)

| # | Decision | Affects |
|---|---|---|
| E18 | Order: runtime first (S1 to S3), then manager before editor. | Plan |
| E19 | Debugger, compilation and installer are not part of Phase 3. | Plan |
| E20 | Element scope stays small (core set) until the editor is finished; the remaining elements come in S8. | S2, S8 |
| E21 | **File format:** v2 must be able to load old flows and variables; how v2 saves is free. v2 works in its own data folder, old data comes in via import (later possibly also an automatic backup at the switchover). Replaces the requirement "format stays" from D11/E8 for writing. | S1, S4 |
| E22 | **No reproduction of the v1 expression evaluation.** The new expression language follows AHK v2. Old expressions are converted on load (converter in S1). Goal: a formula that works in v1 returns the same result after conversion in v2; exceptions are documented (number format, `/` returns an integer when the division is exact). Bugs of v1 that probably do not occur in any production flow (e.g. function calls that always fail in v1) are not reproduced. | S1 |
| E23 | **Golden data** is generated with the v1 code and the v1 interpreter (`v1/` is only read and executed in the process). | S1 |
| E24 | Numbers are output as text in the v2 representation (`0.75`), not as in v1 (`0.750000`). | S1 |
| E25 | Type errors when calculating (`"" + 1`): catch, `f1` log, result as in v1 (empty text). | S1 |
| E26 | The engine evaluates parameters of worker elements in advance, with an error per parameter; `ctx.EvalParams` throws at the first error that is not skipped. Consequence: an assignment in a skipped parameter still runs (MIGRATION). Inline elements evaluate on call, as in v1. | S1 |
| E27 | The project owner's private flows (`C:\Users\bichl\AppData\Roaming\AutoHotFlow\Flows`, on 2026-10-12 an identical copy of the 20 files in `Saved Flows` next to it, which v1 uses) and his variables (`...\AutoHotFlow\Variables`) serve as an additional test corpus, **only locally** (`tests/golden/private/`, not checked in). | S1 |
| E28 | `Lang()` moves to `src/core/` in S1. v2 continues to write variable files in the pair format `.ahfvd`/`.ahfvar`. Object variables are `Map` with `CaseSense := "Off"` (details in WI-40). The working directory for `file`/`folder` parameters keeps the v1 default value until S4 (`A_MyDocuments "\AutoHotFlow"`, v1 `Settings.ahk:15`). | S1 |

Answers of the project owner to the open questions (2026-10-13):

| # | Decision | Affects |
|---|---|---|
| E29 | **`/` with two integers** returns an integer if the division is exact (`4/2` = `2`), otherwise a float (`7/2` = `3.5`). This is a rule of the language: AHK v2 itself gives `4/2` = `2.0` (verified). The converter does not rewrite `/` (appending `.0` would only change the type, not the text form). | WI-37, WI-38 |
| E30 | **`<`, `>`, `<=`, `>=` follow AHK v2.** A comparison with a text that is not a number throws a `TypeError` in AHK v2 (verified: `"a" < "B"`); by E25 the result is `""` (false) plus an `f1` log. A text comparison that v1 did alphabetically is therefore false in v2. Accepted, because it is unlikely in real flows; the deviation catalog of WI-39 shows whether it occurs. | WI-38, WI-39 |
| E31 | **`&&`/`\|\|`** return the operand as in AHK v2 (`"a" \|\| 0` = `"a"`), not `1`/`0` as in v1. Entry in MIGRATION; as a condition both behave the same. | WI-38, WI-39 |
| E32 | **Text form of floats** stays the AHK v2 form, without own formatting (`0.1+0.2` gives `0.30000000000000004`, `1/3` gives `0.33333333333333331`, verified). A rounding option as an element parameter may come later. Refines E24. | WI-38, WI-39 |
| E33 | **Default data folder of v2** is `%APPDATA%\AutoHotFlow v2`, separate from the folder of the productive v1 (`%APPDATA%\AutoHotFlow`). Order: `--data`, then `AHF_DATA_DIR`, then the default (`Supervisor.DataDir`). The fallback `AHF_DATA_DIR` and the guard directory of the tests stay as they are. Done before WI-41, because the owner already starts v2 by hand. | Supervisor, WI-41 |
| E14 | **Closing the manager window** only closes (hides) the window; AutoHotFlow keeps running. Only the "Exit" button of the manager and the "Exit" entry of the tray menu end the application. Same as v1 (verified by reading: the v1 manager has no `GuiClose` handler, so closing hides the window; `Button_manager_Exit` in `Manager GUI.ahk:1026` and the tray entry call the exit). | S4 |
| E34 | **Type errors per flow (F-105, decided by the project owner, 2026-10-14).** Each flow has an option `strictTypes`. Migrated flows (recognised by `formatVersion` and the `v1Text` marker of WI-39) get `false`, which is the v1 behaviour: E25 stays as it is (empty text and `f1` warning). New flows get `true`: in strict mode a type error in a comparison or a calculation becomes an element error (`exception`). Independent of the mode, the `f1` warnings of the evaluator are shown in the editor (log display, S4/S5). | WI-42 (evaluator call from `ctx.EvalParams`, mode from the flow), flow format (WI-39 keys), MIGRATION M-24 and M-25 (text for the compatibility mode), S4/S5 (display) |

## Open questions for the project owner

None at the moment (all answered on 2026-10-13, see above).

## Required reading for every package

1. `AGENTS.md`
2. `doc/ARCHITECTURE.md` sections 1 to 6 and 8, `doc/CONVENTIONS.md`, `doc/HOW-TO.md`
3. `doc/PROTOCOL.md` (packages with messages), `doc/ELEMENT-API-V2.md` (packages with elements)
4. This file and the file of the own package

## Common definition of done

As in Phase 2b (`work_items/phase2b/README.md`): first a test that shows what is missing; overall run green (parallel, and serial if the package changes timing behavior); interfaces in `doc/` in the same commit; deviations from v1 in `doc/MIGRATION.md`; AHK difficulties in `doc/HOW-TO.md`; section "Result" in the package file; VS Code tasks according to rule 10 in `AGENTS.md`; commits with prefix `WI-xx:`. New findings start at **F-44**.

## S1: Expressions and variables

**Goal:** The engine evaluates expressions and parameters and manages all kinds of variables as v1 does. Old v1 expressions are converted into the new language on load, and golden data from v1 proves that they then return the same result (except for documented deviations).

**Not part of S1:** real elements (S2), variable access from the worker via `ctx.Request` (R4, S2), import UI (S4), settings (S4).

### Findings from the v1 code (read, not executed; WI-36 checks them)

- The v1 evaluator has its own tokenizer, parser and evaluator (`v1/Source_Common/Variables/`, 2192 lines). However, it computes the operators with the v1 operators (`Code evaluator.ahk:243` ff.), hence the v1 rules: `"" + 1` = `""`, `4/2` = `2.000000` as text, `<` compares text alphabetically.
- Suspected bugs in the v1 parser: function calls with arguments always fail (`Code parser.ahk:594`, condition inverted); escape sequences in strings are lost (`:718` compares with the empty variable `name`); `%` (modulo) is not known to the evaluator; `!`/`not` at the start of an expression fail; ` ;` cuts off even inside a string (`Code tokenizer.ahk:24`); `this.input.croak` does not exist (errors are swallowed).
- The location of a variable follows from its name (`Variables.ahk:219`, `:253`): `A_` = loop, thread or built-in; `global_`, `static_`; otherwise instance. Dots in the name are paths into objects (`liste.1`). There are hidden variables per scope. v1 reads `global`/`static` from disk on every access (`Global variables.ahk`). v2 currently searches differently (`VarStore.Find`: thread, then instance).
- Built-in variables: 55 from AHK and 14 of its own (`Global variables.ahk:2`, `:4`, `:164`).
- Parameter evaluation `x_AutoEvaluateParameters` (`v1/Source_Execution/API/API for Elements.ahk:60` to `:369`): content types `String` (`%var%`), `Expression`, `number`, `positiveNumber`, `integer`, `positiveInteger`, `positiveIntegerOrZero`, `VariableName`, `RawString`; field types `file`/`folder` (full path); `WarnIfEmpty`, `contentConvertObjects`, `contentID` (content type selectable by the user), `skipList`.
- The v1 interpreter is `v1/AutoHotKey/AutoHotFlow.exe`: AutoHotkey_H 1.1.32.00-H010, 32 bit (file version verified).
- In the 23 example flows, 3064 parameters have a text value, 43 of them with `%`; operators are rare (` and ` 37, `+=` 7, `<=` 7, ...). Rough count over all parameters, not only expressions.

### Behavior of AHK v2 (verified on 2026-10-12, script run with `ahkrun.py`)

| Expression | AHK v2 |
|---|---|
| `4/2` | `2.0` (float) |
| `7/2` | `3.5` |
| `0.5+0.25` | `0.75` |
| `"" + 1`, `"abc" + 1` | `TypeError` |
| `"5" + 1`, `" 5 " + 1` | `6` |
| `7//2`, `-7//2` | `3`, `-3` |
| `7.0//2` | `TypeError` (requires integer) |
| `"abc" = "ABC"` | `1` |
| `"abc" < "ABD"`, `"a" < "B"`, `"10" < "9a"` | `TypeError` |
| `"10" < "9"` | `0` (numeric) |
| `"0x10" + 0`, `"1e3" + 0` | `16`, `1000.0` |
| `!""`, `!"0"` | `1`, `1` |
| `"a" && 0`, `"a" \|\| 0` | `0`, `"a"` |

### Packages

| ID | Title | Size | Depends on |
|---|---|---|---|
| [WI-36](WI-36-golden-data-v1.md) | Golden data from v1 | M | – |
| [WI-37](WI-37-expression-language-parser.md) | Expression language v2: specification, tokenizer, parser | M | – |
| [WI-38](WI-38-evaluator.md) | Evaluator of the new language | M | WI-37 |
| [WI-39](WI-39-converter-v1-expressions.md) | Conversion of old expressions (converter) | L | WI-36, WI-37, WI-38 |
| [WI-40](WI-40-variable-model.md) | Variable model in the engine | L | WI-38 |
| [WI-41](WI-41-global-static-data-folder.md) | `global`/`static` permanent, data folder | M | WI-40 |
| [WI-42](WI-42-parameter-evaluation-ctx.md) | Parameter evaluation and `ctx` API | M | WI-38, WI-39, WI-40 |
| [WI-43](WI-43-acceptance-s1.md) | Acceptance S1 | S | all |

WI-36 and WI-37 can run in parallel. WI-36 starts only after WI-34 (it changes `tools/ahkrun.py`).

### Progress S1

- [x] WI-36  - [x] WI-37  - [x] WI-38  - [x] WI-39  - [x] WI-40  - [x] WI-41  - [x] WI-42  - [ ] WI-43 (serial and parallel run green, one stress test red: F-268)
