#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Json.ahk
#Include VarValues.ahk

; Loads the global and static variables from storage at the start, before evt.engine.ready (WI-41, ARCHITECTURE 6.1).
; The expression evaluator reads variables synchronously, so they must be in memory before a flow runs; loading on
; demand would only work by blocking.
;
; Work: one cmd.storage.var.list for the global scope and one for the static variables of each loaded flow, then one
; cmd.storage.var.get per name. At most PARALLEL requests are on their way, and the next one leaves when an answer
; has been handled (as for the flow files, WI-24): each answer costs the engine a parse, and a ping must not wait
; behind many of them.
;
; When storage is gone or silent no further request is sent. After the last answer the loader reports onDown and
; keeps what is not done yet; Run again (the engine does that when storage is back) continues with exactly that.
; A request that failed for another reason (a file that cannot be read, content that is not JSON) is reported as
; evt.storage.error and skipped: that variable is missing in memory, and the next write of it replaces the file.
;
; A variable that exists in memory already (a flow has set it before the load came to it) is not replaced.
class VarLoader {
    static PARALLEL := 2
    static TIMEOUT_MS := 30000

    __New(engine, store) {
        this._engine := engine
        this._store := store
        this._started := false
        this._pending := []         ; tasks not sent yet (Map: kind "list"/"get", scope, flowId, name)
        this._inflight := 0
        this._down := ""            ; why the loader stopped sending ("" = it did not)
        this._onDone := ""
        this._onDown := ""
        this._count := 0            ; variables loaded
    }

    Count => this._count

    ; Starts (or continues) loading the variables of the global scope and of these flows. Exactly one of onDone() and
    ; onDown(why) is called, once, after the last answer.
    Run(flowIds, onDone, onDown) {
        this._onDone := onDone
        this._onDown := onDown
        this._down := ""
        if (!this._started) {
            this._started := true
            this._pending.Push(Map("kind", "list", "scope", "global", "flowId", ""))
            for flowId in flowIds
                this._pending.Push(Map("kind", "list", "scope", "static", "flowId", flowId))
        }
        this._Pump()
    }

    _Pump() {
        while (this._inflight < VarLoader.PARALLEL && this._pending.Length > 0 && this._down = "") {
            task := this._pending.RemoveAt(1)
            this._Issue(task)
        }
        if (this._inflight > 0)
            return
        if (this._down != "") {
            fn := this._onDown
            this._onDown := ""
            this._onDone := ""
            if (IsObject(fn))
                fn(this._down)
        } else if (this._pending.Length = 0) {
            fn := this._onDone
            this._onDone := ""
            this._onDown := ""
            if (IsObject(fn))
                fn()
        }
    }

    _Issue(task) {
        payload := Map("scope", task["scope"])
        if (task["scope"] = "static")
            payload["flowId"] := task["flowId"]
        if (task["kind"] = "get")
            payload["name"] := task["name"]
        msgType := (task["kind"] = "list") ? "cmd.storage.var.list" : "cmd.storage.var.get"
        try {
            this._engine.peer.Request("storage", msgType, payload
                , ObjBindMethod(this, "_OnAnswer", task), VarLoader.TIMEOUT_MS)
            this._inflight += 1
        } catch as e {
            this._pending.InsertAt(1, task)
            this._down := Type(e) ": " e.Message
        }
    }

    _OnAnswer(task, res) {
        this._inflight -= 1
        try {
            if (res.payload.Get("ok", false)) {
                if (task["kind"] = "list")
                    this._Listed(task, res.payload.Get("names", []))
                else
                    this._Got(task, res.payload)
            } else if (Engine._StorageGone(res)) {
                this._pending.InsertAt(1, task)
                if (this._down = "")
                    this._down := Engine._ErrorText(res)
            } else {
                this._Error(task, Engine._ErrorText(res))
            }
        } catch as e {
            this._Error(task, Type(e) ": " e.Message)
        }
        this._Pump()
    }

    _Listed(task, names) {
        for name in names {
            if (name is Map || name is Array)
                continue
            this._pending.Push(Map("kind", "get", "scope", task["scope"], "flowId", task["flowId"], "name", String(name)))
        }
    }

    _Got(task, payload) {
        if (!payload.Get("exists", false))
            return                  ; deleted between the list and the get
        table := this._store.Table(task["scope"], task["flowId"])
        name := task["name"]
        if (table.Has(name))
            return
        content := payload.Get("content", "")
        if (payload.Get("type", "normal") = "object")
            table[name] := VarValues.Import(Json.Parse(content))
        else
            table[name] := content
        this._count += 1
    }

    _Error(task, text) {
        what := task["scope"] (task["flowId"] != "" ? "/" task["flowId"] : "") (task.Has("name") ? "/" task["name"] : "")
        this._engine._StorageError("var." task["kind"], what, text)
    }
}
