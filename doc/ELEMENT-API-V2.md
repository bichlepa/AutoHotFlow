# Element API v2

Status: Draft. Basis for porting the 152 v1 elements (114 actions, 17 conditions, 5 loops, 16 triggers).
Predecessor: the v1 function family `Element_<Task>_<Class>` and the helpers `x_*` (see `v2-phase2-final:work_items/ANALYSE.md`, section 2).

---

## 1. Guidelines

1. **One class per element**, one file per class. The class name is identical to the v1 class ID (`Action_Sleep`, `Trigger_Hotkey`), because this string is stored in the `class` field of saved flows. Resolution is case-insensitive (v1 writes `trigger_manual` and `Trigger_Manual`).
2. **All methods are `static`.** Elements are stateless. The state of one execution lives in `ctx.State`.
3. **The context `ctx` replaces `Environment` and all `x_*` functions.** It has fixed, lowercase fields (`flowId`, `elementId`, `instanceId`, `threadId`). The inconsistent spelling from v1 goes away.
4. **Errors are exceptions.** `throw ElementError(msg)` ends the execution with result `exception` and the message. The engine wraps every call in `try/catch`, so element code cannot crash it.
5. **Parameters arrive already evaluated.** The engine owns the variables and evaluates parameters with `content: "Expression"` before `Run`/`Enable` is called. This also applies to workers and triggers.
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
    static Icon      := "example.ico"   ; file name under assets/Icons, "" = none
    static JobTimeoutMs := 0            ; worker only: job deadline in ms, 0 = none (WI-27, ARCHITECTURE 6.4)

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

**Worker elements and blocking (WI-27, ARCHITECTURE 6.4):** A worker element may block for any length of time within a single call (download, COM, `DllCall`, dialog). A worker with a job is never pinged and never ended as hanging. Two consequences: an abort (stop of the instance) does not reach an element that is blocked in a single call. After 2 s without an acknowledgement, the engine has the whole process terminated (only one job runs per worker, so nothing else is lost); `Stop(ctx, params)` of the element then no longer runs, so cleanup in the element is not possible there. And: without `JobTimeoutMs` the job has no deadline (v1 had none). If a class sets `JobTimeoutMs` > 0, the thread ends after this time with the result `exception` and the message "worker timeout", and the element is terminated as on an abort. The deadline is a class value, not a parameter; a flow parameter (e.g. "Timeout" for a download) remains the responsibility of the element.

**Class ID:** Do not read it via `cls.Name`. A class with `static Name()` hides the built-in property, so `cls.Name` is then a function. The ID is provided by `ElementRegistry.IdOf(cls)` (internally `Type(cls())`). Verified in WI-09.

**Registration:** At the end of the file: `ElementRegistry.Register(Action_Example)`. This is the only code allowed at file level. It runs at load time, before `AhfMain`. So that an error there (duplicate class, invalid `Mode`) does not show a dialog, the entry point `src/AutoHotFlow.ahk` sets `OnError` as its first executable statement, **before** the `#Include` lines (handler `AhfLoadError`: message to stderr, exit 1). An element file needs nothing for this. (Decision WI-22: the registration is not moved into a function, because that would change hundreds of element files in Phase 3 without catching more: the handler also covers any other code at file level.) The registry is a `Map` with `CaseSense := "Off"`. A generated include block per role (engine, editor, worker, trigger host) includes the files; no text substitution at run time.

**Parameters that the element evaluates itself (WI-39):** the loader of flows converts the texts of all parameters with an expression content type from v1 syntax into the new language (`content` is `Expression`, `number`, `positiveNumber`, `integer`, `positiveInteger` or `positiveIntegerOrZero`, or `content` is a list and the parameter named by `contentID` holds one of these). A parameter that the element itself evaluates as an expression or script (v1: `x_EvaluateExpression` or `x_EvaluateScript` on a `RawString`, e.g. `Action_Script`) has no such content type; the class names it in `static V1Syntax := Map("Script", "script", "Condition", "expression")`. The loader calls `Parameters("")` in the engine, so `Parameters()` must not need the editor (`ctx`) for the ids and content types; if it throws, the element's texts stay in v1 syntax and the element is marked (ARCHITECTURE 7). `Action_TestExprParams` (`src/elements/skeleton/`) has one parameter of each kind.

**Parameter container:** `params` is an object with case-insensitive property access (`params.Duration` equals `params.duration`), as v1 uses it. Variable stores, on the other hand, are `Map` objects with `CaseSense := "Off"`, so that variable names remain case-insensitive as in v1 and v2 objects are not confused with them.

---

## 3. Context `ctx`

| Member | Replaces (v1) | Remarks |
|---|---|---|
| `ctx.flowId`, `.elementId`, `.instanceId`, `.threadId` | `Environment.FlowID` etc. | fixed spelling |
| `ctx.EvalParams(params)` | `x_AutoEvaluateParameters` | returns evaluated parameters, throws on error (no `_error`) |
| `ctx.EvalParams(params, skipList)` | with `p_skipList` | – |
| `ctx.Finish(result, msg := "")` | `x_finish` | `result`: `normal`, `yes`, `no`, `exception`, `head`, `tail` |
| `ctx.SetVar(name, value, scope := "")` | `x_SetVariable` | `scope`: `thread`, `loop`, `instance`, `static`, `global`, as in v1. Phase 2 (WI-09): only `""`/`thread` and `instance`; other scopes throw `ElementError`. |
| `ctx.GetVar(name, default := "")` | `x_GetVariable` | Searches the thread scope first, then the instance scope. Returns `default` if not set (Phase 2: parameter `default` added, WI-09). In a worker only via `imports` or `ctx.Request`. |
| `ctx.After(ms, fn)` | `x_NewFunctionObject` + `SetTimer` | timer belongs to the execution and is cancelled automatically on stop/end |
| `ctx.State` | `x_SetExecutionValue`/`x_GetExecutionValue`, `x_SetTriggerValue`/`x_getTriggerValue` | object per execution (Run) or per armed trigger |
| `ctx.Fire(data := "")` | `x_trigger` | triggers only. Sends `evt.trigger.fired` |
| `ctx.Log(level, text)` | `x_log` | levels `f0` to `f3` |
| `ctx.Request(type, payload, callback, timeoutMs)` | – (new) | request to the engine with callback. Workers/triggers only. |
| `ctx.RunScript(code, imports, exports)` | `x_ExecuteInNewAHKThread` | for AHK code elements. Always runs as a worker. |
| `Lang(key, args*)` | `x_lang` | global function, language files unchanged |
| `form.Disable(id, cond)`, `form.Enable(id, cond)` | `x_Par_Disable`/`x_Par_Enable` | only in `CheckSettings` |
| `form.SetValue(id, v)`, `form.SetChoices(id, list)`, `form.SetLabel(id, text)` | `x_Par_SetValue` etc. | – |

The number of v1 helpers (`x_*`) actually used is 88. The most frequent: `x_lang` (2211 calls), `x_finish` (681), `x_Par_Disable`/`Enable` (~420), `x_SetVariable` (171), `x_AutoEvaluateParameters` (129).

---

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

**v2:**

```ahk
#Requires AutoHotkey v2.0

class Action_Sleep extends AhfElement {
    static Mode      := "inline"
    static Level     := "Beginner"
    static Stability := "Stable"
    static Icon      := "sleep.ico"

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
        switch params.Unit {
            case "Milliseconds": d := params.Duration " " Lang("ms #Milliseconds")
            case "Seconds":      d := params.Duration " " Lang("s #Seconds")
            case "Minutes":      d := params.Duration " " Lang("m #Minutes")
        }
        return Lang("Sleep") ": " d
    }

    static CheckSettings(form, params, staticValues) {
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)          ; throws on error -> result "exception"
        switch p.Unit {
            case "Milliseconds": ms := p.Duration
            case "Seconds":      ms := p.Duration * 1000
            case "Minutes":      ms := p.Duration * 60000
        }
        ctx.After(ms, () => ctx.Finish("normal"))   ; timer is removed automatically on stop
    }
}

ElementRegistry.Register(Action_Sleep)
```

What changes: no `Element_stop` needed any more (the context removes the timer), the error path is gone (exception), the callback is a lambda instead of a named function.
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

A converter (`tools/convert_element.py`, Phase 3) applies the rows of this table automatically, sets `Mode` by heuristic, and marks every place that cannot be converted unambiguously with `; TODO(v2-review): <reason>`.

**Heuristic for `Mode`:** `worker` if the source contains one of `RunWait`, `WinWait*`, `MsgBox`, `InputBox`, `FileSelect*`, `URLDownloadToFile`, `HTTPRequest`, `DllCall`, `ComObject`, `Gui`, `Sleep` (outside of timers), `x_ExecuteInNewAHKThread`. Otherwise `inline`. Trigger classes are always `trigger`. The result is checked by hand.

**Marked as uncertain (do not guess):** everything with its own AHK thread, COM, DllCall, TTS, Eject, `Class_Monitor`, screen settings, `Block_User_Input`.

---

## 7. What stays

- The parameter description format (`type`, `id`, `default`, `content: "Expression"`, `result: "enum"`, `choices`, `enum`, `WarnIfEmpty`, ...), so that the editor's settings dialog remains portable.
- Class IDs, parameter IDs, result strings, language keys, package name and version in flow files.
- The semantics of the loop entry points (`head`/`tail`; `x_getEntryPoint` becomes `ctx.entryPoint`).
- Loop variables (`A_Index` etc.) via `ctx.SetVar(..., "loop")`.

## 8. Still to be clarified (Phase 3)

- Exact form of `ctx.Request` and the import list for workers (`imports`) for elements that read arbitrary variables.
- Whether metadata and runtime code must be separated per role (ARCHITECTURE R3).
- Handling of element packages from third parties (`package`, `packageVersion`): the Chrome package is dropped, but the structure of the package information stays so that old flows can be loaded.
