#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\Role.ahk
#Include ..\core\Time.ahk
#Include ..\elements\base\ElementRegistry.ahk
#Include TriggerContext.ahk

; Trigger host role (WI-0061, ARCHITECTURE 3, PROTOCOL 4.4, D0008). It arms and disarms trigger elements on command of the
; engine, holds their OS handles (hotkeys, timers) and reports their events. It never runs flows and never decides
; when a trigger fires: the engine does (PROTOCOL 4.4, the generation of an arming).
;
; An error of one trigger stops neither the others nor the host (REQ-TRG-010): an error of Enable answers the arming
; with ok false, an error of Disable is logged (the trigger is dropped anyway), an error in a callback is reported as
; evt.trigger.error and the trigger stays armed. Nothing here blocks: the element code runs in the message handlers
; and in timers, under the try/catch of the callers.
class TriggerHost extends Role {
    __New(args) {
        super.__New(args)
        this._armed := Map()         ; triggerKey -> Map("ctx", TriggerContext, "cls", class, "class", id, "gen", n, "armedMs", ms)
    }

    RegisterHandlers() {
        this.On("cmd.trigger.arm", (msg) => this._CmdArm(msg))
        this.On("cmd.trigger.disarm", (msg) => this._CmdDisarm(msg))
        this.On("cmd.trigger.reset", (msg) => this._CmdReset(msg))
        this.FollowSettings()      ; log thresholds and language (WI-0077)
    }

    ; Role part of the snapshot (doc/PROTOCOL.md 4.9): the armed triggers, without parameter values.
    DiagInfo() {
        list := []
        now := Time.NowMs()
        for key, entry in this._armed {
            list.Push(Map("triggerKey", key, "class", entry["class"], "gen", entry["gen"]
                , "sinceMs", Integer(now - entry["armedMs"])))
        }
        return Map("armed", list)
    }

    ; sys.shutdown: every trigger is disarmed, then sys.bye follows (ARCHITECTURE 6.3).
    OnShutdown(deadlineMs) {
        this._DisarmAll()
    }

    ; --- commands ------------------------------------------------------------------------------

    ; Arms a trigger. An armed key is disarmed first. The element's Enable runs under try/catch: an error answers
    ; ok false with its text, and the trigger is not armed. An unknown class is an error (not_found).
    _CmdArm(msg) {
        key := TriggerHost._Text(msg, "triggerKey")
        gen := msg.payload.Get("gen", "")
        if (!IsInteger(gen))
            throw AhfError("payload field 'gen' must be an integer", ErrCode.BAD_PAYLOAD)
        flowId := TriggerHost._Text(msg, "flowId")
        elementId := TriggerHost._Text(msg, "elementId")
        classId := TriggerHost._Text(msg, "class")
        params := TriggerHost._Map(msg, "params")
        context := msg.payload.Get("context", "")
        if (IsObject(context))
            throw AhfError("payload field 'context' must be a text", ErrCode.BAD_PAYLOAD)
        cls := ElementRegistry.Get(classId)
        if (!IsObject(cls))
            throw AhfError("unknown element class '" classId "'", ErrCode.NOT_FOUND)
        if (cls.Mode != "trigger")
            return Map("ok", false, "message", "element " classId " is not a trigger (mode " cls.Mode ")")
        this._Disarm(key)
        ctx := TriggerContext(this, key, flowId, elementId, Integer(gen), String(context))
        this._armed[key] := Map("ctx", ctx, "cls", cls, "class", classId, "gen", Integer(gen), "armedMs", Time.NowMs())
        try {
            message := cls.Enable(ctx, TriggerHost._Params(params))
        } catch as e {
            this._Forget(key, ctx, cls, "Enable failed: ")
            return Map("ok", false, "message", TriggerHost.ErrorText(e))
        }
        answer := Map("ok", true)
        if (!IsObject(message) && message != "")
            answer["message"] := String(message)
        return answer
    }

    _CmdDisarm(msg) {
        key := TriggerHost._Text(msg, "triggerKey")
        this._Disarm(key)
        return Map("ok", true)
    }

    _CmdReset(msg) {
        this._DisarmAll()
        return Map("ok", true)
    }

    ; --- arming state --------------------------------------------------------------------------

    ; Disarms one trigger: the context is closed (no more events or callbacks), then the element's Disable runs. An error
    ; of Disable is logged; the trigger is removed anyway. Returns false for an unknown key.
    _Disarm(key) {
        if (!this._armed.Has(key))
            return false
        entry := this._armed[key]
        this._armed.Delete(key)
        this._Release(entry["ctx"], entry["cls"], "Disable failed: ")
        return true
    }

    ; Removes an arming whose Enable failed. Disable runs as well, so an element can release a handle it got before the
    ; error (a hotkey that was set and then failed); its own error is logged only.
    _Forget(key, ctx, cls, prefix) {
        if (this._armed.Has(key) && this._armed[key]["ctx"] == ctx)
            this._armed.Delete(key)
        this._Release(ctx, cls, prefix)
    }

    _Release(ctx, cls, prefix) {
        ctx.Close()
        try {
            cls.Disable(ctx)
        } catch as e {
            ctx.Log("f0", prefix TriggerHost.ErrorText(e))
        }
    }

    _DisarmAll() {
        keys := []
        for key, entry in this._armed
            keys.Push(key)
        for key in keys
            this._Disarm(key)
    }

    ; --- events of a trigger (called by TriggerContext) -----------------------------------------

    ; evt.trigger.fired to the engine. Called only for an open context.
    ReportFired(ctx, data) {
        this.peer.Send("engine", "evt.trigger.fired", Map("triggerKey", ctx.triggerKey, "gen", ctx.gen
            , "flowId", ctx.flowId, "elementId", ctx.elementId, "data", data))
    }

    ; A callback of a trigger failed: log it, and tell the engine unless the trigger was disarmed meanwhile.
    ReportCallbackError(ctx, e) {
        message := TriggerHost.ErrorText(e)
        ctx.Log("f0", "callback failed: " message)
        if (!ctx.IsOpen)
            return
        this.peer.Send("engine", "evt.trigger.error", Map("triggerKey", ctx.triggerKey, "gen", ctx.gen
            , "message", message))
    }

    ; The text of an error for the answer or the event: an element error as it is, any other error with its type.
    static ErrorText(e) {
        if (e is ElementError)
            return e.Message
        if (e is Error)
            return Type(e) ": " e.Message
        return String(e)
    }

    ; --- payload helpers (as in the worker role) -------------------------------------------------

    ; A required text field. Missing, empty or non-scalar values are bad_payload.
    static _Text(msg, key) {
        v := msg.payload.Get(key, "")
        if (IsObject(v) || v = "")
            throw AhfError("payload field '" key "' is missing", ErrCode.BAD_PAYLOAD)
        return String(v)
    }

    ; An optional object field (Map), empty Map when missing.
    static _Map(msg, key) {
        v := msg.payload.Get(key, "")
        if (v = "")
            return Map()
        if (!(v is Map))
            throw AhfError("payload field '" key "' must be an object", ErrCode.BAD_PAYLOAD)
        return v
    }

    ; Element parameters as an object with case-insensitive properties; values that are objects become "" (as in the
    ; worker role).
    static _Params(source) {
        p := {}
        for k, v in source {
            if (IsObject(v))
                v := ""
            p.%k% := v
        }
        return p
    }
}
