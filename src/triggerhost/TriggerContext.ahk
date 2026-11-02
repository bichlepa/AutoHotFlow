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
;   launch                                        Map(script, session, data): how to start this AutoHotFlow again (WI-0133)
;   DisarmReason                                  why Disable runs: disarm, rearm, reset, shutdown or failed (WI-0133)
;   Request(to, msgType, payload, callback, timeoutMs)  a cmd.* request to another role; callback(answerPayload) (WI-0133)
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
        this.imports := Map()           ; the import variables of the arming (PROTOCOL 4.4, ImportNames)
        this._host := host
        this._open := true
        this._timers := Map()          ; seq -> Map("fn", userFn, "timer", boundTimer)
        this._timerSeq := 0
        this.launch := host.appLaunch   ; Map(script, session, data), read only for the element
        this.DisarmReason := ""         ; set by the host before Disable (see TriggerHost._Release)
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

    ; A cmd.* request of the trigger to another role (WI-0133: storage writes the shortcut file, so the trigger host does no
    ; file I/O). It returns at once; callback(answerPayload) runs later under the guard of the trigger: an error in it goes
    ; to evt.trigger.error while the trigger is armed, else to the log only. The request is also sent after the disarm
    ; (Disable removes a shortcut that way). Every request has a timeout (default 5000 ms).
    Request(to, msgType, payload, callback, timeoutMs := 5000) {
        if (!IsObject(callback))
            throw ElementError("Request: callback is not a function object")
        return this._host.RequestFor(this, to, msgType, payload, callback, timeoutMs)
    }

    ; The answer of a Request, handed to the callback under the guard. A missing payload is an error answer.
    _Answered(callback, ans) {
        payload := IsObject(ans) && ans.HasProp("payload") ? ans.payload : Map("ok", false
            , "error", Map("code", "peer_gone", "message", "no answer"))
        this._Guarded(callback, payload)
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
