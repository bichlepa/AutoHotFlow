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

## Acceptance criteria

- Golden data cases `evalparam` (if generated in WI-36) are equal or have a documented deviation; otherwise tests per content type based on the v1 code.
- Same result for an element inline and in the worker (test with the same flow in both modes).
- Runtime: evaluation of all parameters of an element with 10 parameters on average under 2 ms (measure, record in the result).

## Docs

`doc/ELEMENT-API-V2.md` 3 and 6 (mapping table `x_*` → `ctx`), `doc/MIGRATION.md`, `doc/PROTOCOL.md` 4.5 (format of the evaluated parameters in the job).

## Not part of this

`ctx.Request` and variables back from the worker (R4, S2), settings (S4).
