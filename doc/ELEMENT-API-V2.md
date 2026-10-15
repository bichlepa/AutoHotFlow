# Element API v2

Status: Draft. Basis for porting the 152 v1 elements (114 actions, 17 conditions, 5 loops, 16 triggers).
Predecessor: the v1 function family `Element_<Task>_<Class>` and the helpers `x_*` (see `v2-phase2-final:work_items/ANALYSE.md`, section 2).

---

## 1. Guidelines

1. **One class per element**, one file per class. The class name is identical to the v1 class ID (`Action_Sleep`, `Trigger_Hotkey`), because this string is stored in the `class` field of saved flows. Resolution is case-insensitive (v1 writes `trigger_manual` and `Trigger_Manual`). Together with its package the class is the identity of the element (E0045): the qualified ID `Default.Action_Sleep` (section 2).
2. **All methods are `static`.** Elements are stateless. The state of one execution lives in `ctx.State`.
3. **The context `ctx` replaces `Environment` and all `x_*` functions.** It has fixed, lowercase fields (`flowId`, `elementId`, `instanceId`, `threadId`). The inconsistent spelling from v1 goes away.
4. **Errors are exceptions.** `throw ElementError(msg)` ends the execution with result `exception` and the message. The engine wraps every call in `try/catch`, so element code cannot crash it.
5. **Parameters are evaluated by `ctx.EvalParams`.** `Run` receives the parameters as they are stored; the element evaluates them with `ctx.EvalParams(params)` as v1 did with `x_AutoEvaluateParameters` (section 3.1). The engine owns the variables: for a worker element it evaluates all parameters before the job is sent, and `ctx.EvalParams` in the worker returns these values (E0026, WI-0042). Triggers: S0003.
6. **An element declares its execution mode** (`inline`, `worker`, `trigger`). See ARCHITECTURE 2.3.
7. **No global variables, no `%var%` access, no `ErrorLevel`.**

---

## 2. Class contract

```ahk
class Action_Example extends AhfElement {
    ; --- Metadata (static, cheap, no side effects) ---
    static Mode      := "inline"        ; "inline" | "worker" | "trigger"
    static Level     := "Beginner"      ; "Beginner" | "Advanced" | "Programmer"
    static Stability := "Stable"        ; "Stable" | "Experimental"
    static Icon      := "example.ico"   ; file name in Icons/ of the package, "" = none
    static JobTimeoutMs := 0            ; worker only: job deadline in ms, 0 = none (WI-0027, ARCHITECTURE 6.4)

    static Name()     => Lang("Example")            ; display name
    static Category() => Lang("General")

    ; --- Editor side (runs in the editor process) ---
    static Parameters(ctx) => [ ... ]                      ; field description (schema as in v1)
    static GenerateName(ctx, params) => Lang("Example")    ; name with parameters
    static CheckSettings(form, params, staticValues) {     ; enable/disable fields
        form.Disable("WhenRelease", params.BlockKey)
    }

    ; --- Runtime side (engine, worker or trigger host) ---
    static Run(ctx, params) {          ; Action, Condition, Loop
        ctx.Finish("normal")           ; exactly once (or later via timer/callback)
    }
    static Stop(ctx, params) {         ; optional: abort (the timers of ctx are cancelled automatically)
    }
}
```

**Trigger** (`Mode := "trigger"`) has `Enable`/`Disable`/`TriggerVariables` instead of `Run`/`Stop`:

```ahk
    static Enable(ctx, params)  ; arm. Return: optional message. throw on error.
    static Disable(ctx)         ; disarm
    static TriggerVariables(params, data) => Map()   ; pure function, runs in the engine
```

`TriggerVariables` replaces `Element_postTrigger_*`: it returns the thread variables (name → value) that are set after the event, and it must not have side effects (it runs in the engine, no I/O).

**Worker elements and blocking (WI-0027, ARCHITECTURE 6.4):** A worker element may block for any length of time within a single call (download, COM, `DllCall`, dialog). A worker with a job is never pinged and never ended as hanging. Two consequences: an abort (stop of the instance) does not reach an element that is blocked in a single call. After 2 s without an acknowledgement, the engine has the whole process terminated (only one job runs per worker, so nothing else is lost); `Stop(ctx, params)` of the element then no longer runs, so cleanup in the element is not possible there. And: without `JobTimeoutMs` the job has no deadline (v1 had none). If a class sets `JobTimeoutMs` > 0, the thread ends after this time with the result `exception` and the message "worker timeout", and the element is terminated as on an abort. The deadline is a class value, not a parameter; a flow parameter (e.g. "Timeout" for a download) remains the responsibility of the element.

**Class ID and qualified ID (E0045, WI-0047):** an element is identified by its package and its class. Each package is an AutoHotkey class whose body includes the element files of the package (the generated block, below), so an element class is a nested class and its type name is the qualified ID `<package>.<class>`, for example `Default.Action_Sleep`. The registry, the worker jobs (`cmd.worker.run`), the trigger arming (`cmd.trigger.arm`) and the logs use this ID, so two packages may have a class of the same name. A flow element names the package in `package` and the class in `class`, as v1 wrote them; a missing or empty `package` means `Default`, and the lookup ignores case (`ElementRegistry.Lookup(package, class)`; 8 elements of the test flows write `default`). Do not read the ID via `cls.Name`: a class with `static Name()` hides the built-in property, so `cls.Name` is then a function. The ID is provided by `ElementRegistry.IdOf(cls)` (internally `Type(cls())`). Verified in WI-0009 and WI-0047.

**Inside an element file** (consequences of the nested class, verified 2026-10-15): the class has no global name, so its static methods refer to it as `this` (`this.ToMs(params)`), never by its own name, which would be an unset variable at run time (the generator refuses it). The file holds the class and comments only: no `ElementRegistry.Register` line (the generated block registers the class) and no other code at file level. Its `#Include` lines name the base class (`..\..\base\AhfElement.ahk`) and shared code in `lib/` of the package. The generator includes these files before the package class; inside the class body AutoHotkey then skips them, because it includes a file only once (an `#Include` of a new file inside the body would make the file part of the class, so `#IncludeAgain` is refused). A class file never includes another class file (F-0081).

**Package name and AutoHotkey class name (decision of WI-0047):** the package class has the name of the package, unchanged, so that the type name is the qualified ID and nothing has to be translated. A package name is therefore a safe AutoHotkey class name: ASCII letters, digits and `_`, starting with a letter, at most 64 characters; not a reserved word or built-in name of AutoHotkey (`Map`, `Loop`, `Error`, ...); not starting with `Ahf` (the prefix of the classes of AutoHotFlow itself, doc/CONVENTIONS.md); not the name of a global class or function of the code (`Engine`, `Lang`, ...). It equals the name of the folder and is unique without regard to case, test packages included. `tools/gen_element_includes.py` refuses any other name, with the file name. v1 has only the package `Default`. A package of another author whose name does not fit (spaces, hyphens) needs a mapping once packages can be installed (REQ-PKG-020); the alternative, a prefix for every package class (`Pkg_Default`), was not taken, because the type name would then not be the qualified ID. A local variable with the name of a package shadows the package class in its function (doc/HOW-TO.md).

**Package layout and generated block (E0037, E0041, WI-0047):** a package is a folder `src/elements/<package>/` (test packages: `tests/elements/<package>/`, which only the test entries include: `Test` with the test elements `Action_Test*`, and `TestTwin`, which has classes of the same names as `Test`, so that a test can tell two packages apart):

| Path in the package | Content |
|---|---|
| `package.json` | `name` (the folder name), `version` (`Default`: 1.2.1, as the manifest of v1), `description`, `author`, `website`, `license`. The version is registered with the package (`ElementRegistry.PackageVersion`), so that `package` and `packageVersion` of a flow element can be checked |
| `Actions/`, `Conditions/`, `Loops/`, `Triggers/` | one class file each, as in v1; the class name starts with `Action_`, `Condition_`, `Loop_` or `Trigger_` according to the folder. A folder exists once the package has an element of that kind |
| `lib/` | shared code of the classes, no element class and no `Mode` line |
| `language/<code>.ini` | the texts of the package (the v1 files, unchanged, UTF-16): `Lang()` finds their keys in every role (`core/LangTable.ahk` reads the language folders of all packages after `assets/language`) |
| `Icons/` | the icons of the classes (`static Icon` is a file name in this folder; the v1 files, unchanged) |
| `_includes_<role>.ahk` | generated, see below |

`python tools/gen_element_includes.py` writes, per package and per role, the block `<package>/_includes_<role>.ahk`: the files that the selected class files include, then `class <package> { #Include <class file> ... }`, then `ElementRegistry.RegisterPackage(name, version)` and one `ElementRegistry.Register(<package>.<class>)` per class; and, per role, `src/entry/generated/Elements_<role>.ahk` (test packages: `tests/integration/helpers/entry/generated/TestElements_<role>.ahk`), which includes the blocks of all packages and which the role entry includes. The blocks are committed and never edited by hand; `tests/test_element_includes.py` fails when a block is stale or superfluous (`--check`; VS Code task `Tool: generate element include blocks`). No text substitution at run time.

**Registration:** the `Register` lines of the generated blocks run at load time, before `AhfMain`. So that an error there (duplicate class, invalid `Mode`, a class outside a package) does not show a dialog, the shared boot code `src/AhfBoot.ahk`, which every entry script includes first, sets `OnError` as its first executable statement, **before** the `#Include` lines of the roles and of the element classes (handler `AhfLoadError`: message to stderr, exit 1). (Decision WI-0022: the registration is not moved into a function. Since WI-0047 the generated block registers the classes, so an element file has no code at file level at all.) The registry is a `Map` with `CaseSense := "Off"`, keyed by the qualified ID; `ElementRegistry.Register` refuses a class whose type name is not `<package>.<class>`. **Registration per role (E0041, WI-0047-PREP):** a process registers only the classes that its entry script includes. The block of a role is generated from the literal `static Mode := "inline"` (or `"worker"`, `"trigger"`) of each class file, which the tool reads as text: write `Mode` as a plain string literal on a line of its own (no expression, no inherited value, no second `Mode` line), otherwise the generation fails with the file name. The engine and the editor register all classes (the engine needs `Parameters("")` of every class for the conversion, WI-0039, and `Run`/`Stop` of the `inline` ones), the trigger host the `trigger` classes, a worker the `worker` classes; supervisor, storage, debug and manager none. Every role with a block registers every package (also one with no class of its modes), so a process can tell an unknown class of a known package from a package that is not installed (`ElementRegistry.MissingText`). So a class must not call code of a class of another mode, and a worker class must not include an inline class. A class that is not in the block of a role does not exist in that process: `ElementRegistry.Get` returns `""`. The class file includes `AhfElement.ahk`, which includes `core/Lang.ahk`, so `Lang()` is available in every role that holds classes.

**Parameters that the element evaluates itself (WI-0039):** the loader of flows converts the texts of all parameters with an expression content type from v1 syntax into the new language (`content` is `Expression`, `number`, `positiveNumber`, `integer`, `positiveInteger` or `positiveIntegerOrZero`, or `content` is a list and the parameter named by `contentID` holds one of these). A parameter that the element itself evaluates as an expression or script (v1: `x_EvaluateExpression` or `x_EvaluateScript` on a `RawString`, e.g. `Action_Script`) has no such content type; the class names it in `static V1Syntax := Map("Script", "script", "Condition", "expression")`. The loader calls `Parameters("")` in the engine, so `Parameters()` must not need the editor (`ctx`) for the ids and content types; if it throws, the element's texts stay in v1 syntax and the element is marked (ARCHITECTURE 7). `Test.Action_TestExprParams` (`tests/elements/Test/Actions/`) has one parameter of each kind.

**Parameter container:** `params` is an object with case-insensitive property access (`params.Duration` equals `params.duration`), as v1 uses it. Variable stores, on the other hand, are `Map` objects with `CaseSense := "Off"`, so that variable names remain case-insensitive as in v1 and v2 objects are not confused with them.

---

## 3. Context `ctx`

| Member | Replaces (v1) | Remarks |
|---|---|---|
| `ctx.flowId`, `.elementId`, `.instanceId`, `.threadId` | `Environment.FlowID` etc. | fixed spelling |
| `ctx.EvalParams(params, skipList := "")` | `x_AutoEvaluateParameters` (with `p_skipList`) | Returns the evaluated parameters as an object with case-insensitive properties; throws `ElementError` with the v1 text at the first error (no `_error`). Rules: section 3.1. `skipList`: an Array of ids or a text with commas; skipped parameters are not in the result. In a worker: the values that the engine evaluated before the job (E0026). |
| `ctx.EvalMoreParams(evaluated, params, names)` | `x_AutoEvaluateAdditionalParameters` | Evaluates the parameters `names` (Array or text with commas) into `evaluated` and returns it (a new object if `evaluated` is not one). Errors as `EvalParams`. |
| `ctx.Finish(result, msg := "")` | `x_finish` | `result`: `normal`, `yes`, `no`, `exception`, `head`, `tail` |
| `ctx.SetVar(name, value, scope := "", hidden := false)` | `x_SetVariable` | The name decides the scope as in v1 (WI-0040, doc/EXPRESSION-LANGUAGE.md section 18.2): `A_` names are loop or thread variables and need `scope` `"thread"` or `"loop"`; `global_` and `static_` names are global and static; any other name is an instance variable. Returns 1, or 0 if refused (logged `f0` with the v1 text). The value is copied; an Array becomes a `Map` with the keys 1..n. Worker: through the engine (section 3.2). |
| `ctx.GetVar(name, default := "", hidden := false)` | `x_GetVariable` | Reads a variable or a member (`"list.1"`) where its name says (an `A_` name: loop, thread, then built-in). Returns a copy, or `default` if it does not exist (no log). Worker: through the engine (section 3.2), every kind of variable. |
| `ctx.DeleteVar(name, hidden := false)` | `x_DeleteVariable` | Deletes a variable or a member; 1 if it existed. Built-in variables cannot be deleted. |
| `ctx.GetVarLocation(name, hidden := false)` (alias `ctx.VarLocation`, WI-0040) | `x_GetVariableLocation` | `"loop"`, `"thread"`, `"builtin"`, `"instance"`, `"static"`, `"global"` or `""`. `ctx.VarLocation` is the same (name of WI-0040). |
| `ctx.GetVarType(name, hidden := false)` | `x_getVariableType` | `"object"`, `"normal"`, or `""` if the variable does not exist. |
| `ctx.ListVars(scope := "")` | `x_GetListOf*Vars` | names of the visible variables of one scope, or of all scopes (`""`) in the order loop, thread, instance, static, global. |
| `ctx.ReplaceVariables(text, convertObjects := false)` | `x_replaceVariables` | `%name%` substitution (doc/EXPRESSION-LANGUAGE.md section 18.5); `convertObjects` is the v1 option `ConvertObjectToString`. |
| `ctx.EvaluateExpression(text)` | `x_EvaluateExpression` + `if (res.error)` | Returns the value. Throws `ElementError` with the errors of the evaluator (line, column, marked line), as v1 finished with `res.error`. In strict mode (flow option `strictTypes`, E0034) a warning (type error, division by zero) throws too; in compatibility mode the failed part is the empty text and an `f1` entry (E0025). |
| `ctx.EvaluateScript(text)` | `x_EvaluateScript` + `if (res.errors)` | The value of the last statement; errors as `EvaluateExpression`. |
| `ctx.CheckVarName(name)` | `x_CheckVariableName` | 1 if valid (not empty, no digit at the start, no forbidden character), else 0. Also in a worker. |
| `ctx.ExportInstanceVars()` | `x_ExportAllInstanceVars` | A copy (`Map` name → value) of the visible instance variables; v1 returned the object itself. |
| `ctx.ImportInstanceVars(vars)` | `x_ImportInstanceVars` | Sets every entry of the `Map` as an instance variable, whatever the prefix of the name (as v1); an empty name or one with a forbidden character is skipped (`f0`). |
| `ctx.GetElementIdsOfClass(className)` | `x_getAllElementIDsOfClass` | The IDs of the elements of the own flow that have the class (`"Action_Trace_Point"`, package Default, or `"<package>.<class>"`; any case), in the order of the flow file (sorted by ID); the newest committed revision of the flow (WI-0052). Inline only (a worker throws). v1 could ask for any flow; v2 asks for the own flow |
| `ctx.GetElementPars(elementId)` | `x_getElementPars` | The stored (not evaluated) parameters of an element of the own flow, an object with case-insensitive properties, a copy. Unlike the `params` of `Run` the values keep their type: a list is an `Array`, an object a `Map` (the `params` of `Run` have the empty text instead), a JSON null is the empty text. Throws `ElementError` if the flow has no such element. Inline only (WI-0052) |
| `ctx.StopInstance(reason := "element.stop")` | `x_InstanceStop` | Stops the instance of the element with all its threads; it ends with the reason (PROTOCOL 4.3). Returns false if it is not running. To finish and stop, call `Finish` first, then `StopInstance`, as v1 (the finish is then effective and its connection decided before the stop). Inline only (WI-0052) |
| `ctx.After(ms, fn)` | `x_NewFunctionObject` + `SetTimer` | timer belongs to the execution and is cancelled automatically on stop/end |
| `ctx.State` | `x_SetExecutionValue`/`x_GetExecutionValue`, `x_SetTriggerValue`/`x_getTriggerValue` | object per execution (Run) or per armed trigger |
| `ctx.Fire(data := "")` | `x_trigger` | triggers only. Sends `evt.trigger.fired` |
| `ctx.Log(level, text)` | `x_log` | levels `f0` to `f3` |
| `ctx.GetImport(name, default := "")`, `ctx.Export(name, value)` | `p_VarsToImport`, `p_VarsToExport` of `x_ExecuteInNewAHKThread` | worker only: an explicit import list (empty from the engine since WI-0050, for `ctx.RunScript`, S0008) and values that the engine sets where their name says when the job ends (texts and numbers) |
| `ctx.Request(type, payload, callback, timeoutMs := 5000)` | – (new) | A `cmd.*` request to the engine with callback, `execId` added to the payload (WI-0050). Returns at once; `callback(answerPayload)` runs later on a thread of its own (it may call the variable functions), not at all when the element has ended or was stopped. An exception in the callback ends the element with `exception`. Workers only (triggers: S0003); inline it throws. |
| `ctx.RunScript(code, imports, exports)` | `x_ExecuteInNewAHKThread` | for AHK code elements. Always runs as a worker. |
| `Lang(key, args*)` | `x_lang` | global function, language files unchanged |
| `form.Disable(id, cond)`, `form.Enable(id, cond)` | `x_Par_Disable`/`x_Par_Enable` | only in `CheckSettings` |
| `form.SetValue(id, v)`, `form.SetChoices(id, list)`, `form.SetLabel(id, text)` | `x_Par_SetValue` etc. | – |

The number of v1 helpers (`x_*`) actually used is 88. The most frequent: `x_lang` (2211 calls), `x_finish` (681), `x_Par_Disable`/`Enable` (~420), `x_SetVariable` (171), `x_AutoEvaluateParameters` (129).

### 3.1 Parameter evaluation (WI-0042)

`ctx.EvalParams` is the port of v1 `x_AutoEvaluateParameters` and `x_AutoEvaluateOneParameter` (`v1/Source_Execution/API/API for Elements.ahk:60` to `:369`), code in `src/elements/base/ParamEvaluator.ahk`. It walks `Parameters(ctx)` of the class in order. An entry without `id` and an entry of type `Label` or `Button` is skipped; an `id` that is an Array stands for several parameters with the same description. A parameter that the flow does not have gets the `default` of its description (v1 fills the defaults in when it loads a flow). The value is evaluated by the content type (`content`; an Array means the user selects the type in the parameter named by `contentID`, default `contentDefault`):

| Content type / field type | Evaluation | Error (v1 text, `Lang`) |
|---|---|---|
| type `file` or `folder` | `%var%` substitution, then the full path: a relative path (also the empty one, Shlwapi `PathIsRelative`) is put below the working directory of the flow (`A_WorkingDir`, until S0004 `A_MyDocuments "\AutoHotFlow"`, E0028) | `WarnIfEmpty` and empty after the substitution: `String '%1%' is empty` |
| `String` | `%var%` substitution; with `contentConvertObjects` an object gives its JSON text | `WarnIfEmpty`: `String '%1%' is empty` |
| `Expression`, `number`, `positiveNumber`, `integer`, `positiveInteger`, `positiveIntegerOrZero` | the expression (doc/EXPRESSION-LANGUAGE.md section 17), the value keeps its type (`Integer`, `Float`, text, `Map`) | evaluator error: `An error occured while parsing expression '%1%'`, an empty line and the errors (line, column, marked line); `WarnIfEmpty` and empty result: `Result of expression '%1%' is empty`; a result that is not empty is checked: `is not a number` (number types, `IsNumber`), `is not an integer` (integer types, `IsInteger`: `4/2` is an Integer by E0029, `1.5*2` is a Float), `is not a positive number` (`positiveInteger`, below 1), `is not a positive number or zero` (`positiveIntegerOrZero`, `positiveNumber`, below 0). As in v1 the checks run one after the other and the last failing one gives the message; a text that is not a number compares alphabetically with 1 or 0 there (v1 `>=`) |
| `VariableName` | `%var%` substitution, then the name rule (`ExprNames.Check`, v1 `Var_CheckName`) | `Variable name '%1%' is not valid.` (an empty name only with `WarnIfEmpty`) |
| `RawString` or none | unchanged (a number in the file stays a number) | `WarnIfEmpty`: `Parameter '%1%' is empty` |
| anything else | unchanged | `Parameter '%1%' has unsupported content type` |

- **Errors** end the evaluation at the first parameter (in the order of `Parameters()`) with an error: `ElementError` with the text, so the element ends with `exception` (unless it catches it). v1 evaluated the rest and reported the last error (MIGRATION M-0048).
- **Strict mode** (flow option `strictTypes`, E0034, ARCHITECTURE 7): a warning of the evaluator (a type error in a comparison or calculation, a division by zero, a failing function) is an error of the parameter, with the warnings in place of the errors in the text. In compatibility mode (migrated flows) the failed part is the empty text (E0025). A missing variable is no error in either mode (it gives the empty text; used in a calculation that is a type error).
- **Log:** every entry of the evaluator goes to the log of the element with the parameter: `f1` for errors and warnings (`parameter 'X': Expression warning: ...`), `f0` for a missing variable (as v1), with the flow ID. The editor shows the `f1` warnings later (S0004/S0005). The `f0` entry of a missing variable in a `%var%` substitution comes from the variable model (doc/EXPRESSION-LANGUAGE.md section 18.5).
- **Worker elements (E0026):** the engine evaluates all parameters before it sends the job, with the variables and the mode of the engine, and sends one entry per parameter: the value or the error (`cmd.worker.run`, field `evaluated`, PROTOCOL 4.5). `ctx.EvalParams` in the worker returns these values and throws at the first error of a parameter that is not skipped; `EvalMoreParams` reads the same entries. An assignment in a parameter that the element skips has therefore run already (MIGRATION M-0048).
- **Runtime:** measured in WI-0042 (`tests/ahk/helpers/evalparams_bench.ahk`); see the result of the work item.

### 3.2 Variables in a worker element (WI-0050, ARCHITECTURE R0004)

A worker element has the same variable functions as an inline element: `GetVar`, `SetVar`, `DeleteVar`, `GetVarType`, `GetVarLocation`/`VarLocation`, `ListVars`, `ReplaceVariables`, `EvaluateExpression`, `EvaluateScript`, `ExportInstanceVars`, `ImportInstanceVars` (`CheckVarName` needs no engine).

- **Every call asks the engine** (`cmd.engine.var.*`, PROTOCOL 4.5) and waits for the answer; the worker may wait (its own process), the engine answers at once and never waits. The engine runs the same function with the context of the element, so the result is the one the element gets inline: every kind of variable (loop, thread, instance, static, global, hidden, built-in), the type mode of the flow, the same log entries, the same error texts. Measured round trip: about 1 ms (`doc/MEASUREMENTS.md` MS-0031).
- **No copies:** the job carries no copies of the variables, and nothing is cached in the worker. A variable that another thread changes meanwhile is seen at the next call; an element reads what it has written (MIGRATION M-0045).
- **Errors:** an error of the operation throws `ElementError` with the inline text. Without an answer within 5 s, or when the engine went away, the function throws `ElementError` "engine did not answer ...". After a stop of the instance (or the end of the job by its deadline) the engine answers `gone`, and the function throws: the element ends; its result is discarded.
- **Rules for element code:** do not call the variable functions while the thread is `Critical` (the answer cannot be handled then; the call ends with "engine did not answer" after the timeout). From the element's `Run`, from `ctx.After` timers and from `ctx.Request` callbacks they work.
- **Values:** as in variables (texts, numbers, `Map` objects; an `Array` becomes a `Map` with the keys 1..n). A Float that is not finite (`inf`, `nan`) becomes its text on the way to the engine (JSON has no such number); any other object is refused with the error of the variable model.

---

### 3.3 Dialogs (E0038, WI-0051)

An element never calls `MsgBox`, `InputBox`, `ToolTip`, `TrayTip`, `FileSelect` or `DirSelect` itself. It calls `Dialogs.MsgBox(text, title, options)`, `Dialogs.InputBox(prompt, title, options, defaultText)`, `Dialogs.ToolTip(text, x?, y?, which)`, `Dialogs.FileSelect(options, root, title, filter)` and `Dialogs.DirSelect(root, options, prompt)` (`src/elements/base/Dialogs.ahk`, included by `AhfElement.ahk`). They take the arguments and give the return value of the AutoHotkey function of the same name (`InputBox`: an object with `Value` and `Result`). The product shows the real dialogs. Where an element may call them does not change: only a `worker` element may block on a dialog (section 1), never the engine. More functions are added when an element needs them (S0008).

A test entry registers a provider (`Dialogs.UseProvider`) that answers from a script instead of opening a window: `tests/integration/helpers/TestDialogProvider.ahk`, how a test writes the script: `doc/TEST-STRATEGY.md` section 9a. The product entries cannot register one: they do not include the provider, and the architecture check (rule `dialog-seam`, `doc/CONVENTIONS.md` section 3) forbids `Dialogs.UseProvider` in `src/` and a direct dialog call in `src/elements/`. An element that is used in a test with a dialog must therefore not keep its own dialog code.

## 4. Example 1: `Action_Sleep` (inline, with timer)

**v1** (`v1/Source_Elements/Default/Actions/Sleep.ahk`, abridged):

```ahk
Element_run_Action_Sleep(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage)
		return
	}
	switch (EvaluatedParameters.Unit)
	{
	case "Milliseconds": duration := EvaluatedParameters.duration
	case "Seconds":      duration := EvaluatedParameters.duration * 1000
	case "Minutes":      duration := EvaluatedParameters.duration * 60000
	}
	functionObject := x_NewFunctionObject(environment, "Action_Sleep_EndSleep", ElementParameters)
	x_SetExecutionValue(Environment, "functionObject", functionObject)
	SetTimer, % functionObject, -%duration%
}
Element_stop_Action_Sleep(Environment, ElementParameters)
{
	functionObject := x_getExecutionValue(Environment, "functionObject")
	SetTimer, % functionObject, off
}
Action_Sleep_EndSleep(Environment, ElementParameters)
{
	x_finish(Environment, "normal")
}
```

**v2** (`src/elements/Default/Actions/Action_Sleep.ahk`, WI-0047, abridged; the class is `Default.Action_Sleep`):

```ahk
#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

class Action_Sleep extends AhfElement {
    static Mode      := "inline"
    static Level     := "Beginner"
    static Stability := "Stable"
    static Icon      := "Sleep.ico"                  ; in Icons/ of the package

    static Name()     => Lang("Sleep")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Duration")},
        {type: "edit", id: "Duration", default: 2, content: "Expression", WarnIfEmpty: true},
        {type: "Radio", id: "Unit", default: 2, result: "enum"
            , choices: [Lang("Milliseconds"), Lang("Seconds"), Lang("Minutes")]
            , enum: ["Milliseconds", "Seconds", "Minutes"]}
    ]

    static GenerateName(ctx, params) {
        switch this.UnitOf(params.Unit) {          ; the class is `this`: a nested class has no global name
            case "Milliseconds": d := params.Duration " " Lang("ms #Milliseconds")
            case "Seconds":      d := params.Duration " " Lang("s #Seconds")
            case "Minutes":      d := params.Duration " " Lang("m #Minutes")
        }
        return Lang("Sleep") ": " d
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)                  ; throws on error -> result "exception"
        ctx.After(this.ToMs(p.Duration, p.Unit), () => ctx.Finish("normal"))   ; timer is removed automatically on stop
    }

    static ToMs(duration, unit) { ... }              ; milliseconds; throws ElementError for a bad duration or unit
    static UnitOf(unit) { ... }                      ; "Seconds" for "seconds" or for the default index 2
}
```

The generated block of the package registers the class (`ElementRegistry.Register(Default.Action_Sleep)`); the file
has no code at file level.

What changes: no `Element_stop` needed any more (the context removes the timer), the error path is gone (exception), the callback is a lambda instead of a named function, a missing `Unit` (v1 stores the default index 2) means seconds, and a duration that is not a number of 0 or more ends with `exception` instead of a broken timer.
What stays the same: class ID, parameter IDs and schema, language keys, result strings, name format.

---

## 5. Example 2: `Trigger_Hotkey` (runs in the trigger host)

**v1** (`v1/Source_Elements/Default/Triggers/Hotkey.ahk`): `Element_enable_`, `Element_disable_`, `Element_postTrigger_`, callback `Trigger_Hotkey_Trigger` → `x_trigger(Environment)`. The hotkey is set with `hotkey, % fullHotkey, % functionObject, UseErrorLevel on`.

**v2:**

```ahk
#Requires AutoHotkey v2.0

class Trigger_Hotkey extends AhfElement {
    static Mode      := "trigger"
    static Level     := "Beginner"
    static Stability := "Stable"

    static Name()     => Lang("Hotkey")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) {
        p := [
            {type: "Label", label: Lang("Hotkey")},
            {type: "Hotkey", id: "hotkey"},
            {type: "Label", label: Lang("Options")},
            {type: "Checkbox", id: "BlockKey", default: 1, label: Lang("Block_key")},
            {type: "Checkbox", id: "Wildcard", default: 0, label: Lang("Trigger even if other keys are already held down")},
            {type: "Checkbox", id: "WhenRelease", default: 0, label: Lang("Trigger on release rather than press")},
            {type: "Label", label: Lang("Scope")},
            {type: "Radio", id: "UseWindow", default: 1, result: "enum"
                , choices: [...]   ; as in v1
                , enum: ["Everywhere", "WindowIsActive", "WindowExists", "WindowIsNotActive", "WindowNotExists"]}
        ]
        WindowFunctions.AddIdentificationParameters(p, {noExcludes: true})
        return p
    }

    static GenerateName(ctx, params) => Lang("Hotkey") " - " params.Hotkey

    static CheckSettings(form, params, staticValues) {
        form.Disable("WhenRelease", params.BlockKey)
        form.Disable("BlockKey", params.WhenRelease)
        showWin := params.UseWindow != "Everywhere"
        for id in ["TitleMatchMode", "Wintitle", "excludeTitle", "winText", "ExcludeText", "ahk_class", "ahk_exe"
                 , "ahk_id", "ahk_pid", "FindHiddenText", "FindHiddenWindow", "GetWindowInformation"]
            form.Enable(id, showWin)
    }

    ; params are evaluated (the engine has resolved the variables)
    static Enable(ctx, params) {
        if (params.hotkey = "")
            throw ElementError(Lang("The_Hotkey_is_not_set!"))

        full := params.hotkey
        if !params.BlockKey
            full := "~" full
        if params.WhenRelease
            full .= " UP"
        if params.Wildcard
            full := "*" full

        ctx.State.hotIf := Trigger_Hotkey._ContextFor(params)   ; function or ""
        ctx.State.full := full
        try {
            Trigger_Hotkey._SetContext(ctx.State.hotIf)
            Hotkey(full, (*) => ctx.Fire(), "On")
        } catch as e {
            throw ElementError(Lang("The hotkey %1% cannot be set!", full))
        } finally {
            HotIf()                                             ; reset the context
        }
        return Lang("The hotkey %1% was set.", full)
    }

    static Disable(ctx) {
        ; important: same context as when setting (v1 forgets this)
        Trigger_Hotkey._SetContext(ctx.State.hotIf)
        try Hotkey(ctx.State.full, "Off")
        HotIf()
    }

    ; pure function, runs in the engine
    static TriggerVariables(params, data) => Map("A_Hotkey", params.hotkey)

    ; window context via HotIfWinActive/HotIfWinExist/... or HotIf(fn)
    static _ContextFor(params) { ... }
    static _SetContext(hotIf) { ... }
}

ElementRegistry.Register(Trigger_Hotkey)
```

What changes: the engine evaluates the parameters and sends them to the trigger host (`cmd.trigger.arm`). `x_enabled`/`x_disabled` are dropped (return value or exception), and `Element_postTrigger_` becomes the pure function `TriggerVariables`.
What is improved (noted in [MIGRATION.md](MIGRATION.md)): `Disable` sets the same `HotIf` context as `Enable`. In v1, `hotkey, <key>, off` is called without a context, so a context-bound hotkey may remain active.
Additionally: in v1, in the error case of the window parameter in `Element_enable`, `x_finish` is called instead of `x_enabled` (`Hotkey.ahk` line 134). In v2 this pattern no longer exists; an error is always a `throw`.

---

## 6. Mechanical conversion rules

| v1 | v2 |
|---|---|
| `Element_run_<C>(Environment, ElementParameters)` | `static Run(ctx, params)` in `class <C> extends AhfElement` |
| `Element_getName_<C>()` etc. | `static Name()`, `Category()`, `Level`, `Stability`, `Icon` |
| `Element_getParametrizationDetails_<C>(Environment)` | `static Parameters(ctx)` |
| `Element_GenerateName_<C>(Environment, ElementParameters)` | `static GenerateName(ctx, params)` |
| `Element_CheckSettings_<C>(Environment, ElementParameters, staticValues)` | `static CheckSettings(form, params, staticValues)` |
| `Element_stop_<C>` | `static Stop(ctx, params)` (often unnecessary) |
| `Element_enable_<C>` / `Element_disable_<C>` / `Element_postTrigger_<C>` | `Enable` / `Disable` / `TriggerVariables` |
| `x_AutoEvaluateParameters` + `if _error` | `ctx.EvalParams` |
| `x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, list)` | `p := ctx.EvalMoreParams(p, params, list)` |
| `x_EvaluateExpression` + `if (res.error)` / `res.result` | `ctx.EvaluateExpression(text)` (throws; returns the value) |
| `x_EvaluateScript` + `if (res.errors)` | `ctx.EvaluateScript(text)` |
| `x_replaceVariables(Environment, s, "ConvertObjectToString")` | `ctx.ReplaceVariables(s, true)` |
| `x_GetVariable`, `x_SetVariable`, `x_DeleteVariable`, `x_getVariableType`, `x_GetVariableLocation` | `ctx.GetVar`, `ctx.SetVar`, `ctx.DeleteVar`, `ctx.GetVarType`, `ctx.GetVarLocation` |
| `x_GetListOfAllVars`, `x_GetListOf<Scope>Vars` | `ctx.ListVars("")`, `ctx.ListVars("<scope>")` |
| `x_CheckVariableName` | `ctx.CheckVarName` |
| `x_ExportAllInstanceVars`, `x_ImportInstanceVars` | `ctx.ExportInstanceVars()`, `ctx.ImportInstanceVars(map)` |
| `x_finish(Environment, r, m)` | `ctx.Finish(r, m)` |
| `x_enabled`/`x_disabled` | return value or `throw` |
| `x_lang("k")` | `Lang("k")` |
| `x_NewFunctionObject` + `SetTimer, % fo, -n` | `ctx.After(n, fn)` |
| `x_SetExecutionValue` / `x_getExecutionValue` | `ctx.State.<name>` |
| `StringReplace, out, in, a, b, all` | `out := StrReplace(in, a, b)` |
| `IfInString, hay, needle` | `if InStr(hay, needle)` |
| `FileRead, v, path` + `ErrorLevel` | `try v := FileRead(path)` / `catch` |
| `Object()` / `{}` as a dictionary with exact keys | `Map()` |
| `if x is number` | `IsNumber(x)` |
| `%var%` as a command parameter | expression |
| `Return %x%` | `return x` |
| `global` declaration in functions | explicit parameters or `static` |

A converter (`tools/convert_element.py`, at the start of S0008, E0036; the core set of S0002 is ported by hand and serves as its before/after test cases) applies the rows of this table automatically, sets `Mode` by heuristic, and marks every place that cannot be converted unambiguously with `; TODO(v2-review): <reason>`.

**Heuristic for `Mode`:** `worker` if the source contains one of `RunWait`, `WinWait*`, `MsgBox`, `InputBox`, `FileSelect*`, `URLDownloadToFile`, `HTTPRequest`, `DllCall`, `ComObject`, `Gui`, `Sleep` (outside of timers), `x_ExecuteInNewAHKThread`. Otherwise `inline`. Trigger classes are always `trigger`. The result is checked by hand.

**Marked as uncertain (do not guess):** everything with its own AHK thread, COM, DllCall, TTS, Eject, `Class_Monitor`, screen settings, `Block_User_Input`.

---

## 7. What stays

- The parameter description format (`type`, `id`, `default`, `content: "Expression"`, `result: "enum"`, `choices`, `enum`, `WarnIfEmpty`, ...), so that the editor's settings dialog remains portable. `contentID` (the parameter that holds the content type the user selected) names a parameter that the editor adds itself and stores with the element (`expression` of `Action_New_variable`, `varnameContent` of `Condition_Variable_content_is`); the class need not list it in `Parameters()` (the smoke test requires only a usable id).
- Class IDs, parameter IDs, result strings, language keys, package name and version in flow files.
- The semantics of the loop entry points (`head`/`tail`; `x_getEntryPoint` becomes `ctx.entryPoint`).
- Loop variables (`A_Index` etc.) via `ctx.SetVar(..., "loop")`.

## 8. Still to be clarified (Phase 3)

- Exact form of `ctx.Request` and the variable functions in the worker (ARCHITECTURE R0004): decided and built in WI-0050, section 3.2.
- Whether metadata and runtime code must be separated per role (ARCHITECTURE R0003): measured in S0002, WI-0046.
- Element packages (`package`, `packageVersion`): decided (E0037, E0045), built in WI-0047: files and include block per package (section 2), in phase 3 only `Default` (and the test packages); the package information in flows stays; the package is part of the identity of an element; an element of an unknown package loads, is marked and ends with `exception` when it runs.
- Dialogs: decided (E0038), built in WI-0051, see section 3.3.
- AHK code elements: decided (E0039). They run AHK v2 code; an imported v1 script is kept as text and marked (MIGRATION M-0049, S0008).
- Specification of a ported element (E0035): the v1 help text (`v1/Source_Elements/Default/help/en/`) and the AHK v2 behaviour, not the v1 code. A deliberate difference to v1 goes into MIGRATION.
