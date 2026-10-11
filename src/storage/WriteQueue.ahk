#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Role.ahk
#Include ..\core\Time.ahk

; Serial queue of storage operations (WI-12, ARCHITECTURE 6.3). One operation runs per timer tick, so
; the message pump answers sys.ping and new requests between two operations. A big write is one
; operation; the pump is free again when it ends.
;
; An operation is a Map:
;   deadline  Time.NowMs() value after which it is not run (answered with timeout), or "" for none
;   run       function() returning a payload Map; a throw is answered with the error code
;   finish    function(payload) called exactly once with the answer, also on FailAll
; Each operation is answered once. A finish that throws is logged to the console, the queue goes on.
;
; The queue is touched from timers and handlers. Every statement here is one operation on the array
; (RemoveAt, Push, Length), so an interrupting thread sees a consistent queue (HOW-TO, Pipes section).
class WriteQueue {
    __New() {
        this._ops := []
        this._pumpFn := () => this._Pump()
        this._nextDelayMs := -1   ; delay before the next run after a retry request, -1 for none
    }

    Pending => this._ops.Length

    Add(op) {
        this._ops.Push(op)
        SetTimer(this._pumpFn, -1)
    }

    ; Runs the first operation and answers it. Returns false when the queue is empty.
    ; An operation may ask for a later retry (F-04, file locked by another process): its run function
    ; returns Map("retry", true, "message", text) and the operation has "retryMs" (the time it may keep
    ; trying, counted from the first retry) and optionally "retryDelayMs". It then stays at the head
    ; of the queue (the order is kept) and runs again after the delay, by timer, so the message pump
    ; is free in between. When the time is up, it is answered with code busy.
    RunOne() {
        if (this._ops.Length = 0)
            return false
        this._nextDelayMs := -1
        op := this._ops.RemoveAt(1)
        if (op["deadline"] != "" && Time.NowMs() > op["deadline"]) {
            payload := WriteQueue.Fail(ErrCode.TIMEOUT, "waited too long in the storage queue, not executed")
        } else {
            payload := WriteQueue._RunSafely(op["run"])
            if (payload.Has("retry")) {
                now := Time.NowMs()
                if (!op.Has("retryUntil"))
                    op["retryUntil"] := now + op.Get("retryMs", 0)
                if (now < op["retryUntil"]) {
                    this._ops.InsertAt(1, op)
                    this._nextDelayMs := op.Get("retryDelayMs", 25)
                    return true
                }
                payload := WriteQueue.Fail(ErrCode.BUSY, "still busy after " op.Get("retryMs", 0) " ms: "
                    payload.Get("message", ""))
            }
        }
        WriteQueue._FinishSafely(op["finish"], payload)
        return true
    }

    ; Answers every waiting operation with an error (used at shutdown when the time is up).
    FailAll(code, text) {
        while (this._ops.Length > 0) {
            op := this._ops.RemoveAt(1)
            WriteQueue._FinishSafely(op["finish"], WriteQueue.Fail(code, text))
        }
    }

    _Pump() {
        this.RunOne()
        if (this._ops.Length > 0)
            SetTimer(this._pumpFn, -Max(this._nextDelayMs, 1))
    }

    static Fail(code, text) => Map("ok", false, "error", Map("code", code, "message", text))

    static _RunSafely(run) {
        try {
            payload := run()
        } catch as e {
            code := (e is AhfError) ? e.code : ErrCode.INTERNAL
            return WriteQueue.Fail(code, Type(e) ": " e.Message)
        }
        if (!payload.Has("ok"))
            payload["ok"] := true
        return payload
    }

    static _FinishSafely(finish, payload) {
        try {
            finish(payload)
        } catch as e {
            ; The sender of a failed answer gets its own timeout. The queue must not stop for it.
            Role.Console("a0", "storage", "answer failed: " Type(e) ": " e.Message)
        }
    }
}
