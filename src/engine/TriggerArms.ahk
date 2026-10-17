#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\elements\base\ElementRegistry.ahk
#Include ..\elements\base\ExecContext.ahk
#Include ..\elements\base\ParamEvaluator.ahk
#Include Executor.ahk
#Include vars\BuiltInVars.ahk
#Include vars\VarAccess.ahk

; Arming of the triggers in the engine (WI-0062, PROTOCOL 4.4, ARCHITECTURE 6.1 step 4, S0003 "Design fixed while
; detailing"). The engine decides what is armed; the trigger host only arms what it is told and reports events.
;
; Passes: a pass is cmd.trigger.reset followed by one cmd.trigger.arm per enabled trigger of every loaded flow. A pass
; runs when the engine is ready and the host is ready, and again after every restart of the host. The host is "ready"
; when the supervisor says so (topic process) or when the engine asks cmd.process.list and finds it ready.
;
; Staggering: at most MAX_OPEN arm requests are open at a time; the rest waits in the queue. A pass drops the queue of
; an earlier pass, and a trigger is queued at most once (entry "queued").
;
; Generation: every arm of a trigger gets a new "gen" from this engine. Events of another generation, or of a trigger
; that is neither armed nor being armed (its arm on the way), are dropped by the engine (Accepts, Reported).
;
; Failures of an arm: a parameter that cannot be evaluated, a class that is unknown or not a trigger (checked here, the
; host is not asked), an answer ok false (the element refused), a protocol error of the host (not_found, peer_gone,
; timeout). Each keeps the trigger not armed with its text in "message". A failure that reached the host sends
; cmd.trigger.disarm for the key as well: the engine does not rely on the host to drop an earlier arming. An arm without
; an answer is retried at the next pass only, never in a loop.
;
; The start context (the tokens of the first pass only): "ahfStartup" while nothing was armed before in this start of
; AutoHotFlow, plus "windowsStartup" when the supervisor was started with --windows-startup. The first pass that finds
; the host ready consumes it; a later pass (after a restart of the host or of the engine) carries no token.
;
; Parameters are evaluated with the global, static and built-in variables (no instance, as v1): VarAccess with the
; common place. The evaluated parameters are kept per arming (ParamsOf) for the instances that the events start.
class TriggerArms {
    static HOST := "triggerhost"
    static ARM_TIMEOUT_MS := 5000
    static RESET_TIMEOUT_MS := 5000
    static DISARM_TIMEOUT_MS := 5000
    static MAX_OPEN := 2
    static HOST_DOWN := "trigger host is not running"
    static TOKEN_STARTUP := "ahfStartup"
    static TOKEN_WINDOWS := "windowsStartup"

    __New(owner) {
        this._owner := owner            ; the Engine: peer, flows, vars, Emit state (EmitTriggerState)
        this._entries := Map()          ; triggerKey -> Map(flowId, triggerId, gen, armed, message, params, queued)
        this._entries.CaseSense := "Off"
        this._gen := 0
        this._pass := 0                 ; number of the last pass; answers of an older pass are ignored
        this._engineReady := false
        this._hostReady := false
        this._hostSeen := false         ; the host was ready once in this engine process
        this._resetPending := false     ; a pass waits for the answer of cmd.trigger.reset
        this._listPending := false      ; a cmd.process.list for the state of the host is on its way
        this._queue := []               ; Maps key, context: arms that wait for a free slot
        this._open := 0                 ; arm requests on their way
        ; The first arming pass after the start of AutoHotFlow. An engine that was restarted by the supervisor has none.
        this._startupPending := !owner.args.Has("restarted")
        this._windowsStartup := owner.args.Has("windows-startup")
    }

    ; --- passes and host state ------------------------------------------------------------------------------------

    ; The engine is ready (evt.engine.ready was sent): the first pass runs when the host is ready too.
    EngineReady() {
        this._engineReady := true
        if (this._hostReady)
            this._StartPass()
        else if (!this._hostSeen)
            this._AskHost()
    }

    ; evt.process.ready of triggerhost (or its state in the answer of cmd.process.list).
    HostReady() {
        this._hostSeen := true
        if (this._hostReady)
            return
        this._hostReady := true
        if (this._engineReady)
            this._StartPass()
    }

    ; The host ended (crash, exit, restart limit). Its arms are gone; events sent meanwhile are lost (PROTOCOL 4.4).
    HostGone() {
        this._hostReady := false
        this._resetPending := false
        this._queue := []
        for key, entry in this._entries {
            entry["queued"] := false
            entry["gen"] := this._NewGen()     ; an answer or event of the lost host must not count any more
            this._Forget(entry, TriggerArms.HOST_DOWN)
        }
    }

    ; The flow leaves the flow table: its triggers are disarmed (the engine calls it when it removes a flow).
    FlowRemoved(flowId) {
        keys := []
        for key, entry in this._entries {
            if (entry["flowId"] = flowId)
                keys.Push(key)
        }
        for key in keys {
            this._entries.Delete(key)
            this._SendDisarm(key)
        }
    }

    ; --- switches (cmd.trigger.enable/disable, cmd.flow.enable/disable; E0056) ---------------------------------------

    ; One trigger of rec changed its target state. An enabled trigger is queued for arming (a pass that is still waiting
    ; for its reset includes it); a disabled one is disarmed at once. The caller emits evt.trigger.state.
    Changed(rec, triggerId) {
        if (!rec.TriggerEnabled(triggerId)) {
            this._Disarm(rec.FlowId, triggerId)
            return
        }
        entry := this._Entry(rec.FlowId, triggerId)
        if (!this._engineReady)
            return                          ; the first pass arms it
        if (!this._hostReady) {
            this._Forget(entry, TriggerArms.HOST_DOWN)
            return
        }
        if (!this._resetPending)
            this._Enqueue(rec.FlowId, triggerId, "")
        this._Pump()
    }

    ; --- queries (the engine, the snapshot, the start path) -----------------------------------------------------------

    ; True if an event of this arming may start an instance: the trigger is armed with this generation, or its arm is on
    ; its way. The host can fire inside Enable, before its answer to the arm arrives; the answer may still refuse the
    ; arming, and then the instances that the event started run on (as v1 would start them).
    Accepts(key, gen) {
        entry := this._entries.Get(key, "")
        return IsObject(entry) && entry["gen"] = gen && (entry["armed"] || entry["sent"])
    }

    ; True if the generation is the current one of the trigger (armed or not): an error of a callback is reported then.
    Current(key, gen) {
        entry := this._entries.Get(key, "")
        return IsObject(entry) && entry["gen"] = gen
    }

    ; The evaluated parameters of the current arming (an object), "" if none.
    ParamsOf(key) {
        entry := this._entries.Get(key, "")
        return IsObject(entry) ? entry["params"] : ""
    }

    ; The state of one trigger for evt.trigger.state and the snapshot: Map(armed, message).
    Info(flowId, triggerId) {
        entry := this._entries.Get(TriggerArms.KeyOf(flowId, triggerId), "")
        if (!IsObject(entry))
            return Map("armed", false, "message", "")
        return Map("armed", entry["armed"], "message", entry["message"])
    }

    ; The triggers of a flow for the snapshot: an Array of Map(elementId, enabled, armed, message).
    Snapshot(rec) {
        out := []
        for triggerId in rec.Def.Triggers() {
            info := this.Info(rec.FlowId, triggerId)
            out.Push(Map("elementId", triggerId, "enabled", Json.Bool(rec.TriggerEnabled(triggerId))
                , "armed", Json.Bool(info["armed"]), "message", info["message"]))
        }
        return out
    }

    ; The parameters of a start that is not a fired event (cmd.flow.start, CallFlow): the stored parameters evaluated now,
    ; like at an arming, with data "". "" when they cannot be evaluated (logged, the instance starts without them).
    StartInfo(rec, triggerId) {
        ev := this._Evaluate(rec, triggerId)
        if (!ev["ok"]) {
            Log.Write("f0", "engine", "trigger '" triggerId "': its parameters cannot be evaluated, the instance starts "
                . "without its trigger variables: " ev["error"], rec.FlowId)
            return ""
        }
        return Map("params", ev["params"], "data", "")
    }

    ; An evt.trigger.error of the current arming: the message of the trigger (it stays armed).
    Reported(key, gen, text) {
        entry := this._entries.Get(key, "")
        if (!IsObject(entry) || entry["gen"] != gen)
            return false
        entry["message"] := text
        this._Emit(entry)
        return true
    }

    ; --- arming ----------------------------------------------------------------------------------------------------

    ; A new pass: reset, then the arms of every enabled trigger when the reset is answered. Earlier answers are ignored.
    _StartPass() {
        this._pass += 1
        pass := this._pass
        this._queue := []
        for key, entry in this._entries
            entry["queued"] := false
        this._resetPending := true
        try {
            this._owner.peer.Request(TriggerArms.HOST, "cmd.trigger.reset", Map()
                , (res) => this._OnReset(pass, res), TriggerArms.RESET_TIMEOUT_MS)
        } catch as e {
            this._resetPending := false
            Log.Write("a1", "engine", "trigger host not reached for the reset: " Executor.ErrorText(e))
        }
    }

    _OnReset(pass, res) {
        if (pass != this._pass)
            return
        this._resetPending := false
        if (!res.payload.Get("ok", false)) {
            Log.Write("a1", "engine", "trigger host refused the reset: " TriggerArms._AnswerText(res))
            return
        }
        ; The host is clear now: nothing of an earlier arming is left in it, and the start context is used up.
        context := this._Context()
        this._startupPending := false
        for rec in this._owner.flows.All() {
            for triggerId in rec.EnabledTriggers()
                this._Enqueue(rec.FlowId, triggerId, context)
        }
        this._Pump()
    }

    ; The tokens of the start context of this pass (see the header).
    _Context() {
        if (!this._startupPending)
            return ""
        if (this._windowsStartup)
            return TriggerArms.TOKEN_STARTUP " " TriggerArms.TOKEN_WINDOWS
        return TriggerArms.TOKEN_STARTUP
    }

    _Enqueue(flowId, triggerId, context) {
        entry := this._Entry(flowId, triggerId)
        if (entry["queued"])
            return
        entry["queued"] := true
        this._queue.Push(Map("key", TriggerArms.KeyOf(flowId, triggerId), "context", context))
    }

    _Pump() {
        while (this._open < TriggerArms.MAX_OPEN && this._queue.Length > 0) {
            job := this._queue.RemoveAt(1)
            this._StartArm(job["key"], job["context"])
        }
    }

    ; Evaluates the parameters and sends one arm. Nothing is sent for a failure that the engine sees itself.
    _StartArm(key, context) {
        entry := this._entries.Get(key, "")
        if (!IsObject(entry))
            return
        entry["queued"] := false
        flowId := entry["flowId"]
        triggerId := entry["triggerId"]
        rec := this._owner.flows.Get(flowId)
        if (!IsObject(rec) || !rec.TriggerEnabled(triggerId))
            return                          ; switched off or gone since it was queued
        gen := this._NewGen()
        entry["gen"] := gen
        entry["armed"] := false
        entry["params"] := ""
        ev := this._Evaluate(rec, triggerId)
        if (!ev["ok"]) {
            this._Failed(key, gen, ev["error"], false)
            return
        }
        entry["params"] := ev["params"]
        payload := Map("triggerKey", key, "gen", gen, "flowId", flowId, "elementId", triggerId
            , "class", ev["classId"], "params", TriggerArms._Wire(ev["params"]), "context", context)
        this._open += 1
        entry["sent"] := true
        try {
            this._owner.peer.Request(TriggerArms.HOST, "cmd.trigger.arm", payload
                , (res) => this._OnArm(key, gen, res), TriggerArms.ARM_TIMEOUT_MS)
        } catch as e {
            this._open -= 1
            entry["sent"] := false
            this._Failed(key, gen, "trigger host not reached: " Executor.ErrorText(e), true)
        }
    }

    _OnArm(key, gen, res) {
        this._open -= 1
        if (!this.Current(key, gen)) {
            Log.Write("a2", "engine", "answer of an arm that was replaced or switched off is dropped: " key)
            this._Pump()
            return
        }
        p := res.payload
        this._entries[key]["sent"] := false
        if (p.Get("ok", false)) {
            entry := this._entries[key]
            msg := p.Get("message", "")
            entry["armed"] := true
            entry["message"] := IsObject(msg) ? "" : String(msg)
            this._Emit(entry)
        } else if (p.Get("error", "") is Map) {
            ; A protocol error: the host did not arm it (unknown class, no answer, peer gone). Not retried here.
            this._Failed(key, gen, "trigger host: " TriggerArms._AnswerText(res), true)
        } else {
            ; The element refused (its Enable failed): the host has dropped its arming already.
            this._Failed(key, gen, TriggerArms._Message(p, "the trigger refused to arm"), true)
        }
        this._Pump()
    }

    ; The arming of the current generation failed: not armed, with its text. disarm: send cmd.trigger.disarm too.
    _Failed(key, gen, text, disarm) {
        entry := this._entries.Get(key, "")
        if (!IsObject(entry) || entry["gen"] != gen)
            return
        entry["armed"] := false
        entry["sent"] := false
        entry["message"] := text
        Log.Write("f1", "engine", "trigger '" entry["triggerId"] "' is not armed: " text, entry["flowId"])
        this._Emit(entry)
        if (disarm)
            this._SendDisarm(key)
    }

    ; Disarms one trigger that the engine no longer wants armed (switched off).
    _Disarm(flowId, triggerId) {
        key := TriggerArms.KeyOf(flowId, triggerId)
        if (!this._entries.Has(key))
            return
        this._entries.Delete(key)       ; a queued or open arm finds no entry and does nothing
        this._SendDisarm(key)
    }

    _SendDisarm(key) {
        if (!this._hostReady)
            return
        try {
            this._owner.peer.Request(TriggerArms.HOST, "cmd.trigger.disarm", Map("triggerKey", key)
                , (res) => this._OnDisarm(key, res), TriggerArms.DISARM_TIMEOUT_MS)
        } catch as e {
            Log.Write("a2", "engine", "disarm of " key " not sent: " Executor.ErrorText(e))
        }
    }

    _OnDisarm(key, res) {
        if (!res.payload.Get("ok", false))
            Log.Write("a1", "engine", "disarm of " key " not confirmed: " TriggerArms._AnswerText(res))
    }

    ; Asks the supervisor for the state of the host (once, when the engine is ready and the host never was).
    _AskHost() {
        if (this._listPending)
            return
        this._listPending := true
        try {
            this._owner.peer.Request("supervisor", "cmd.process.list", Map(), (res) => this._OnHostState(res), 5000)
        } catch as e {
            this._listPending := false
        }
    }

    _OnHostState(res) {
        this._listPending := false
        if (!res.payload.Get("ok", false) || this._hostSeen)
            return
        for p in res.payload.Get("processes", []) {
            if (p is Map && p.Get("name", "") = TriggerArms.HOST && p.Get("state", "") = "ready") {
                this.HostReady()
                return
            }
        }
    }

    ; --- evaluation and entries ------------------------------------------------------------------------------------

    ; The parameters of a trigger of rec, evaluated with the global, static and built-in variables. Returns Map(ok, params,
    ; classId) or Map(ok false, error). Errors are the texts of v1 (ParamEvaluator, ElementRegistry.MissingText).
    _Evaluate(rec, triggerId) {
        def := rec.Def
        qid := Executor._QidOf(def, triggerId)
        cls := ElementRegistry.Get(qid)
        if (!IsObject(cls))
            return Map("ok", false, "error", ElementRegistry.MissingText(qid))
        if (cls.Mode != "trigger")
            return Map("ok", false, "error", "element " qid " is not a trigger (mode " cls.Mode ")")
        elem := def.Element(triggerId)
        name := (elem is Map) ? elem.Get("name", "") : ""
        env := Map("flowId", rec.FlowId, "elementId", triggerId, "flowName", def.Name
            , "elementName", IsObject(name) ? "" : String(name)
            , "workingDir", BuiltInVars.WorkingDirOf(def.Raw.Get("flowSettings", ""), this._owner.settings.Value("workingDir")))
        try {
            ctx := ExecContext(rec.FlowId, triggerId, "", "", "", VarAccess(this._owner.vars, "", "", env))
            ctx.cls := cls
            ctx.strictTypes := def.StrictTypes
            values := ctx.EvalParams(Executor._Params(def, triggerId))
        } catch as e {
            return Map("ok", false, "error", Executor.ErrorText(e))
        }
        return Map("ok", true, "params", values, "classId", qid)
    }

    _Entry(flowId, triggerId) {
        key := TriggerArms.KeyOf(flowId, triggerId)
        if (!this._entries.Has(key))
            this._entries[key] := Map("flowId", flowId, "triggerId", triggerId, "gen", 0, "armed", false
                , "message", "", "params", "", "queued", false, "sent", false)
        return this._entries[key]
    }

    ; Marks an entry as not armed with a message and tells the state.
    _Forget(entry, text) {
        entry["armed"] := false
        entry["sent"] := false
        entry["message"] := text
        this._Emit(entry)
    }

    _Emit(entry) {
        this._owner.EmitTriggerState(entry["flowId"], entry["triggerId"])
    }

    _NewGen() {
        this._gen += 1
        return this._gen
    }

    static KeyOf(flowId, triggerId) => flowId "/" triggerId

    ; The parameters as a Map for the wire (values that are objects are made fit for JSON, as for the worker role).
    static _Wire(values) {
        m := Map()
        m.CaseSense := "Off"
        for k, v in values.OwnProps()
            m[k] := Executor.ToWire(v)
        return m
    }

    ; The text of an answer for the log: its error code and message, or its message.
    static _AnswerText(res) {
        p := res.payload
        if (p.Get("error", "") is Map)
            return p["error"].Get("code", "") ": " p["error"].Get("message", "")
        return TriggerArms._Message(p, "no details")
    }

    static _Message(p, fallback) {
        m := p.Get("message", "")
        return (IsObject(m) || m = "") ? fallback : String(m)
    }
}
