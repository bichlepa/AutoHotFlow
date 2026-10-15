#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Json.ahk
#Include ..\..\core\Time.ahk
#Include VarValues.ahk
#Include VarJson.ahk

; Writes the global and static variables back through storage (WI-0041, ARCHITECTURE 6.2, PROTOCOL 4.6, M-0006). The
; engine holds the working copy and never touches a file. A change is not sent at once: the variable is marked, and
; DELAY_MS after the first change since the last write the state of that moment goes out (cmd.storage.var.set, or
; cmd.storage.var.delete if the variable is gone). Many changes of one variable inside the delay cost one write.
;
; A write that fails because storage is silent or gone (timeout, peer_gone, ...) is marked again and retried after
; RETRY_MS, as often as it takes; the working copy is never touched. The first failure of a variable is reported
; (log a0, evt.storage.error), the following ones are not, until a write succeeds. An error that a retry cannot fix
; (bad_payload: the name or the content is refused) is reported and the variable is dropped from the queue; the next
; change of it tries again.
;
; At shutdown FlushAll sends everything that is still marked, with the rest of the deadline as the limit of each
; request, and does not wait for the answers: the frames leave before sys.bye, storage is the last process to end
; and writes its queue empty (ARCHITECTURE 6.3).
class VarWriter {
    static DELAY_MS := 200
    static TIMEOUT_MS := 10000
    static RETRY_MS := 1000
    ; At most this many requests leave per timer run and this many are unanswered at the same time; the rest waits.
    static BATCH := 50
    static MAX_INFLIGHT := 200

    __New(engine, store, delayMs := 200, timeoutMs := 10000) {
        this._engine := engine
        this._store := store
        this._delayMs := delayMs
        this._timeoutMs := timeoutMs
        this._dirty := Map()        ; key -> Map(scope, flowId, name, due)
        this._reported := Map()       ; key -> true: the last write failed and was reported
        this._inflight := 0
        this._closing := false
        this._runFn := () => this._Run()
        this._scheduled := false
    }

    ; Number of variables that wait for their write, and of requests that wait for their answer.
    Pending => this._dirty.Count
    Inflight => this._inflight

    ; The variable has changed. The first change since the last write starts the delay.
    Touch(scope, flowId, name) {
        if (this._closing)
            return
        key := VarWriter._Key(scope, flowId, name)
        if (!this._dirty.Has(key))
            this._dirty[key] := Map("scope", scope, "flowId", flowId, "name", name, "due", Time.NowMs() + this._delayMs)
        this._Schedule()
    }

    ; sys.shutdown: sends every variable that is still marked. Returns how many were sent.
    FlushAll(deadlineMs) {
        this._closing := true
        SetTimer(this._runFn, 0)
        timeoutMs := Max(500, Integer(deadlineMs))
        sent := 0
        lost := 0
        for key, entry in this._dirty {
            if (this._Send(key, entry, timeoutMs, true))
                sent += 1
            else
                lost += 1
        }
        this._dirty := Map()
        ; The peer refuses requests beyond its limit of waiting ones and the process ends at once, so the rest is lost
        ; (F-0070). One summary line instead of one error per variable.
        if (lost > 0)
            this._engine._Log("a0", "engine", "shutdown: " lost " of " (sent + lost) " variables not written (storage refused the requests)")
        return sent
    }

    ; --- internals ---------------------------------------------------------------------------------------

    static _Key(scope, flowId, name) => scope "|" StrLower(flowId) "|" StrLower(name)

    ; One timer for all variables: it runs when the earliest one is due.
    _Schedule() {
        if (this._scheduled || this._dirty.Count = 0)
            return
        due := ""
        for _, entry in this._dirty {
            if (due = "" || entry["due"] < due)
                due := entry["due"]
        }
        wait := Max(1, Integer(due - Time.NowMs()) + 1)
        this._scheduled := true
        SetTimer(this._runFn, -wait)
    }

    _Run() {
        this._scheduled := false
        if (this._closing)
            return
        try {
            now := Time.NowMs()
            sent := 0
            due := []
            for key, entry in this._dirty {
                if (entry["due"] <= now)
                    due.Push(key)
            }
            for key in due {
                if (sent >= VarWriter.BATCH || this._inflight >= VarWriter.MAX_INFLIGHT)
                    break
                entry := this._dirty[key]
                this._dirty.Delete(key)
                this._Send(key, entry, this._timeoutMs, false)
                sent += 1
            }
        } catch as e {
            this._engine._Log("a0", "engine", "writing variables failed: " Type(e) ": " e.Message)
        }
        this._Schedule()
    }

    ; Sends the state of the variable as it is now. Returns true if a request left.
    _Send(key, entry, timeoutMs, closing) {
        scope := entry["scope"], flowId := entry["flowId"], name := entry["name"]
        table := this._store.Table(scope, flowId)
        payload := Map("scope", scope, "name", name)
        msgType := "cmd.storage.var.set"
        if (scope = "static")
            payload["flowId"] := flowId
        try {
            if (table.Has(name)) {
                value := table[name]
                payload["type"] := (value is Map) ? "object" : "normal"
                payload["content"] := (value is Map) ? VarJson.Stringify(value, 2) : String(value)
                msgType := "cmd.storage.var.set"
            } else {
                msgType := "cmd.storage.var.delete"
            }
            this._engine.peer.Request("storage", msgType, payload
                , ObjBindMethod(this, "_OnAnswer", key, entry, msgType, closing), timeoutMs)
            this._inflight += 1
            return true
        } catch as e {
            ; Not sent (too many unanswered requests, a payload that cannot be serialized). At shutdown FlushAll
            ; counts these and reports one summary line.
            if (closing)
                return false
            this._Failed(key, entry, msgType, Type(e) ": " e.Message, !closing)
            return false
        }
    }

    _OnAnswer(key, entry, msgType, closing, res) {
        this._inflight -= 1
        if (res.payload.Get("ok", false)) {
            if (this._reported.Has(key)) {
                this._reported.Delete(key)
                this._engine._Log("a1", "engine", "variable '" entry["name"] "' written after an earlier failure")
            }
            return
        }
        err := res.payload.Get("error", "")
        code := (err is Map) ? err.Get("code", "") : ""
        text := (err is Map) ? code ": " err.Get("message", "") : "no error details"
        ; closing: nothing is retried, the process ends.
        this._Failed(key, entry, msgType, text, !closing && code != ErrCode.BAD_PAYLOAD)
    }

    ; Reports the first failure of a variable; marks it again (after RETRY_MS) if retry is set and nothing newer is
    ; waiting for its turn.
    _Failed(key, entry, msgType, text, retry) {
        if (!this._reported.Has(key)) {
            this._reported[key] := true
            op := SubStr(msgType, 13)       ; "var.set" or "var.delete"
            this._engine._StorageError(op, entry["scope"] "/" entry["name"], text)
        }
        if (retry && !this._closing && !this._dirty.Has(key)) {
            entry["due"] := Time.NowMs() + VarWriter.RETRY_MS
            this._dirty[key] := entry
            this._Schedule()
        }
    }
}
