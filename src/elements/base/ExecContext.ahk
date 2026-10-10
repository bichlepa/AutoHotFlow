#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Log.ahk
#Include VarStore.ahk

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
        this.vars := IsObject(vars) ? vars : VarStore()
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

    ; Sets a variable. scope "" or "thread" (default) or "instance".
    SetVar(name, value, scope := "") {
        this.vars.Set(scope, name, value)
    }

    ; Reads a variable: thread scope first, then instance scope. Returns default if unset.
    GetVar(name, default := "") {
        return this.vars.Find(name, default)
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
