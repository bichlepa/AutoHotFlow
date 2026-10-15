#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Log.ahk
#Include ..\..\expr\Expr.ahk
#Include ..\..\expr\ExprDiag.ahk
#Include ..\..\expr\ExprNames.ahk
#Include ParamEvaluator.ahk

; Context of one inline execution of an element (doc/ELEMENT-API-V2.md section 3, inline subset).
;
; Finish is effective once. A second call is logged (a0) and ignored. Every timer created with After
; belongs to this context and is removed when the context finishes or is stopped (CancelTimers).
;
; onFinish(ctx, result, msg) is called once, by the first Finish. It is a function object (or a
; bound method, see doc/HOW-TO.md), the engine sets it.
class ExecContext {
    static Results := ["normal", "yes", "no", "exception", "head", "tail"]

    __New(flowId, elementId, instanceId, threadId, onFinish := "", vars := "") {
        this.flowId := flowId
        this.elementId := elementId
        this.instanceId := instanceId
        this.threadId := threadId
        this.entryPoint := ""            ; "head" | "tail" for loops, "" otherwise
        this.State := {}                 ; per-run state of the element
        this.vars := vars                ; VarAccess of the engine, or "" (no variables)
        this.cls := ""                   ; the element class (set by the engine): its Parameters() for EvalParams
        this.strictTypes := 0            ; the flow option strictTypes of the revision the element started with (E0034)
        this.onFinish := onFinish
        this.finished := false
        this.result := ""
        this.message := ""
        this._timers := Map()            ; seq -> Map("fn", userFn, "timer", boundTimer)
        this._timerSeq := 0
    }

    ; Ends the run with a result. Returns true if this call was the effective one.
    Finish(result, msg := "") {
        if (!ExecContext.IsResult(result))
            throw ElementError("Finish: unknown result '" result "'")
        if (this.finished) {
            Log.Write("a0", "element " this.elementId, "second Finish('" result "') ignored, first was '" this.result "'", this.flowId)
            return false
        }
        this.finished := true
        this.result := result
        this.message := msg
        this.CancelTimers()
        onFinish := this.onFinish
        if (IsObject(onFinish))
            onFinish(this, result, msg)
        return true
    }

    ; Calls fn() after ms milliseconds, on the message loop. An exception in fn ends the run with "exception".
    ; Returns the timer id. Nothing is scheduled after the run has finished.
    After(ms, fn) {
        if (!IsNumber(ms) || ms < 0)
            throw ElementError("After: invalid delay '" ms "'")
        if (!IsObject(fn))
            throw ElementError("After: callback is not a function object")
        if (this.finished)
            return 0
        this._timerSeq += 1
        seq := this._timerSeq
        timer := ObjBindMethod(this, "_RunTimer", seq)
        this._timers[seq] := Map("fn", fn, "timer", timer)
        SetTimer(timer, -Max(1, Round(ms)))
        return seq
    }

    ; Removes every pending timer of this context. Called by Finish and by ElementRunner.Stop.
    CancelTimers() {
        for seq, entry in this._timers
            SetTimer(entry["timer"], 0)
        this._timers.Clear()
    }

    ; Writes a line to the log (level a0..a3, f0..f3, t0..t3).
    Log(level, text) {
        Log.Write(level, "element " this.elementId, text, this.flowId)
    }

    ; Variables (WI-0040, doc/ELEMENT-API-V2.md section 3). The name decides the scope as in v1: A_ names are loop or
    ; thread variables (scope "loop" or "thread" is required to set one), global_ and static_ names are global and
    ; static, any other name is an instance variable. The engine passes the access object (VarAccess); without it
    ; (a worker, a test without engine) there are no variables.

    ; Sets a variable (v1 x_SetVariable). scope: "" or, for an A_ name, "thread" or "loop". Returns 1, or 0 if the
    ; name or the scope is not allowed (logged f0, as in v1).
    SetVar(name, value, scope := "", hidden := false) {
        return this._Vars().SetVar(name, value, scope, hidden)
    }

    ; Reads a variable or a member ("list.1"), as a copy; default if it does not exist (v1 x_GetVariable).
    GetVar(name, default := "", hidden := false) {
        return this._Vars().GetVar(name, default, hidden)
    }

    ; Deletes a variable or a member. Returns 1 if it existed (v1 x_DeleteVariable).
    DeleteVar(name, hidden := false) {
        return this._Vars().DeleteVar(name, hidden)
    }

    ; "loop", "thread", "builtin", "instance", "static", "global" or "" (v1 x_GetVariableLocation).
    GetVarLocation(name, hidden := false) {
        return this._Vars().Location(name, hidden)
    }

    ; The same as GetVarLocation (the name of WI-0040).
    VarLocation(name, hidden := false) => this.GetVarLocation(name, hidden)

    ; "object", "normal", or "" if the variable does not exist (v1 x_getVariableType).
    GetVarType(name, hidden := false) {
        return this._Vars().VarType(name, hidden)
    }

    ; Names of the visible variables of a scope, or of all scopes for "" (v1 x_GetListOf*Vars).
    ListVars(scope := "") {
        return this._Vars().ListVars(scope)
    }

    ; The text with %name% replaced by the values of the variables (v1 x_replaceVariables). convertObjects: an object
    ; gives its JSON text (v1 option "ConvertObjectToString"), else the empty text.
    ReplaceVariables(text, convertObjects := false) {
        return this._Vars().Replace(String(text), convertObjects)
    }

    ; The value of an expression (v1 x_EvaluateExpression). Throws ElementError with the errors of the evaluator (line,
    ; column, marked line); in strict mode (flow option strictTypes) also for a warning such as a type error. In
    ; compatibility mode a warning gives the empty text for the failed part and an f1 log entry (E0025).
    EvaluateExpression(text) {
        return this._Evaluate(text, "expression")
    }

    ; The value of a script: its last statement (v1 x_EvaluateScript). Errors as EvaluateExpression.
    EvaluateScript(text) {
        return this._Evaluate(text, "script")
    }

    ; 1 if name is a valid variable name, else 0 (v1 x_CheckVariableName: not empty, no digit at the start, no
    ; forbidden character).
    CheckVarName(name) => (ExprNames.Check(String(name)) = "OK") ? 1 : 0

    ; A copy of the visible instance variables, name -> value (v1 x_ExportAllInstanceVars returned the object itself).
    ExportInstanceVars() {
        return this._Vars().ExportInstance()
    }

    ; Sets every entry of a Map (name -> value) as an instance variable, whatever its name (v1 x_ImportInstanceVars).
    ImportInstanceVars(vars) {
        this._Vars().ImportInstance(vars)
    }

    ; A request to the engine with a callback (ELEMENT-API-V2 section 3): only for worker elements (WorkerContext) and
    ; later triggers. An inline element runs in the engine and calls it directly.
    Request(type, payload, callback, timeoutMs := 5000) {
        throw ElementError("Request is only available in a worker element")
    }

    ; ---- parameters (WI-0042, doc/ELEMENT-API-V2.md section 3.1) ------------------------------------------------------

    ; The evaluated parameters of the element (v1 x_AutoEvaluateParameters), as an object with case-insensitive
    ; properties. Every parameter of Parameters() is evaluated by its content type, except labels, buttons and the ids
    ; in skipList (an Array, or a text with commas); skipped ones are not in the result. Throws ElementError with the
    ; text of v1 at the first parameter that has an error (the element ends with "exception").
    EvalParams(params, skipList := "") {
        return this._EvalInto({}, params, skipList, "")
    }

    ; Evaluates further parameters (names: an Array or a text with commas) into evaluated, which is returned (an object
    ; is created if evaluated is not one). v1 x_AutoEvaluateAdditionalParameters. Errors as EvalParams.
    EvalMoreParams(evaluated, params, names) {
        return this._EvalInto(IsObject(evaluated) ? evaluated : {}, params, "", ParamEvaluator.NameSet(names))
    }

    _EvalInto(out, params, skipList, only) {
        if (!IsObject(this.cls))
            throw ElementError("EvalParams: the class of the element is not known")
        skip := ParamEvaluator.NameSet(skipList)
        src := this.EvalSource()
        for item in ParamEvaluator.List(this.cls, this) {
            id := item["id"]
            if (skip.Has(id) || (IsObject(only) && !only.Has(id)))
                continue
            src.at.param := id
            r := ParamEvaluator.One(item, params, src)
            if (r["error"] != "")
                throw ElementError(r["error"])
            out.%id% := r["value"]
        }
        return out
    }

    ; The source of ParamEvaluator for this run: variables, working directory, mode, and a log function that names the
    ; flow, the element and the parameter (src.at.param) of every entry of the evaluator. The log function holds only
    ; src.at, not src: a function in src that holds src would be a reference cycle, never freed (doc/HOW-TO.md).
    EvalSource() {
        vars := this._Vars()
        at := {param: ""}
        src := {vars: vars, strict: this.strictTypes, at: at, logFn: ObjBindMethod(this, "_EvalLog", at)}
        src.workingDir := (vars.HasProp("env") && vars.env is Map) ? vars.env.Get("workingDir", "") : ""
        return src
    }

    _EvalLog(at, level, text) {
        this.Log(level, (at.param != "" ? "parameter '" at.param "': " : "") text)
    }

    _Evaluate(text, kind) {
        src := this.EvalSource()
        res := Expr.Evaluate(String(text), src.vars, src.logFn, kind)
        if (res["errors"].Length)
            throw ElementError(ExprDiag.FormatAll(res["errors"]))
        if (this.strictTypes && res["warnings"].Length)
            throw ElementError(ExprDiag.FormatAll(res["warnings"]))
        return res["value"]
    }

    _Vars() {
        if (!IsObject(this.vars))
            throw ElementError("variables are not available in this context")
        return this.vars
    }

    _RunTimer(seq) {
        entry := this._timers.Get(seq, "")
        if (!IsObject(entry))
            return
        this._timers.Delete(seq)
        if (this.finished)
            return
        fn := entry["fn"]
        try {
            fn()
        } catch as e {
            this.Finish("exception", e.Message)
        }
    }

    static IsResult(result) {
        for r in ExecContext.Results
            if (r == result)
                return true
        return false
    }
}
