#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\SettingsModel.ahk
#Include ..\core\ipc\Deferred.ahk

; The runtime copy of the global settings (WI-0077, REQ-SET-010, PROTOCOL 4.2 "Settings", 4.3, 4.6 Settings.json). The engine owns
; the copy, storage keeps the file (the engine only asks for it as text, like Categories.json), every other role takes what it
; needs from evt.settings.changed.
;
; Start: the engine reads the file before it reads the flows (Engine._StartLoad). A missing file gives the defaults. A file that
; cannot be parsed is kept as Settings.json.broken and the defaults are used. A key that is missing, unknown or invalid in a file
; that parses counts as its default and is logged; the file is not rewritten until the next change. A read that fails for another
; reason makes the start wait and read again, so the flows never start with settings that are not the user's.
;
; Change (cmd.settings.set): the partial set is checked first (bad_payload names the key), then the whole set is written through
; storage, and only when the write was answered ok the new set is applied, sent as evt.settings.changed and answered. Changes are
; handled one after the other, so two changes in a row both reach the file. The engine applies at once: the global execution
; policy and the working directory (read when a flow starts), the three limits of the runaway guard (read at each check), the log
; thresholds and the language (Role.ApplySettings) and the number of workers (Engine.OnSettings).
class EngineSettings {
    static TIMEOUT_MS := 30000
    static RETRY_MS := 1000

    __New(engine) {
        this._engine := engine
        this._values := SettingsModel.Defaults()   ; the settings in force; the defaults until the file was read
        this._loaded := false
        this._onDone := ""
        this._onDown := ""
        this._queue := []                      ; changes that wait: Map(request, checked)
        this._busy := false                    ; a write is on its way
        this._readFn := () => this._Read()
    }

    Loaded => this._loaded

    ; The value of one setting (a default for a key that does not exist is an error of the caller: Map throws).
    Value(key) => this._values[key]

    ; The whole set (a copy, truth values 1 and 0).
    All() {
        out := Map()
        for key, value in this._values
            out[key] := value
        return out
    }

    ; The whole set as it goes over a message (real JSON booleans).
    Wire() => SettingsModel.ToWire(this._values)

    ; --- start ---------------------------------------------------------------------------------------------------

    ; Reads the file once per start. onDone() runs when the settings are in force; onDown(why) when storage is gone or silent
    ; (the engine waits and calls Load again).
    Load(onDone, onDown) {
        if (this._loaded) {
            onDone()
            return
        }
        this._onDone := onDone
        this._onDown := onDown
        this._Read()
    }

    _Read() {
        try {
            this._engine.peer.Request("storage", "cmd.storage.settings.read", Map()
                , (res) => this._OnRead(res), EngineSettings.TIMEOUT_MS)
        } catch as e {
            this._onDown(Type(e) ": " e.Message)
        }
    }

    _OnRead(res) {
        if (!res.payload.Get("ok", false)) {
            why := Engine._ErrorText(res)
            if (Engine._StorageGone(res)) {
                this._onDown(why)
                return
            }
            this._engine._StorageError("settings.read", "Settings.json", why)
            SetTimer(this._readFn, -EngineSettings.RETRY_MS)
            return
        }
        if (!Engine._Flag(res.payload.Get("exists", false))) {
            this._engine._Log("a1", "engine", "no Settings.json, the defaults are used")
            this._Finish(SettingsModel.Defaults())
            return
        }
        raw := ""
        try {
            raw := SettingsModel.FromText(res.payload.Get("text", ""))
        } catch as e {
            this._engine._Log("a0", "engine", "Settings.json is broken (" e.Message "); it is kept as Settings.json.broken, "
                . "the defaults are used")
            this._Keep()
            this._Finish(SettingsModel.Defaults())
            return
        }
        values := SettingsModel.Normalize(raw, &problems)
        for problem in problems
            this._engine._Log(problem["kind"] = "missing" ? "a1" : "a0", "engine", problem["text"])
        this._Finish(values)
    }

    _Finish(values) {
        this._values := values
        this._loaded := true
        this._Apply()
        onDone := this._onDone
        this._onDone := ""
        this._onDown := ""
        onDone()
    }

    _Keep() {
        try {
            this._engine.peer.Request("storage", "cmd.storage.settings.keepBroken", Map()
                , (res) => this._OnKept(res), EngineSettings.TIMEOUT_MS)
        } catch as e {
            this._engine._Log("a0", "engine", "keeping Settings.json as broken failed: " e.Message)
        }
    }

    _OnKept(res) {
        if (!res.payload.Get("ok", false))
            this._engine._Log("a0", "engine", "keeping Settings.json as broken failed: " Engine._ErrorText(res))
    }

    ; --- commands ----------------------------------------------------------------------------------------------

    ; cmd.settings.get: { ok, settings }. busy while the engine has not read the file.
    CmdGet(msg) {
        if (!this._loaded)
            throw AhfError("the settings are being loaded", ErrCode.BUSY)
        return Map("settings", this.Wire())
    }

    ; cmd.settings.set { settings: partial }: the answer comes after storage wrote the file. { ok, changed: [keys] }.
    CmdSet(msg) {
        if (!this._loaded)
            throw AhfError("the settings are being loaded", ErrCode.BUSY)
        checked := SettingsModel.CheckPartial(msg.payload.Get("settings", ""))
        changed := []
        ; A change is a change against the values with every waiting change applied, not against the values in force: a waiting
        ; change would otherwise win over a later one that equals the old value.
        effective := this._Effective()
        for key, value in checked {
            if (!EngineSettings._Same(effective[key], value))
                changed.Push(key)
        }
        if (changed.Length = 0)
            return Map("changed", [])
        this._queue.Push(Map("request", msg, "checked", checked, "changed", changed))
        this._Next()
        return Deferred.Marker()
    }

    ; The values in force with all waiting changes applied in order (the first one is the one that is being written).
    _Effective() {
        values := this._values
        for item in this._queue
            values := SettingsModel.Merge(values, item["checked"])
        return values
    }

    ; Writes the oldest waiting change.
    _Next() {
        if (this._busy || this._queue.Length = 0)
            return
        item := this._queue[1]
        this._busy := true
        merged := SettingsModel.Merge(this._values, item["checked"])
        try {
            this._engine.peer.Request("storage", "cmd.storage.settings.write", Map("text", SettingsModel.ToText(merged))
                , (res) => this._OnWritten(item, merged, res), EngineSettings.TIMEOUT_MS)
        } catch as e {
            this._Done(item, "", Type(e) ": " e.Message)
        }
    }

    _OnWritten(item, merged, res) {
        if (!res.payload.Get("ok", false)) {
            this._Done(item, "", Engine._ErrorText(res))
            return
        }
        this._values := merged
        this._Apply()
        this._Done(item, merged, "")
    }

    ; The change is over: answer, then the next one. why is "" for a change that was written.
    _Done(item, merged, why) {
        this._busy := false
        this._queue.RemoveAt(1)
        request := item["request"]
        try {
            if (why = "") {
                this._engine.peer.Reply(request, Map("changed", item["changed"]))
            } else {
                this._engine._StorageError("settings.write", "Settings.json", why)
                this._engine.peer.Reply(request, Map("ok", false, "error", Map("code", ErrCode.INTERNAL
                    , "message", "Settings.json was not written: " why)))
            }
        } catch as e {
            this._engine._Log("a0", "engine", "answer of cmd.settings.set not sent: " Type(e) ": " e.Message)
        }
        this._Next()
    }

    ; --- effect ------------------------------------------------------------------------------------------------

    ; The settings are new: the log thresholds, the language and the pool in this process, then everyone else is told.
    _Apply() {
        this._engine.ApplySettings(this._values)
        payload := Map("settings", this.Wire())
        this._engine.Emit("topic:settings", "evt.settings.changed", payload)
        ; The supervisor takes the options of new processes and its own log thresholds from it (it is not a subscriber).
        try {
            this._engine.peer.Send("supervisor", "evt.settings.changed", Map("settings", payload["settings"]))
        } catch as e {
            this._engine._Log("a1", "engine", "settings not sent to the supervisor: " Type(e) ": " e.Message)
        }
    }

    ; Settings values are text, whole numbers, 1 and 0 or a Map of windows: equal when the texts are equal (maps by content).
    static _Same(a, b) {
        if (a is Map || b is Map)
            return Json.Stringify(a) == Json.Stringify(b)
        return a == b
    }
}
