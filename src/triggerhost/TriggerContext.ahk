#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk

; Context of one armed trigger (doc/ELEMENT-API-V2.md section 3, trigger members; WI-0061). The trigger host creates
; one per arming and passes it to Enable and Disable. Its members:
;
;   triggerKey, flowId, elementId, gen, context   fixed for the arming (context: "" or the start context, e.g. "ahfStartup")
;   State                                         an object per armed trigger
;   Fire(data)                                    sends evt.trigger.fired; nothing once the trigger is disarmed
;   Log(level, text)                              a log line of the trigger
;   After(ms, fn)                                 one-shot timer; cancelled at disarm; errors are reported (see below)
;   Guard(fn)                                     a function object that calls fn under try/catch (for hotkey callbacks)
;
; A callback of the trigger (a timer of After, a function of Guard) runs under try/catch. An error goes to the log and to
; evt.trigger.error; the trigger stays armed (REQ-TRG-010). A disarmed context runs no callback and sends nothing.
class TriggerContext {
    __New(host, triggerKey, flowId, elementId, gen, context) {
        this.triggerKey := triggerKey
        this.flowId := flowId
        this.elementId := elementId
        this.gen := gen
        this.context := context
        this.State := {}
        this._host := host
        this._open := true
        this._timers := Map()          ; seq -> Map("fn", userFn, "timer", boundTimer)
        this._timerSeq := 0
    }

    ; True until the trigger is disarmed.
    IsOpen => this._open

    ; Sends evt.trigger.fired. data: a Map of texts and numbers, or "" / nothing. Anything else is refused: the event
    ; goes out with an empty Map and an f0 entry names the problem.
    Fire(data := "") {
        if (!this._open)
            return
        this._host.ReportFired(this, TriggerContext._CleanData(this, data))
    }

    ; A log line of the trigger (levels a0..a3, f0..f3, t0..t3).
    Log(level, text) {
        Log.Write(level, "trigger " this.elementId, text, this.flowId)
    }

    ; Calls fn() after ms milliseconds. Returns the timer id, 0 when the trigger is not armed (nothing is scheduled).
    After(ms, fn) {
        if (!IsNumber(ms) || ms < 0)
            throw ElementError("After: invalid delay '" ms "'")
        if (!IsObject(fn))
            throw ElementError("After: callback is not a function object")
        if (!this._open)
            return 0
        this._timerSeq += 1
        seq := this._timerSeq
        timer := ObjBindMethod(this, "_RunTimer", seq)
        this._timers[seq] := Map("fn", fn, "timer", timer)
        SetTimer(timer, -Max(1, Round(ms)))
        return seq
    }

    ; A function object that calls fn with the arguments it gets, under try/catch: an error is reported like an error of
    ; a timer. For callbacks that the element gives to the OS (hotkeys).
    Guard(fn) {
        if (!IsObject(fn))
            throw ElementError("Guard: callback is not a function object")
        return (args*) => this._Guarded(fn, args*)
    }

    ; Removes the pending timers. Called by the host when the trigger is disarmed.
    CancelTimers() {
        for seq, entry in this._timers
            SetTimer(entry["timer"], 0)
        this._timers.Clear()
    }

    ; Marks the context as disarmed: no more callbacks, no more events. The host calls it before the element's Disable.
    Close() {
        this._open := false
        this.CancelTimers()
    }

    _RunTimer(seq) {
        if (!this._timers.Has(seq))
            return
        entry := this._timers[seq]
        this._timers.Delete(seq)
        if (this._open)
            this._Guarded(entry["fn"])
    }

    _Guarded(fn, args*) {
        try {
            fn(args*)
        } catch as e {
            this._host.ReportCallbackError(this, e)
        }
    }

    ; The data of Fire, checked (see Fire). Returns a Map.
    static _CleanData(ctx, data) {
        if (IsObject(data)) {
            if (data is Map) {
                clean := Map()
                valid := true
                for key, value in data {
                    if (IsObject(value)) {
                        valid := false
                        break
                    }
                    clean[String(key)] := value
                }
                if (valid)
                    return clean
            }
        } else if (data = "") {
            return Map()
        }
        ctx.Log("f0", "Fire: data must be a Map of texts and numbers; the event is sent without it")
        return Map()
    }
}
