#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Role.ahk
#Include ..\core\Time.ahk

; Serial queues of storage operations (WI-12, WI-25, ARCHITECTURE 6.3). Two queues: requests (Add) and
; log operations (AddLow). A request always runs before a waiting log operation, so a flood of log
; lines cannot hold back flow.read or flow.write. The order inside each queue is kept.
;
; One timer run (_Pump) works through operations until a time budget (BUDGET_MS) is used up or nothing
; is runnable, then yields so the message pump answers sys.ping and takes new requests. The budget is
; checked between operations: a big write is one operation and is never split; the pump is free again
; when it ends.
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
    ; Time one timer run may work before it yields to the message pump (WI-25: justification in the result).
    static BUDGET_MS := 10

    ; clock: optional function() returning milliseconds in the unit of Time.NowMs(); only unit tests pass one
    ; (WI-32), so that budget and retry delays can be checked without real time.
    __New(clock := "") {
        this._now := (clock = "") ? () => Time.NowMs() : clock
        this._ops := []     ; requests
        this._low := []     ; log operations
        this._pumpFn := () => this._Pump()
    }

    Pending => this._ops.Length + this._low.Length

    ; Waiting requests and waiting log operations, for the snapshot.
    RequestCount => this._ops.Length
    LogCount => this._low.Length

    Add(op) {
        this._ops.Push(op)
        SetTimer(this._pumpFn, -1)
    }

    ; Queues a low priority operation (log). It runs only when no request is waiting.
    AddLow(op) {
        this._low.Push(op)
        SetTimer(this._pumpFn, -1)
    }

    ; Runs the next runnable operation and answers it: the first request, else the first log operation
    ; (when its retry delay is over). Returns false when nothing could run.
    ; An operation may ask for a later retry (F-04, file locked by another process): its run function
    ; returns Map("retry", true, "message", text) and the operation has "retryMs" (the time it may keep
    ; trying, counted from the first retry) and optionally "retryDelayMs". It then stays at the head
    ; of its queue (the order is kept). A log operation is not run again before its delay is over, a
    ; request in the other queue goes first meanwhile; a request retry runs again at the next call.
    ; When the time is up, the operation is answered with code busy.
    RunOne() {
        if (this._ops.Length > 0) {
            queue := this._ops
        } else if (this._low.Length > 0 && this._LowDue()) {
            queue := this._low
        } else {
            return false
        }
        op := queue.RemoveAt(1)
        if (op["deadline"] != "" && this._now.Call() > op["deadline"]) {
            payload := WriteQueue.Fail(ErrCode.TIMEOUT, "waited too long in the storage queue, not executed")
        } else {
            payload := WriteQueue._RunSafely(op["run"])
            if (payload.Has("retry")) {
                now := this._now.Call()
                if (!op.Has("retryUntil"))
                    op["retryUntil"] := now + op.Get("retryMs", 0)
                if (now < op["retryUntil"]) {
                    op["notBefore"] := now + op.Get("retryDelayMs", 25)
                    queue.InsertAt(1, op)
                    return true
                }
                payload := WriteQueue.Fail(ErrCode.BUSY, "still busy after " op.Get("retryMs", 0) " ms: "
                    payload.Get("message", ""))
            }
        }
        WriteQueue._FinishSafely(op["finish"], payload)
        return true
    }

    ; Runs operations until the budget (ms) is used up or nothing is runnable. At least one operation
    ; runs when one is runnable. Returns the number of runs.
    RunFor(budgetMs) {
        start := this._now.Call()
        runs := 0
        while (this.RunOne()) {
            runs += 1
            if (this._now.Call() - start >= budgetMs)
                break
        }
        return runs
    }

    ; Milliseconds until something is runnable again, 1 when it is runnable now, -1 when nothing waits.
    NextWaitMs() {
        if (this._ops.Length > 0)
            return 1
        if (this._low.Length = 0)
            return -1
        wait := this._low[1].Get("notBefore", 0) - this._now.Call()
        return (wait > 1) ? Ceil(wait) : 1
    }

    _LowDue() => this._low[1].Get("notBefore", 0) <= this._now.Call()

    ; Answers every waiting operation with an error (used at shutdown when the time is up).
    FailAll(code, text) {
        for queue in [this._ops, this._low] {
            while (queue.Length > 0) {
                op := queue.RemoveAt(1)
                WriteQueue._FinishSafely(op["finish"], WriteQueue.Fail(code, text))
            }
        }
    }

    _Pump() {
        this.RunFor(WriteQueue.BUDGET_MS)
        wait := this.NextWaitMs()
        if (wait > 0)
            SetTimer(this._pumpFn, -wait)
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
