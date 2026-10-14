# WI-42 Parameter evaluation and `ctx` API

Size: M · Depends on: WI-38, WI-39, WI-40 · Blocks: WI-43, S2

## Goal

Elements get their parameters evaluated as in v1 (`x_AutoEvaluateParameters`), with the new expression language, and have access via `ctx` to all variable functions that the v1 elements use. This lets S2 port the first real elements.

## Read first

README of this phase (E25, E26, E28), `v1/Source_Execution/API/API for Elements.ahk` lines 1 to 460, `doc/ELEMENT-API-V2.md` 1 to 3, `src/elements/base/ExecContext.ahk`, `src/worker/WorkerContext.ahk`, `src/engine/Executor.ahk`, `src/engine/WorkerBridge.ahk`.

## Tasks

1. **`Lang()`** into `src/core/` (E28): reads `language/*.ini` (copy from `v1/language/` to `assets/language/`, unchanged), placeholder `%1%` as in v1, language fixed for now (setting comes in S4), missing key → the key itself and an `f3` log entry. All roles can use it.
2. **`ctx.EvalParams(params, skipList := "")`** with the content types of v1: `String` (`%var%` substitution, `contentConvertObjects`), `Expression`, `number`, `positiveNumber`, `integer`, `positiveInteger`, `positiveIntegerOrZero` (checks as in v1, messages via `Lang` as in v1), `VariableName` (substitution plus name check), `RawString`/empty (unchanged), field types `file`/`folder` (substitution plus full path relative to the working directory, v1 `x_GetFullPath`; default until S4 is `A_MyDocuments "\AutoHotFlow"` as in v1 `FlowWorkingDir`), `WarnIfEmpty`, `contentID` (content type taken from another parameter), `label`/`button` are skipped. Errors: `ElementError` with the v1 message (the thread ends with `exception`). Additionally `ctx.EvalMoreParams(evaluated, params, names)` for `x_AutoEvaluateAdditionalParameters`.
3. **Worker elements (E26):** The engine evaluates all parameters before sending the job and sends values plus errors per parameter; `WorkerContext.EvalParams` returns these values and throws at the first error of a parameter that is not skipped. Side effect (assignment in skipped parameters) goes into MIGRATION.
4. **Variable functions on `ctx`** (from the 88 v1 helpers in use, only the variable group): `GetVar`, `SetVar(name, value, scope, hidden)`, `DeleteVar`, `GetVarType`, `GetVarLocation`, `ListVars(scope)`, `ReplaceVariables(text, convertObjects)`, `EvaluateExpression(text)`, `EvaluateScript(text)`, `CheckVarName(name)`, `ExportInstanceVars()`, `ImportInstanceVars(map)`. Signatures in ELEMENT-API 3; what works in the worker (read from the copy) and what only comes with R4 (S2) is noted there.
5. **Test element** from WI-39 used: one parameter of each content type; integration tests for each rule from task 2, inline and in the worker.
6. **Error output:** Warnings from the evaluator (type errors, missing variable) as an `f1` log entry with flow, element and parameter.
7. **Flow option `strictTypes` (E34, decided 2026-10-14):** a flow setting, `false` for migrated flows (formatVersion and v1Text marker of WI-39), `true` for new flows. In strict mode a type error in an evaluation (comparison or calculation, as E25 describes it) is an element error (`exception`) instead of an empty result with a warning; in compatibility mode E25 stays. Tests for both modes, inline and in the worker. The display of the `f1` warnings in the editor is not part of this package (S4/S5). Record the flow setting in the flow format (doc/PROTOCOL.md, doc/ARCHITECTURE.md section 7).

## Acceptance criteria

- Golden data cases `evalparam` (if generated in WI-36) are equal or have a documented deviation; otherwise tests per content type based on the v1 code.
- Same result for an element inline and in the worker (test with the same flow in both modes).
- Runtime: evaluation of all parameters of an element with 10 parameters on average under 2 ms (measure, record in the result).

## Docs

`doc/ELEMENT-API-V2.md` 3 and 6 (mapping table `x_*` → `ctx`), `doc/MIGRATION.md`, `doc/PROTOCOL.md` 4.5 (format of the evaluated parameters in the job).

## Not part of this

`ctx.Request` and variables back from the worker (R4, S2), settings (S4).

## Result

- **Code:** `src/core/Lang.ahk` and `LangTable.ahk` (`Lang()` for every role; the v1 files copied unchanged to `assets/language/basic/`, English until S4); `src/elements/base/ParamEvaluator.ahk` (port of `x_AutoEvaluateOneParameter`); `ExecContext` (`EvalParams`, `EvalMoreParams`, `GetVarType`, `GetVarLocation`, `ReplaceVariables`, `EvaluateExpression`, `EvaluateScript`, `CheckVarName`, `ExportInstanceVars`, `ImportInstanceVars`); `VarAccess.ExportInstance`/`ImportInstance`; `FlowDefinition.StrictTypes` and the key `flowSettings.strictTypes`; `Executor` (class and mode on the context, evaluation of worker parameters before the job), `WorkerBridge` (field `evaluated` of `cmd.worker.run`), `Worker`/`WorkerContext` (parameters from `evaluated`, `GetVar`/`GetVarType` from the imported copy). Test elements `Action_TestExprParams` (now with every content type, it evaluates and reports) and `Action_TestExprParamsWorker`.
- **Rules:** `doc/ELEMENT-API-V2.md` section 3 (table with the worker column) and 3.1 (evaluation per content type), section 6 (mapping table); `doc/PROTOCOL.md` 4.5 (`evaluated`) and 4.2 (`strictTypes` in the saved file); `doc/ARCHITECTURE.md` 7 (`strictTypes`) and 8 (`Lang`, `assets/language`); `doc/MIGRATION.md` M-25, M-26, M-43 (compatibility mode), M-46 (language), M-47 (strict mode), M-48 (evaluation); `doc/HOW-TO.md` four entries; `doc/EXPRESSION-LANGUAGE.md` points to ELEMENT-API 3.1.
- **Decisions taken here** (also in the report of the package):
  - Golden data `evalparam`: not generated (open action 1 of `doc/OPEN-ITEMS.md`). The checks after the evaluation are simple and were read from the v1 code; what decides the result (expressions, substitution, name rule) has golden data already. The behaviour of v1 `is number`, `is integer` and `>=` with texts was run in the v1 interpreter instead (14 values, HOW-TO entry); the tests per content type follow the v1 code. Alternative: a copy of `x_AutoEvaluateOneParameter` in the v1 harness (it would test a copy, not v1).
  - `strictTypes` lives in `flowSettings` (where v1 keeps the settings of a flow), as a JSON boolean. A flow without the key is a migrated one (false), also a file that v2 saved before WI-42, because v2 creates no flows before S4. `FlowDefinition.NEW_FLOW_STRICT_TYPES` (true) is for `cmd.flow.create` in S4. `Raw` is not changed; `cmd.flow.get` shows the key only when the file had it.
  - Strict mode turns every warning of the evaluator into an error (type error, division by zero, a failing function), not only type errors: E25 treats all of them alike. A missing variable is no error in either mode.
  - The first error stops `EvalParams` (v1 went on and reported the last one); errors are exceptions (guideline 4). M-48.
  - A missing parameter gets the `default` of its description (v1 fills defaults when it loads a flow); v2 does it at evaluation, the definition is not changed.
  - The log level of a missing variable stays `f0` (as v1 and the evaluator), warnings `f1`; every entry names the parameter (`parameter 'X': ...`) and the element (source) and the flow (flow ID). The work item said `f1` for both; `f0` is the more visible level.
  - `ctx.EvaluateExpression` and `EvaluateScript` return the value and throw `ElementError` with the error text (v1 elements finished with `res.error`); in strict mode also for a warning.
  - Worker: `GetVar`/`GetVarType` read the imported copy; the other variable functions throw until R4. Map values cross JSON and get their Integer keys back in the worker (rule of `VarValues.NormKey`, repeated in `WorkerContext` because the worker role cannot include `engine/vars`).
  - `ctx.VarLocation` (WI-40) stays as an alias of `GetVarLocation`.
- **Runtime (acceptance criterion):** `EvalParams` of an element with 10 parameters (5 expressions, 2 substitutions, a variable name, a path, a raw text) 0.36, 0.41 and 0.38 ms per call, three runs of `tests/ahk/helpers/evalparams_bench.ahk` (2000 calls each, parse cache hit). The first evaluation of a new text adds its parse time (doc/EXPRESSION-LANGUAGE.md section 12).
- **Tests:** `tests/ahk/core_lang.test.ahk` (9), `tests/ahk/engine_flow_strict.test.ahk` (6), `tests/ahk/element_evalparams.test.ahk` (40: every content type and rule inline, the same cases again through the real Executor, the stand-in pool and a real `WorkerContext` after a JSON round trip, both modes), `tests/integration/test_worker.py` (2 new: `evaluated` in a real worker process, `bad_payload`), `tests/fault/test_param_eval.py` (slow: the same flow inline and in a worker under the real supervisor: values, error, skipped parameter, both modes). Runs: on commit `6668552` (the code of this package; the result section changes no code): fast tier `20261014-172621-66685524` (627 passed, exit 0), slow tier `20261014-172621-66685524-2` (87 passed, 2 xfailed: the known F-17 and F-85, exit 0), foundation tier `20261014-172719-66685524` (443 passed, 1 skipped, exit 0); no INTERNALERROR. `tools/arch_check.py`: 0 violations.
- **Tool fix on the way:** `tools/run_suite.py` gave two runs of one commit started in the same second the same folder; the second removed the worktree of the first (exit 5, no tests). Fixed in its own commit (`new_run_dir`, test in `tests/test_run_suite.py`).
- **Not checked:** the GUI and the editor display of the warnings (S4/S5, not part of this package); the private flows of the owner; triggers (S3); a real element of v1 ported with `EvalParams` (S2); the memory of many worker jobs with large `evaluated` lists.
