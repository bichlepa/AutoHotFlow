# Phase 3: v1 feature scope in the new architecture, plan

Status: 2026-10-13, plan of the project owner with Claude. Branch `v2-port`. Located in `work_items/phase3/` (temporary, delete after the port). **Phase 3 is approved by the project owner (2026-10-13).**

Basis: Phase 2 (walking skeleton), Phase 2b (hardening) and the fix block up to WI-0034. What already exists: processes, IPC, supervisor, storage, engine with state machines and latest revision, worker pool, diagnostics, debug window, skeleton elements. What is missing: see `work_items/HANDOVER.md`, "Offene Punkte" (Open points).

## Goal of the phase

AutoHotFlow v2 can do everything v1 can: load flows (including old v1 flows), edit them, run them, triggers, all elements, manager, editor. Afterwards (Phase 4) debugger, compilation and installer follow.

## Guiding principles

1. **Vertical steps.** Each step ends with something that runs and is tested, and brings the engine commands it needs.
2. **Test early.** The element scope stays small until the editor is finished. This way the project owner can try things out by hand early. The remaining elements come in S0008.
3. **Measure risky things early** (R0003 in S0002, R0002 in S0005), before much code relies on them.
4. **v1 stays in everyday use until v2 is finished.** v2 only needs to be able to **read** old flows and variables. What v2 writes is free (E0021). v2 works in its own data folder; old data comes in through an import (S0004).
5. **v1 is not the yardstick (E0035).** A loaded v1 flow may need small fixes; every such place is marked with its MIGRATION ID. Tests take their expected values from AHK v2 and the v1 help texts, not from the v1 code.

## Procedure per step

Each step is worked through individually: **detail** (package files WI-xx with tasks and acceptance criteria), **decide** (questions for the project owner, numbers from E0018 onward), **implement**, **test** (acceptance run serial, parallel, stress), then the next step. Only the next step is detailed at any time; the others stay rough so that findings can flow in.

## Steps

| # | Step | Content (rough) | Acceptance | Status |
|---|---|---|---|---|
| **S0001** | Expressions and variables | new expression language (AHK v2 semantics), conversion of old expressions, golden data from v1, variable model, `global`/`static` permanent, parameter evaluation | see below, packages WI-0036 to WI-0043 | done (acceptance closed 2026-10-15, E0050; F-0073 stays open) |
| **S0002** | Element foundation and core set | oracle of the expression language (native AHK v2, E0035), migration markers, R0003 measurement, element layout per package (E0037), L0001 smoke test, flow builder for tests, R0004 (`ctx.Request`), dialog test seam (E0038), core set of 29 elements, test corpus from the "Automatic tests" flows | see below, packages WI-0044 to WI-0058 | **done** (acceptance WI-0058, 2026-10-16; F-0107 and F-0108 closed by the owner) |
| **S0003** | Trigger host and a few triggers | enabled state per trigger, kept across starts (E0056, E0057), role `triggerhost` (WI-0014), `cmd.trigger.arm/disarm`, `evt.trigger.fired/error`, re-arming after a restart of engine or trigger host, activate/deactivate flow. Triggers: Manual, Hotkey (with window conditions, E0060), Periodic_Timer, Start_up; elements `Set_Flow_Status`, `Condition_Flow_Enabled`; guard against runaway flows (REQ-EXE-170, E0062) | see below, packages WI-0060 to WI-0067 | **detailed** |
| S0004 | UI foundation and manager | `ui_common/`, manager (category tree, start/stop/activate, new/rename/delete/duplicate, settings, log display, hints), **import from v1** (flows, variables), `.ahf` export/import, engine commands `cmd.flow.create/delete/meta.update`, `cmd.category.*`, `cmd.settings.*`, global setting for the number of workers (E0044, F-0082). Closing the window only hides it (E0014). Tray icon and tray menu (REQ-MGR-140), start with Windows, run as administrator, user level setting, about window (REQ-MGR-090, REQ-SET-030, REQ-SET-040, REQ-USE-010, REQ-MGR-100). Notice on unhandled flow errors (REQ-USE-080), imported flows disabled with a warning (REQ-SEC-060), the manager can be reopened after a crash (REQ-ROB-120), sharp on high-resolution displays (REQ-USE-090, also S0005 to S0007). From S0003: the display of active independent triggers and the dialog that disables a flow completely (E0056), the notice when a flow was stopped by a limit and the global defaults of the limits (REQ-EXE-170, E0062), the autostart entry passes `--windows-startup` (WI-0063) | operation by hand, e2e of the commands | rough |
| S0005 | Editor I: display | `Renderer`/`Scene`, GDI+ in v2, zoom, panning the view, live states, resync, tray icon of the editor with the state of the flow (REQ-EDT-230) | R0002 measurement (300 elements, under 16 ms per frame), memory with 5 editors | rough |
| S0006 | Editor II: editing | selection, moving, connecting, copy/paste, undo/redo, patch operations, `baseRev` conflict, saving, prompt when quitting, a crashed editor loses nothing (REQ-ROB-120), tray menu of the editor (REQ-EDT-230). From S0003: a changed, added or removed trigger of an enabled flow is re-armed or disarmed; the enabled state of a new trigger | e2e: editing during execution (E0001) | rough |
| S0007 | Editor III: settings dialogs | parameter schema to GUI, `form` API for `CheckSettings`, flow settings, wizards (window info, color, mouse), help, element list filtered by user level (REQ-USE-010). From S0003: the checkbox "Switch with the flow" (`followsFlow`, E0056) in every trigger dialog, the limits of a flow in the flow settings (REQ-EXE-170) | every element of the core set editable | rough |
| S0008 | Remaining elements | first the converter `tools/convert_element.py` (E0036, tested with the core set of S0002 as before/after cases), then the elements in groups: dialogs/worker, file/drive/process/internet/power/sound, window/user simulation/image, unsafe elements (AHK script with v2 code only, E0039; DllCall, TTS, Eject, Monitor, screen, input block), remaining triggers, demonstration flows (REQ-MGR-060) | the "Automatic tests" flows of the test corpus (WI-0057, adapted to v2 where needed) run green | rough |
| S0009 | Distribution and release | compiled program (one program or one per role, R0007), installer with start menu entry and uninstaller, release checklist, translations brought up to date, translation tools for contributors, newer file formats are not destroyed (REQ-DST-010, REQ-DST-020, REQ-DST-050, REQ-LNG-050, REQ-MIG-080) | install, start, use and uninstall on a Windows without AutoHotkey | rough |
| S0010 | Phase 3 completion | overall acceptance, equality list with v1, performance budgets, documents, check that nothing is sent from the computer (REQ-SEC-050), scope of Phase 4 | serial, parallel, stress green | rough |

Not in Phase 3 (E0019): debugger (do not block the execution gate, ARCHITECTURE 4.3), compilation and installer (R0007).

## Decisions of the project owner (2026-10-12)

| # | Decision | Affects |
|---|---|---|
| E0018 | Order: runtime first (S0001 to S0003), then manager before editor. | Plan |
| E0019 | Debugger, compilation and installer are not part of Phase 3. | Plan |
| E0020 | Element scope stays small (core set) until the editor is finished; the remaining elements come in S0008. | S0002, S0008 |
| E0021 | **File format:** v2 must be able to load old flows and variables; how v2 saves is free. v2 works in its own data folder, old data comes in via import (later possibly also an automatic backup at the switchover). Replaces the requirement "format stays" from D0011/E0008 for writing. | S0001, S0004 |
| E0022 | **No reproduction of the v1 expression evaluation.** The new expression language follows AHK v2. Old expressions are converted on load (converter in S0001). Goal: a formula that works in v1 returns the same result after conversion in v2; exceptions are documented (number format, `/` returns an integer when the division is exact). Bugs of v1 that probably do not occur in any production flow (e.g. function calls that always fail in v1) are not reproduced. **Narrowed by E0035:** a deviation must be known and marked; v1 is not the yardstick of new tests. | S0001 |
| E0023 | ~~**Golden data** is generated with the v1 code and the v1 interpreter (`v1/` is only read and executed in the process).~~ **Superseded by E0035:** the v1 golden data is frozen; nothing new is generated against v1. | S0001 |
| E0024 | Numbers are output as text in the v2 representation (`0.75`), not as in v1 (`0.750000`). | S0001 |
| E0025 | Type errors when calculating (`"" + 1`): catch, `f1` log, result as in v1 (empty text). | S0001 |
| E0026 | The engine evaluates parameters of worker elements in advance, with an error per parameter; `ctx.EvalParams` throws at the first error that is not skipped. Consequence: an assignment in a skipped parameter still runs (MIGRATION). Inline elements evaluate on call, as in v1. | S0001 |
| E0027 | The project owner's private flows (`C:\Users\bichl\AppData\Roaming\AutoHotFlow\Flows`, on 2026-10-12 an identical copy of the 20 files in `Saved Flows` next to it, which v1 uses) and his variables (`...\AutoHotFlow\Variables`) serve as an additional test corpus, **only locally** (`tests/golden/private/`, not checked in). | S0001 |
| E0028 | `Lang()` moves to `src/core/` in S0001. v2 continues to write variable files in the pair format `.ahfvd`/`.ahfvar`. Object variables are `Map` with `CaseSense := "Off"` (details in WI-0040). The working directory for `file`/`folder` parameters keeps the v1 default value until S0004 (`A_MyDocuments "\AutoHotFlow"`, v1 `Settings.ahk:15`). | S0001 |

Answers of the project owner to the open questions (2026-10-13):

| # | Decision | Affects |
|---|---|---|
| E0029 | **`/` with two integers** returns an integer if the division is exact (`4/2` = `2`), otherwise a float (`7/2` = `3.5`). This is a rule of the language: AHK v2 itself gives `4/2` = `2.0` (verified). The converter does not rewrite `/` (appending `.0` would only change the type, not the text form). | WI-0037, WI-0038 |
| E0030 | **`<`, `>`, `<=`, `>=` follow AHK v2.** A comparison with a text that is not a number throws a `TypeError` in AHK v2 (verified: `"a" < "B"`); by E0025 the result is `""` (false) plus an `f1` log. A text comparison that v1 did alphabetically is therefore false in v2. Accepted, because it is unlikely in real flows; the deviation catalog of WI-0039 shows whether it occurs. | WI-0038, WI-0039 |
| E0031 | **`&&`/`\|\|`** return the operand as in AHK v2 (`"a" \|\| 0` = `"a"`), not `1`/`0` as in v1. Entry in MIGRATION; as a condition both behave the same. | WI-0038, WI-0039 |
| E0032 | **Text form of floats** stays the AHK v2 form, without own formatting (`0.1+0.2` gives `0.30000000000000004`, `1/3` gives `0.33333333333333331`, verified). A rounding option as an element parameter may come later. Refines E0024. | WI-0038, WI-0039 |
| E0033 | **Default data folder of v2** is `%APPDATA%\AutoHotFlow v2`, separate from the folder of the productive v1 (`%APPDATA%\AutoHotFlow`). Order: `--data`, then `AHF_DATA_DIR`, then the default (`Supervisor.DataDir`). The fallback `AHF_DATA_DIR` and the guard directory of the tests stay as they are. Done before WI-0041, because the owner already starts v2 by hand. | Supervisor, WI-0041 |
| E0014 | **Closing the manager window** only closes (hides) the window; AutoHotFlow keeps running. Only the "Exit" button of the manager and the "Exit" entry of the tray menu end the application. Same as v1 (verified by reading: the v1 manager has no `GuiClose` handler, so closing hides the window; `Button_manager_Exit` in `Manager GUI.ahk:1026` and the tray entry call the exit). | S0004 |
| E0034 | **Type errors per flow (F-0068, decided by the project owner, 2026-10-14).** Each flow has an option `strictTypes`. Migrated flows (recognised by `formatVersion` and the `v1Text` marker of WI-0039) get `false`, which is the v1 behaviour: E0025 stays as it is (empty text and `f1` warning). New flows get `true`: in strict mode a type error in a comparison or a calculation becomes an element error (`exception`). Independent of the mode, the `f1` warnings of the evaluator are shown in the editor (log display, S0004/S0005). | WI-0042 (evaluator call from `ctx.EvalParams`, mode from the flow), flow format (WI-0039 keys), MIGRATION M-0024 and M-0025 (text for the compatibility mode), S0004/S0005 (display) |

Decisions of the project owner while S0002 was detailed (2026-10-14; E0040, E0041 and E0045 on 2026-10-15):

| # | Decision | Affects |
|---|---|---|
| E0035 | **v1 is no longer the yardstick.** Full v1 compatibility is not essential (niche product, v1 hardly in use because of its bugs); small manual fixes after the import are acceptable. (1) The v1 golden data of WI-0036 is **frozen**: it stays as a regression test of the converter, nothing new is generated against v1. (2) The **oracle of the expression language is native AHK v2**: generated expressions run as AHK v2 code and in the evaluator and may differ only by a fixed list of deliberate deviations (E0025, E0029, E0034). (3) The specification of an element is the underlying AHK v2 command plus the **v1 help texts** (`v1/Source_Elements/Default/help/`), not the v1 code. (4) Every place that the loader cannot convert or that behaves differently is **marked with its MIGRATION ID, with the v1 original kept**, so that a later AI-assisted import can get the description of the changes and adapt the flow. The AI connection is not part of phase 3. Supersedes E0023, narrows E0022. | WI-0044, WI-0045, WI-0057, TEST-STRATEGY 7 and 8 |
| E0036 | The element converter `tools/convert_element.py` moves to the **start of S0008**. The core set of S0002 is ported by hand; these elements are the before/after test cases of the converter. | S0002, S0008 |
| E0037 | Element files are organised **per package** (`src/elements/<package>/`), the include block is generated per package. In phase 3 the only package is `Default`; the package information in flows stays. | WI-0047 |
| E0038 | **Dialogs of elements go through an indirection.** The test entry point registers a provider with scripted answers, so dialog elements are tested headless, without the `gui` tier. | WI-0051, WI-0056 |
| E0039 | **v1 AHK code** in `Action_AutoHotkey_script` and `Trigger_AutoHotkey_Script` is not run with a v1 interpreter (E0004 stays). The v2 elements run AHK v2 code; an imported v1 script is kept as text and marked (E0035); porting it is a manual or AI-assisted step. Documented break (MIGRATION M-0049). | S0008 |
| E0040 | **Memory budget applies to the background processes only.** Supervisor, storage, engine, triggerhost, manager and the workers are counted (below 100 MB private bytes with one worker and about 150 elements); editors are not counted. Normal state with about 3 active workers; peaks may exceed the budget. The user limits the workers by the pool size N (E0044: default 8, 1 to 16); `workerLimit` is an internal guard (24). | WI-0047-PREP |
| E0041 | **Role entry scripts (R0003 option A without B).** Each role's entry script includes only the element classes it needs, selected by the literal `static Mode` (engine: all; triggerhost: trigger; worker: worker; supervisor, storage and debug: none; manager: all if it needs them, accepted). Metadata and runtime code are not split. Supersedes D0012 in part. | WI-0047-PREP, WI-0047 |
| E0045 | **The package name is part of the identity of an element**, also for the elements of v1 (REQ-PKG-060). Each package is an AHK class that includes its element files; the type name (`Default.Action_Sleep`) is the qualified ID used by registry, worker jobs, trigger arming and logs. Flow files stay as they are (`package` plus `class`; missing `package` means `Default`, case ignored). (2026-10-15) | WI-0047 |

Decisions of the project owner while S0003 was detailed (2026-10-16; details in `doc/DECISIONS.md`):

| # | Decision | Affects |
|---|---|---|
| E0056 | **Enabled state of triggers.** Every trigger has its own enabled state and the property `followsFlow` ("Switch with the flow", default true, stored in the flow file). A flow is active when at least one of its following triggers is enabled. Enabling or disabling a flow switches its following triggers only; switching one trigger changes only that trigger. Independent triggers keep their state, also across a restart. When the user disables, by hand, a flow that is inactive but has active independent triggers, the manager asks whether to disable them too, and says that only the editor can undo this. | WI-0060, WI-0062, WI-0065, S0004 (dialog, display), S0007 (checkbox) |
| E0057 | **The enabled state is kept in its own file `FlowState.json`** in the data folder (written by storage, owned by the engine), not in the flow file and not in the settings: switching must not save unsaved changes of a flow, and the state belongs to the machine. | WI-0060 |
| E0058 | **A flow file in the v1 format loads with all triggers disabled;** its `enabled` keys are ignored (REQ-SEC-060). Otherwise a flow that runs in the productive v1 would react twice. | WI-0060, MIGRATION |
| E0059 | **Hotkey tests:** simple tests send unassigned virtual keys (`vk97` to `vk9F`) with `SendInput` and run in the normal tiers under a machine-wide input lock; key combinations with modifiers run in the `gui` tier (by the owner). A spike checks first that unassigned keys work. | WI-0064 |
| E0060 | **`Trigger_Hotkey` comes complete in S0003, with its window conditions.** The window identification it needs is built as a shared library of the package, which S0008 reuses. | WI-0064, S0008 |
| E0061 | **Acceptance evidence of S0003:** an adapted copy of the v1 flow "Trigger test" without its `Action_Speech_output` (S0008), recorded in the fix list with a MIGRATION ID. | WI-0067 |
| E0062 | **Guard against runaway flows (new REQ-EXE-170).** Per flow: element executions per minute (the trigger counts too); over the limit all instances stop and all triggers of the flow are disabled, independent ones included, and the user is told. Waiting instances and parallel instances: a start over the limit is refused like `skip`. No separate "new instances per minute". Global defaults (S0004), per flow changeable (S0007), 0 = no limit. WI-0066 sets the defaults from its throughput measurement (start: 100 waiting, 100 parallel); the owner may change them later. | WI-0066, S0004, S0007 |

## Open questions for the project owner

None at the moment (E0056 to E0062 answered on 2026-10-16).

## Required reading for every package

1. `AGENTS.md`
2. `doc/ARCHITECTURE.md` sections 1 to 6 and 8, `doc/CONVENTIONS.md`, `doc/HOW-TO.md`
3. `doc/PROTOCOL.md` (packages with messages), `doc/ELEMENT-API-V2.md` (packages with elements)
4. This file and the file of the own package
5. `doc/REQUIREMENTS-INDEX.md`, and the sections of `doc/REQUIREMENTS.md` that the package changes

## Common definition of done

As in Phase 2b (`work_items/phase2b/README.md`): first a test that shows what is missing; overall run green (parallel, and serial if the package changes timing behavior); interfaces in `doc/` in the same commit; deviations from v1 in `doc/MIGRATION.md`; AHK difficulties in `doc/HOW-TO.md`; section "Result" in the package file; VS Code tasks according to rule 10 in `AGENTS.md`; the requirements the package touches updated according to rule 12 in `AGENTS.md`; commits with prefix `WI-xx:`. New findings start at **F-0040**.

## S0001: Expressions and variables

**Goal:** The engine evaluates expressions and parameters and manages all kinds of variables as v1 does. Old v1 expressions are converted into the new language on load, and golden data from v1 proves that they then return the same result (except for documented deviations).

**Not part of S0001:** real elements (S0002), variable access from the worker via `ctx.Request` (R0004, S0002), import UI (S0004), settings (S0004).

### Findings from the v1 code (read, not executed; WI-0036 checks them)

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
| [WI-0036](WI-0036-golden-data-v1.md) | Golden data from v1 | M | – |
| [WI-0037](WI-0037-expression-language-parser.md) | Expression language v2: specification, tokenizer, parser | M | – |
| [WI-0038](WI-0038-evaluator.md) | Evaluator of the new language | M | WI-0037 |
| [WI-0039](WI-0039-converter-v1-expressions.md) | Conversion of old expressions (converter) | L | WI-0036, WI-0037, WI-0038 |
| [WI-0040](WI-0040-variable-model.md) | Variable model in the engine | L | WI-0038 |
| [WI-0041](WI-0041-global-static-data-folder.md) | `global`/`static` permanent, data folder | M | WI-0040 |
| [WI-0042](WI-0042-parameter-evaluation-ctx.md) | Parameter evaluation and `ctx` API | M | WI-0038, WI-0039, WI-0040 |
| [WI-0043](WI-0043-acceptance-s1.md) | Acceptance S0001 | S | all |

WI-0036 and WI-0037 can run in parallel. WI-0036 starts only after WI-0034 (it changes `tools/ahkrun.py`).

### Progress S0001

- [x] WI-0036  - [x] WI-0037  - [x] WI-0038  - [x] WI-0039  - [x] WI-0040  - [x] WI-0041  - [x] WI-0042  - [x] WI-0043 (closed by the owner 2026-10-15, E0050)

## S0002: Element foundation and core set

**Goal:** Real elements run in the new architecture. A core set of 29 elements is enough to run synthetic test flows and three "Automatic tests" flows of v1 headless and green. The expression language has an independent oracle (native AHK v2, E0035). Every place of a loaded v1 flow that needs a fix carries its MIGRATION ID.

**Not part of S0002:** trigger host and `Set_Flow_Status` (S0003), import UI (S0004), settings dialogs and `CheckSettings` in the GUI (S0007), `tools/convert_element.py` (S0008, E0036), `AutoHotkey_script` (S0008, E0039), the AI connection (after phase 3, E0035).

### Findings for S0002 (2026-10-14)

- **Verified (read):** one entry point for all roles (D0012). `src/AhfBoot.ahk` includes every role and every element, so every process parses everything. "An include block per role" (ELEMENT-API 2, ARCHITECTURE R0003) is therefore only possible with separate entry scripts; WI-0046 measures whether that is needed at all.
- **Verified (read):** the test elements (`Action_Test*`) are in `src/elements/skeleton/` and are included by the product entry.
- **Verified (read):** a worker element already gets copies of the visible loop, thread and instance variables with the job (WI-0040, MIGRATION M-0045). R0004 is what is left: global, static, hidden and built-in variables, writing variables, and `ReplaceVariables`/`EvaluateExpression` in the worker (ELEMENT-API 3, "Worker: R0004 (S0002)").
- **Verified (counted):** element use in 46 flows (v1 examples plus the owner's private flows): `Condition_Expression` 128, `New_Variable` 123, `Variable_content_is` 101, `Trigger_Manual` 77, `Set_Flow_Status` 65, `Do_nothing` 56, `Execute_Flow` 44, `NumberIs` 32, `Sleep` 32, `Debug_dialog` 30, `Message_Box` 30, `Add_to_list` 29, `Tooltip` 27.
- **Verified (counted):** of the 16 "Automatic tests" flows in `tests/data/flows/v1_examples/`, the core set below covers three completely: "variable test", "List test", "Loop test". The others need elements of S0003 (`Set_Flow_Status`, triggers) or S0008. The main load of the S0002 tests is therefore on synthetic flows (WI-0049, WI-0057).
- **Verified (read):** `Loop_Condition` (`v1/Source_Elements/Default/Loops/Condition.ahk`) evaluates its condition with `x_EvaluateExpression`. A ported element that evaluates a parameter itself must name it in `V1Syntax`, otherwise the loader leaves the v1 text unconverted (ELEMENT-API 2). The converter that would warn about this comes only in S0008 (E0036), so the smoke test checks it (WI-0048).
- **Verified (listed):** the v1 help texts of the elements are in `v1/Source_Elements/Default/help/en/<Kind>/<Name>.html` (E0035: specification of an element).

### Core set

| Group | Elements (v1 class IDs) | Package |
|---|---|---|
| Variables, conditions, trace points | `Action_New_variable`, `Condition_Expression`, `Condition_Variable_content_is`, `Condition_NumberIs`, `Condition_Variable_Is_Empty`, `Action_Do_nothing`, `Condition_Do_nothing`, `Action_Trace_Point`, `Action_Trace_Point_Check` | WI-0052 |
| Lists | `Action_New_List`, `Action_Add_To_List`, `Action_Get_List_Info`, `Condition_List_Contains_Element`, `Action_Delete_from_list`, `Action_Get_index_of_element_in_list`, `Action_Shuffle_list` | WI-0053 |
| Loops | `Loop_SimpleLoop`, `Loop_Condition`, `Loop_Work_through_a_list`, `Loop_Parse_A_String` | WI-0054 |
| Flow control | `Action_Execute_Flow`, `Action_Stop_Flow`, `Condition_Flow_Running` | WI-0055 |
| Dialogs and worker | `Action_Message_Box`, `Condition_Confirmation_Dialog`, `Condition_Debug_Dialog`, `Action_Tooltip` | WI-0056 |
| Already there, completed | `Action_Sleep`, `Trigger_Manual` (from `skeleton/` to `Default`, parameters as in v1) | WI-0047 |

Count: 27 classes in the groups above + 2 in the last row (`Action_Sleep`, `Trigger_Manual`) = 29 elements.

The trace points are in the first group on purpose: they record the path through a flow and serve as instrumentation for every later e2e test.

### Packages

| ID | Title | Size | Depends on |
|---|---|---|---|
| [WI-0044](WI-0044-expression-oracle-ahk-v2.md) | Oracle of the expression language: native AHK v2; v1 golden data frozen | M | WI-0038 |
| [WI-0045](WI-0045-migration-markers.md) | Migration markers with MIGRATION ID and v1 original, import report | S | WI-0039 |
| [WI-0046](WI-0046-r3-measurement.md) | R0003 measurement: parse time and memory with many elements | S | – |
| [WI-0047-PREP](WI-0047-PREP-role-entries.md) | Role entry scripts (E0041), class selection by `Mode`, memory per role (E0040) | M | WI-0046 |
| [WI-0047](WI-0047-element-layout-packages.md) | Element layout per package, generated include block, test elements out of `src/` | M | WI-0047-PREP, WI-0042 |
| [WI-0048](WI-0048-element-smoke-tests.md) | L0001 smoke test of every registered element | S | WI-0047 |
| [WI-0049](WI-0049-flow-builder.md) | Flow builder and headless flow runner for tests | M | – |
| [WI-0050](WI-0050-r4-ctx-request.md) | R0004: `ctx.Request` and variable access in the worker | M | WI-0042 |
| [WI-0051](WI-0051-dialog-test-seam.md) | Dialog indirection and test provider | S | WI-0047 |
| [WI-0052](WI-0052-core-variables-conditions.md) | Core set A: variables, conditions, trace points | M | WI-0048, WI-0049 |
| [WI-0053](WI-0053-core-lists.md) | Core set B: lists | M | WI-0048, WI-0049 |
| [WI-0054](WI-0054-core-loops.md) | Core set C: loops | M | WI-0048, WI-0049, WI-0052 (trace points), WI-0053 (the v1 flow "Loop test" uses `New_List` and `Add_To_List`) |
| [WI-0055](WI-0055-core-flow-control.md) | Core set D: flow control and the engine commands it needs | L | WI-0050, WI-0052 |
| [WI-0056](WI-0056-core-dialogs.md) | Core set E: dialogs and worker elements | M | WI-0050, WI-0051 |
| [WI-0057](WI-0057-test-corpus.md) | Test corpus: three v1 test flows adapted, synthetic flows | M | WI-0045, WI-0049, WI-0052 to WI-0056 |
| [WI-0058](WI-0058-acceptance-s2.md) | Acceptance S0002 | S | all |

**Order.** The orchestrator runs one implementation at a time (bug fixes and test runs in parallel). Proposed order: WI-0044, WI-0045, WI-0046, WI-0049 (they need no `ctx` and can start before WI-0043 is finished), then WI-0047-PREP, WI-0047, WI-0048, WI-0050, WI-0051, then WI-0052 to WI-0056, then WI-0057, WI-0058. The column "Depends on" is binding, the order is not: if a package is blocked, any package whose dependencies are done may come first.

**Load path of the engine (F-0073, retrospective of WI-0043).** Since S0001 the engine loads 200 big flows more slowly (ready after 59 s instead of 45 s, largest snapshot answer 2.3 s instead of 0.5 s; suspected: the conversion at load and the variable loading). S0002 makes this work grow on purpose: every class it registers lets the loader convert more elements. Therefore: WI-0046 measures the load phase per flow as a baseline before the first class comes; and every package that adds work to the load path (WI-0045, WI-0047, WI-0052 to WI-0056) runs `tests/stress/test_big_flows.py` at its end and records the time to ready and the largest snapshot answer in its result. If the budget is broken, the package stops and the project owner decides (stagger the conversion, convert on first use, or save converted flows). Since 2026-10-15 (E0042) the budget of the snapshot answer is 3 s (it was 1 s); a maximum that moves systematically above about 1.5 s is reported in the result of the package.

**Files with conflict risk in S0002:** `doc/ELEMENT-API-V2.md` (WI-0047, WI-0050, WI-0051, WI-0055, WI-0056), `doc/PROTOCOL.md` (WI-0050, WI-0055), `doc/MIGRATION.md` (every element package). The generated include block is never merged by hand: it is generated again.

### Acceptance S0002

- The smoke test (WI-0048) is green for every registered element.
- The oracle (WI-0044) shows no deviation from AHK v2 that is not in the list of deliberate deviations; the fixed corpus runs in the fast tier.
- Every core element has e2e tests through the flow builder; worker elements are tested with the dialog test seam.
- The v1 flows "variable test", "List test" and "Loop test" and the synthetic flows of WI-0057 run headless and green; every fix of a v1 flow is documented with its MIGRATION ID.
- The values of R0003 (WI-0046) and R0004 (WI-0050) are in `doc/MEASUREMENTS.md`.
- Serial, parallel and `-m stress` runs are green.

### Progress S0002

- [x] WI-0044  - [x] WI-0045  - [x] WI-0046  - [x] WI-0047-PREP  - [x] WI-0047  - [x] WI-0048  - [x] WI-0049  - [x] WI-0050  - [x] WI-0051
- [x] WI-0052  - [x] WI-0053  - [x] WI-0054  - [x] WI-0055  - [x] WI-0056  - [x] WI-0057  - [x] WI-0058

## S0003: Trigger host and triggers

**Goal:** Triggers react by themselves. The trigger host holds the OS handles (timers, hotkeys); the engine knows the enabled state of every trigger, keeps it across starts, arms the triggers in the host and starts instances on their events. Four triggers (Manual, Periodic_Timer, Start_up, Hotkey with window conditions), the elements `Action_Set_Flow_Status` and `Condition_Flow_Enabled`, and a guard against runaway flows (REQ-EXE-170). The v1 flow "Trigger test" runs headless and green on an adapted copy (E0061).

**Not part of S0003:** the manager display of independent triggers and the dialog that disables a flow completely (S0004, E0056), the notice of a limit stop and the global defaults of the limits (S0004), import from v1 (S0004), the checkbox `followsFlow` and the limits in the flow settings (S0007), re-arming triggers that the editor changes (S0006), the other triggers (S0008), `ctx.Request` for triggers (only when a trigger of S0008 needs it), conflicting hotkeys reported (REQ-TRG-040, `later`).

### Findings for S0003 (2026-10-16)

- **Verified (read):** v1 keeps one `enabled` key per trigger in the flow file; the enabled state of a flow is derived ("any trigger enabled"); enabling a flow enables all its triggers, disabling disables all; every switch rewrites the whole flow file (`SaveFlowMetaData` calls `SaveFlow`, `v1/Source_Common/Flows/Save.ahk:5`). At start `EnableLoadedFlows` (`v1/Source_Common/Flows/Manage Flows.ahk`) enables every trigger with `enabled`; only during this pass `x_isAHFStartup()` is true (`v1/Source_Execution/Execution.ahk:90`), which `Trigger_Start_up` uses.
- **Verified (read):** in v2 `FlowRecord.Enabled` is a flag only: not loaded, not kept (F-0099, E0053); `cmd.flow.enable/disable` only set it. The role `triggerhost` is a placeholder (`src/entry/triggerhost.ahk`); the supervisor already gives it its rank in the shutdown (`Children._RankOf`). `Trigger_Manual` has `Enable`, `Disable` and `TriggerVariables`, but the engine never calls `TriggerVariables` (M-0069).
- **Verified (read):** the v1 flow "Trigger test" (`Flow 884290977`) uses `Trigger_Manual`, `Trigger_Periodic_Timer`, `Trigger_Start_up`, `Action_Set_Flow_Status`, `Condition_Flow_Enabled`, `Action_Execute_Flow`, `Condition_Debug_Dialog`, `Action_New_variable`, `Action_Sleep`, `Action_Add_To_List`, `Action_Stop_Flow` and one `Action_Speech_output` (S0008). No other flow of the table `PENDING` (`tests/integration/test_corpus.py`) becomes runnable with S0003 alone.
- **Verified (read):** v2 has no file with state per machine yet; storage knows flow files and variable files. The settings file comes with S0004.
- **Verified (read):** the test admission (WI-0059) runs `stress`, `soak` and `idle` alone, but two normal runs may overlap. There is no lock for tests that send real input.
- **Verified (read, AHK v2 docs `lib/Hotkey.htm`):** in one AutoHotkey process a second `Hotkey()` with the same key and the same `HotIf` criteria updates the existing hotkey, so the callback of the first is replaced; different `HotIf` criteria make separate variants. v1 has all triggers in one process, so two flows with the same hotkey disturb each other there; the trigger host must share one registration between them (WI-0064).
- **Not measured:** how many inline elements per second the engine executes (MS-0017 measures instance starts only, about 300 per second). WI-0066 measures it before the owner sets the defaults of the limits.

### Design fixed while detailing

No owner decision needed; a package may refine it and says so in its result.

- The engine evaluates the parameters of a trigger when it arms it, with the global, static and built-in variables (there is no instance yet, as in v1). An evaluation error: the trigger is not armed, its state carries the message.
- Every arming carries a generation number; the engine drops a fired event of an older generation or of a trigger that is no longer enabled.
- Before it arms, the engine resets the host (`cmd.trigger.reset`); it arms again after its own restart and after a restart of the trigger host. Arming at start is staggered like the loading of the flows (F-0073).
- `Trigger_Start_up` fires only in the first arming pass after the start of AutoHotFlow: not after a restart of engine or trigger host, and not when a flow is enabled later (as v1). A start with Windows is told by the supervisor option `--windows-startup`, which the autostart entry of S0004 sets.
- Target state and armed state are separate. `IsTriggerEnabled` (`Action_Execute_Flow`, `Condition_Flow_Enabled`) reads the target state; whether a trigger is armed, and its error, is reported by `evt.trigger.state`.
- `TriggerVariables` runs at every start of an instance, also at a start by `cmd.flow.start` or by another flow (M-0069 goes back).
- A start by hand (`cmd.flow.start`) of a disabled flow stays allowed (WI-0060 checks v1).

### Packages

| ID | Title | Size | Depends on |
|---|---|---|---|
| [WI-0060](WI-0060-trigger-enabled-state.md) | Enabled state of triggers: model, `FlowState.json`, commands, F-0099 | L | – |
| [WI-0061](WI-0061-trigger-host-role.md) | Role `triggerhost`: arm, disarm, fire, test triggers | M | – |
| [WI-0062](WI-0062-engine-arming.md) | Engine: arming, re-arming, fired events, `TriggerVariables` | L | WI-0060, WI-0061 |
| [WI-0063](WI-0063-timer-and-startup-triggers.md) | `Trigger_Periodic_Timer` and `Trigger_Start_up` | M | WI-0062 |
| [WI-0064](WI-0064-hotkey-trigger.md) | `Trigger_Hotkey` with window conditions, window identification, input tests | L | WI-0062 |
| [WI-0065](WI-0065-flow-status-elements.md) | `Action_Set_Flow_Status` and `Condition_Flow_Enabled` | M | WI-0060, WI-0062 |
| [WI-0066](WI-0066-runaway-guard.md) | Guard against runaway flows (REQ-EXE-170) | M | WI-0060, WI-0062 |
| [WI-0067](WI-0067-acceptance-s3.md) | Acceptance S0003 | M | all |

**Order.** WI-0060 and WI-0061 first (they share only `doc/PROTOCOL.md`, in different sections), then WI-0062, then WI-0063 to WI-0066 in any order (WI-0064 starts with its spike; WI-0066 sets the defaults of the limits from its measurement), then WI-0067. As in S0002 the column "Depends on" is binding, the order is not.

**Load path (F-0073).** Loading `FlowState.json` and arming at start add to the start of the engine. WI-0060 and WI-0062 run `tests/stress/test_big_flows.py` at their end (WI-0062 with enabled timer triggers in the big flows) and record the time to ready and the largest snapshot answer; budget as in S0002 (3 s, E0042).

**Files with conflict risk in S0003:** `doc/PROTOCOL.md` (WI-0060, WI-0061, WI-0062, WI-0066), `doc/ELEMENT-API-V2.md` (WI-0061, WI-0062, WI-0064, WI-0065), `doc/MIGRATION.md` (every package), `src/engine/Engine.ahk` and `src/engine/Executor.ahk` (WI-0060, WI-0062, WI-0065, WI-0066), `tests/integration/test_corpus.py` (WI-0062, WI-0065, WI-0067).

### Acceptance S0003

- The triggers of enabled flows are active after the start of AutoHotFlow, after a restart of the engine and after a restart of the trigger host; the enabled state survives a restart of AutoHotFlow; a flow file in the v1 format loads disabled (REQ-EXE-070, REQ-TRG-020, REQ-ROB-040, E0058).
- Every trigger of S0003 has e2e tests; the hotkey also with real input (E0059): the normal tests in the tiers, the `gui` tests run by the owner.
- An error of one trigger stops neither the others nor the host; the host keeps reacting while the engine is busy (measurement, REQ-TRG-010).
- The adapted v1 flow "Trigger test" runs headless and green (E0061); "variable test" runs as saved again (M-0069 back).
- The guard stops a runaway flow and refuses starts over the limits (REQ-EXE-170), with the defaults that WI-0066 set from its measurement.
- The memory of the background processes is measured again with the real trigger host (REQ-PRF-030, E0040).
- Serial, parallel, `-m stress`, foundation and slow runs are green.

### Progress S0003

- [x] WI-0060  - [x] WI-0061  - [x] WI-0062  - [x] WI-0063  - [x] WI-0064  - [x] WI-0065  - [x] WI-0066  - [x] WI-0067 (step S0003 complete, 2026-10-17)
