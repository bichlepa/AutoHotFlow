#Requires AutoHotkey v2.0
#Include ..\Errors.ahk
#Include ..\Ids.ahk
#Include ..\Json.ahk
#Include ..\Log.ahk
#Include ..\Time.ahk
#Include Message.ahk
#Include Dispatcher.ahk
#Include PipeConnection.ahk
#Include Wake.ahk

; The message layer of one process (doc/PROTOCOL.md, sections 1, 2 and 5). Every role talks
; through one Peer: it connects to the hub, answers requests, sends events, matches answers to
; requests and reconnects after a lost connection.
;
;   peer := Peer("engine", hubPipeName, Map("hubHwnd", hubWindowHandle))
;   peer.On("cmd.flow.", (msg) => Map("rev", 1))      ; answers cmd.flow.* (payload Map or nothing)
;   peer.OnReady := () => ...                          ; after every successful handshake
;   peer.OnClosed := () => ...                         ; once, when the peer is closed for good
;   peer.Subscribe("flow:Flow 1")
;   peer.Connect()                                     ; does not block, see "Handshake" below
;   peer.Request("storage", "cmd.storage.flow.read", Map("path", p), (res) => ..., 30000)
;   peer.Send("topic:engine", "evt.engine.ready", Map("epoch", 1))
;
; Options (Map or object): hubHwnd (window of the hub, enables the wake-up, default 0),
; reconnectTotalMs (default 10000), helloTimeoutMs (default 3000).
;
; Handshake: Connect() opens the pipe with one non-blocking attempt and retries on a timer
; (backoff, see _ScheduleRetry). After the connection is open the peer sends sys.hello with its
; window handle. SendFrame posts WM_AHF_WAKE to hubHwnd, so the hub accepts the new client at
; once and does not wait for its 250 ms fallback. When sys.welcome arrives, the peer subscribes
; its topics again, sets status "ready" and calls OnReady.
;
; Rules: each request ends with exactly one callback, either with the real answer or with a
; synthetic error: timeout (deadline passed), peer_gone (connection lost, or not connected),
; shutting_down (Close). A real answer that comes after that is counted in lateReplies and dropped.
; Handlers and callbacks run on the message path: they must not block, wait, or touch files.
; Only one Peer per process: it owns the wake-up (Wake.Install) of its connection.
class Peer {
    static PROTOCOL := 1
    static MAX_PENDING := 1000
    static RECONNECT_FIRST_MS := 100
    static RECONNECT_MAX_MS := 2000
    static DEFAULT_TIMEOUT_MS := 5000
    static DEFAULT_RECONNECT_TOTAL_MS := 10000
    static DEFAULT_HELLO_TIMEOUT_MS := 3000

    OnReady := ""
    OnClosed := ""
    ; idle | connecting | handshake | ready | reconnecting | closed
    status := "idle"
    ; With status closed: local | hub_unreachable | denied
    closeReason := ""
    ; Transport reason of the last lost connection (PipeConnection close reasons)
    lastCloseReason := ""
    hubSession := ""
    lateReplies := 0
    badFrames := 0
    droppedSends := 0

    __New(name, hubPipeName, options := "") {
        if (name = "")
            throw AhfError("Peer: name is empty", ErrCode.BAD_ARGS)
        this.name := name
        this.hubPipe := hubPipeName
        this.hubHwnd := Peer._Opt(options, "hubHwnd", 0)
        this.reconnectTotalMs := Peer._Opt(options, "reconnectTotalMs", Peer.DEFAULT_RECONNECT_TOTAL_MS)
        this.helloTimeoutMs := Peer._Opt(options, "helloTimeoutMs", Peer.DEFAULT_HELLO_TIMEOUT_MS)
        if (Ids.processName = "")
            Ids.Configure(name)
        this._dispatcher := Dispatcher()
        this._pending := Map()
        this._topics := Map()
        this._conn := ""
        this._helloId := ""
        this._backoff := Peer.RECONNECT_FIRST_MS
        this._budgetStart := 0
        this._pumpFn := () => this._Pump()
        this._retryFn := () => this._Attempt()
        this._welcomeFn := () => this._OnWelcomeTimeout()
    }

    ; Number of requests waiting for an answer. Every one of them owns exactly one timer.
    PendingCount => this._pending.Count

    ; Counters for the snapshot (doc/PROTOKOLL.md 4.9): the peer's own and those of the connection (send queue,
    ; failed handlers). Cheap and without side effects.
    Stats() {
        conn := this._conn
        return Map("status", this.status, "pending", this._pending.Count, "lateReplies", this.lateReplies
            , "badFrames", this.badFrames, "droppedSends", this.droppedSends
            , "queuedFrames", IsObject(conn) ? conn.QueuedFrames : 0, "queuedBytes", IsObject(conn) ? conn.QueuedBytes : 0
            , "handlerErrors", IsObject(conn) ? conn.handlerErrors : 0)
    }

    ; The topics this peer subscribes to (sorted).
    Topics() {
        names := []
        for topic, _ in this._topics
            names.Push(topic)
        return names
    }

    ; Registers the handler for incoming messages whose type starts with typePrefix.
    On(typePrefix, handler) {
        this._dispatcher.On(typePrefix, handler)
    }

    ; Starts the connection. Runs once. Returns at once; OnReady or OnClosed report the outcome.
    Connect() {
        if (this.status != "idle")
            throw AhfError("Peer.Connect: status is " this.status ", Connect runs once", ErrCode.INTERNAL)
        this.status := "connecting"
        this._budgetStart := Time.NowMs()
        this._backoff := Peer.RECONNECT_FIRST_MS
        Wake.Install(this._pumpFn)
        this._Attempt()
    }

    ; Ends the peer for good: pending requests get shutting_down, OnClosed is called once. Frames that still wait
    ; in the send queue of the connection are dropped (use CloseWhenFlushed for the last frames of a process).
    Close() {
        this._Closed("local")
    }

    ; Ends the peer for good like Close, but what was sent before still leaves (WI-30, F-26): the connection
    ; takes no new frames and closes when its send queue is written or after timeoutMs
    ; (PipeConnection.CloseWhenFlushed). The connection is detached first, so its end starts no reconnect and
    ; incoming frames are no longer handled. onDone(flushed) is called once, never inside this call; flushed is
    ; false when there was no open connection, frames were dropped at the deadline, or the hub went away.
    CloseWhenFlushed(timeoutMs, onDone) {
        conn := this._conn
        if (this.status = "closed" || !IsObject(conn) || !conn.IsOpen) {
            this._Closed("local")
            SetTimer(() => onDone(false), -1)
            return
        }
        this._conn := ""
        conn.OnFrame := ""
        conn.OnClose := ""
        this._Closed("local")
        if (!conn.CloseWhenFlushed(timeoutMs, onDone))
            SetTimer(() => onDone(false), -1)
    }

    ; Topic subscription. Kept across reconnects: it is sent again after every handshake.
    Subscribe(topic) {
        if (topic = "")
            throw AhfError("Peer.Subscribe: topic is empty", ErrCode.BAD_ARGS)
        this._topics[topic] := true
        if (this.status = "ready")
            this._SendSubscribe(topic)
    }

    ; Sends an event or other message without an answer. Returns the message id, or "" when the
    ; peer is not ready or the frame was refused (counted in droppedSends). Events are not kept.
    Send(to, msgType, payload := "") {
        if (SubStr(msgType, 1, 4) = "cmd.")
            throw AhfError("Peer.Send: '" msgType "' is a request, use Request", ErrCode.BAD_ARGS)
        if (!IsObject(payload))
            payload := Map()
        if (this.status != "ready" || !IsObject(this._conn)) {
            this.droppedSends += 1
            return ""
        }
        id := this._NextId()
        text := Message(to, this.name, id, msgType, payload).Serialize()
        if (!this._conn.SendFrame(text)) {
            this.droppedSends += 1
            return ""
        }
        return id
    }

    ; Sends a cmd.* request. callback(answer) is called exactly once, with the answer message
    ; (payload ok:true/false) or with a synthetic error message (see the header). Returns the id.
    ; Throws AhfError (code busy) when MAX_PENDING requests are already waiting.
    Request(to, msgType, payload, callback, timeoutMs := 5000) {
        if (SubStr(msgType, 1, 4) != "cmd.")
            throw AhfError("Peer.Request: '" msgType "' is not a cmd.* message", ErrCode.BAD_ARGS)
        if (!IsInteger(timeoutMs) || timeoutMs < 1)
            throw AhfError("Peer.Request: timeoutMs must be a positive integer", ErrCode.BAD_ARGS)
        if (this._pending.Count >= Peer.MAX_PENDING)
            throw AhfError("Peer: " Peer.MAX_PENDING " requests are already waiting, refusing " msgType " to " to
                , ErrCode.BUSY)
        if (!IsObject(payload))
            payload := Map()
        id := this._NextId()
        ; Serialize before anything is registered: a payload that cannot be sent throws here, cleanly.
        text := Message(to, this.name, id, msgType, payload, "", timeoutMs).Serialize()
        rec := Map("to", to, "id", id, "type", msgType, "callback", callback
            , "timeoutMs", timeoutMs, "timerFn", "")
        timerFn := this._MakeTimeout(id)
        rec["timerFn"] := timerFn
        this._pending[id] := rec
        SetTimer(timerFn, -timeoutMs)
        if (this.status != "ready" || !IsObject(this._conn)) {
            this._DeferFail(id, ErrCode.PEER_GONE, "not connected to the hub (status " this.status ")")
            return id
        }
        try {
            sent := this._conn.SendFrame(text)
        } catch as e {
            this._Abandon(id)
            throw e
        }
        if (!sent)
            this._DeferFail(id, ErrCode.PEER_GONE, "the connection refused the frame")
        return id
    }

    ; Sends the answer to a cmd.* request whose handler returned Deferred.Marker() (WI-12). request is the
    ; Message that the handler received. Returns false when the answer could not be sent (no connection).
    ; The answer is sent as the handler's result would be: payload Map, ok added as true when missing.
    Reply(request, payload) {
        if (!IsObject(payload) || Type(payload) != "Map")
            throw AhfError("Peer.Reply: payload must be a Map", ErrCode.BAD_ARGS)
        if (!payload.Has("ok"))
            payload["ok"] := true
        return this._Transmit(request.from, Peer._ResType(request.type), payload, request.id)
    }

    ; --- connection --------------------------------------------------------------------------

    ; One non-blocking attempt. Failure means "no hub yet": the retry policy decides what happens next.
    _Attempt() {
        if (this.status != "connecting" && this.status != "reconnecting")
            return
        conn := ""
        try {
            conn := PipeConnection.Connect(this.hubPipe, 0)
        } catch {
            ; Expected while the hub is not there (or its pipe is busy). Not an error: retry.
            this._ScheduleRetry()
            return
        }
        this._Adopt(conn)
    }

    ; Next attempt after the backoff (100, 200, 400, ... ms, at most 2 s), but not after the budget
    ; (reconnectTotalMs, counted from the start of the outage) is used up.
    _ScheduleRetry() {
        remaining := this.reconnectTotalMs - (Time.NowMs() - this._budgetStart)
        if (remaining <= 0) {
            this._Closed("hub_unreachable")
            return
        }
        delay := Min(this._backoff, Max(1, Integer(remaining)))
        this._backoff := Min(this._backoff * 2, Peer.RECONNECT_MAX_MS)
        SetTimer(this._retryFn, -delay)
    }

    _Adopt(conn) {
        this._conn := conn
        conn.PeerHwnd := this.hubHwnd
        conn.OnFrame := (c, text) => this._OnFrame(text)
        conn.OnClose := (c, reason) => this._OnConnClose(c, reason)
        this.status := "handshake"
        this._helloId := this._NextId()
        hello := Message("supervisor", this.name, this._helloId, "sys.hello", Map("name", this.name
            , "pid", DllCall("GetCurrentProcessId", "uint"), "hwnd", Wake.Hwnd, "protocol", Peer.PROTOCOL))
        SetTimer(this._welcomeFn, -this.helloTimeoutMs)
        ; SendFrame also posts the wake-up to hubHwnd (see the header). If the frame cannot be
        ; queued, the connection closes and OnClose starts the retry policy.
        conn.SendFrame(hello.Serialize())
    }

    _OnWelcomeTimeout() {
        if (this.status != "handshake")
            return
        conn := this._conn
        if (IsObject(conn))
            conn.Close()        ; raises OnClose("local"), which starts the retry policy
    }

    _OnWelcome(msg) {
        if (this.status != "handshake" || msg.corr != this._helloId)
            return
        SetTimer(this._welcomeFn, 0)
        if (Peer._IsDenied(msg.payload)) {
            this._Closed("denied")
            return
        }
        this.hubSession := msg.payload.Get("session", "")
        this.status := "ready"
        this._backoff := Peer.RECONNECT_FIRST_MS
        for topic, _ in this._topics
            this._SendSubscribe(topic)
        handler := this.OnReady
        if (IsObject(handler)) {
            try {
                handler()
            } catch as e {
                Log.Write("a0", "ipc", "peer " this.name ": OnReady failed: " Type(e) ": " e.Message)
            }
        }
    }

    _OnConnClose(c, reason) {
        if (!IsObject(this._conn) || ObjPtr(c) != ObjPtr(this._conn))
            return
        this._conn := ""
        this.lastCloseReason := reason
        SetTimer(this._welcomeFn, 0)
        ; The status changes before the pending requests fail: their callbacks may send new requests,
        ; and those must be refused, not sent on the dead connection.
        this._BeginReconnect()
        this._FailAll(ErrCode.PEER_GONE, "connection to the hub lost (" reason ")")
    }

    _BeginReconnect() {
        if (this.status = "closed")
            return
        this.status := "reconnecting"
        this._budgetStart := Time.NowMs()
        this._backoff := Peer.RECONNECT_FIRST_MS
        this._ScheduleRetry()
    }

    _Closed(reason) {
        if (this.status = "closed")
            return
        this.status := "closed"
        this.closeReason := reason
        SetTimer(this._retryFn, 0)
        SetTimer(this._welcomeFn, 0)
        conn := this._conn
        this._conn := ""
        Wake.Uninstall()
        this._FailAll(reason = "local" ? ErrCode.SHUTTING_DOWN : ErrCode.PEER_GONE, "peer closed (" reason ")")
        if (IsObject(conn))
            conn.Close()
        handler := this.OnClosed
        if (IsObject(handler)) {
            try {
                handler()
            } catch as e {
                Log.Write("a0", "ipc", "peer " this.name ": OnClosed failed: " Type(e) ": " e.Message)
            }
        }
    }

    _Pump() {
        conn := this._conn
        if (!IsObject(conn))
            return
        try {
            conn.Pump()
        } catch as e {
            Log.Write("a0", "ipc", "peer " this.name ": pump failed: " Type(e) ": " e.Message)
        }
    }

    ; --- incoming ----------------------------------------------------------------------------

    _OnFrame(text) {
        try {
            msg := Message.Parse(text)
        } catch as e {
            this._RejectFrame(text, e.Message)
            return
        }
        try {
            this._Route(msg)
        } catch as e {
            Log.Write("a0", "ipc", "peer " this.name ": routing " msg.type " failed: " Type(e) ": " e.Message)
        }
    }

    ; A frame that does not validate is dropped, but a readable command still gets its error answer.
    _RejectFrame(text, reason) {
        this.badFrames += 1
        Log.Write("a0", "ipc", "peer " this.name ": bad frame dropped: " reason)
        try {
            data := Json.Parse(text)
        } catch {
            return      ; not JSON at all: there is nothing to answer
        }
        if (Type(data) != "Map" || !data.Has("from") || !data.Has("id") || !data.Has("type"))
            return
        if (Type(data["from"]) != "String" || Type(data["id"]) != "String" || Type(data["type"]) != "String")
            return
        if (SubStr(data["type"], 1, 4) != "cmd.")
            return
        this._Transmit(data["from"], Peer._ResType(data["type"])
            , Map("ok", false, "error", Map("code", ErrCode.BAD_PAYLOAD, "message", reason)), data["id"])
    }

    _Route(msg) {
        t := msg.type
        if (SubStr(t, 1, 4) = "res.") {
            this._OnReply(msg)
            return
        }
        if (t = "sys.welcome") {
            this._OnWelcome(msg)
            return
        }
        if (t = "sys.ping") {
            this._Transmit(msg.from, "sys.pong", Map("n", msg.payload.Get("n", 0)), msg.id)
            return
        }
        if (SubStr(t, 1, 4) = "cmd.") {
            result := this._dispatcher.Invoke(msg)
            ; A handler that returned Deferred answers later with Reply (WI-12). Nothing is sent now.
            if (result is Deferred)
                return
            this._Transmit(msg.from, Peer._ResType(t), result, msg.id)
            return
        }
        if (!IsObject(this._dispatcher.Find(t))) {
            Log.Write("a1", "ipc", "peer " this.name ": no handler for " t ", dropped")
            return
        }
        result := this._dispatcher.Invoke(msg)
        if (result is Deferred)
            return   ; an event has no answer, a deferred marker from it is ignored
        if (!result["ok"])
            Log.Write("a0", "ipc", "peer " this.name ": handler for " t " failed: " result["error"]["message"])
    }

    _OnReply(msg) {
        if (!this._pending.Has(msg.corr)) {
            this.lateReplies += 1
            return
        }
        this._Finish(msg.corr, msg)
    }

    ; --- requests ----------------------------------------------------------------------------

    _MakeTimeout(id) {
        return () => this._OnTimeout(id)
    }

    _OnTimeout(id) {
        if (!this._pending.Has(id))
            return
        rec := this._pending[id]
        this._Finish(id, this._ErrorReply(rec, ErrCode.TIMEOUT
            , "no answer from " rec["to"] " within " rec["timeoutMs"] " ms"))
    }

    ; Removes the request, stops its timer and calls its callback. Returns false if it was already finished.
    _Finish(id, res) {
        if (!this._pending.Has(id))
            return false
        rec := this._pending[id]
        this._pending.Delete(id)
        if (IsObject(rec["timerFn"]))
            SetTimer(rec["timerFn"], 0)
        cb := rec["callback"]
        if (IsObject(cb)) {
            try {
                cb(res)
            } catch as e {
                Log.Write("a0", "ipc", "peer " this.name ": callback for " rec["type"] " failed: " Type(e) ": " e.Message)
            }
        }
        return true
    }

    _FailAll(code, text) {
        ids := []
        for id, _ in this._pending
            ids.Push(id)
        for id in ids {
            if (this._pending.Has(id))
                this._Finish(id, this._ErrorReply(this._pending[id], code, text))
        }
    }

    ; Fails a request on the next message loop turn (never inside Request itself).
    _DeferFail(id, code, text) {
        SetTimer(() => this._FailNowIfPending(id, code, text), -1)
    }

    _FailNowIfPending(id, code, text) {
        if (this._pending.Has(id))
            this._Finish(id, this._ErrorReply(this._pending[id], code, text))
    }

    ; Drops a request that could not be sent at all (no callback, the exception goes to the caller).
    _Abandon(id) {
        if (!this._pending.Has(id))
            return
        rec := this._pending[id]
        this._pending.Delete(id)
        if (IsObject(rec["timerFn"]))
            SetTimer(rec["timerFn"], 0)
    }

    _ErrorReply(rec, code, text) {
        payload := Map("ok", false, "error", Map("code", code, "message", text))
        return Message(this.name, rec["to"], rec["id"], Peer._ResType(rec["type"]), payload, rec["id"])
    }

    ; Called from the handshake too: a refused request must not stop OnReady, so it is logged here.
    _SendSubscribe(topic) {
        try {
            this.Request("supervisor", "cmd.topic.subscribe", Map("topic", topic)
                , (res) => this._CheckSubscribe(topic, res), Peer.DEFAULT_TIMEOUT_MS)
        } catch as e {
            Log.Write("a0", "ipc", "peer " this.name ": subscribe to " topic " not sent: " e.Message)
        }
    }

    _CheckSubscribe(topic, res) {
        if (!res.payload.Get("ok", false))
            Log.Write("a0", "ipc", "peer " this.name ": subscribe to " topic " refused: " res.type)
    }

    ; --- sending helpers ---------------------------------------------------------------------

    ; Sends a message that is not a request. Returns false if there is no connection or the frame was refused.
    _Transmit(to, msgType, payload, corr := "") {
        if (!IsObject(this._conn))
            return false
        text := Message(to, this.name, this._NextId(), msgType, payload, corr).Serialize()
        return this._conn.SendFrame(text)
    }

    _NextId() {
        return Ids.Next(this.name "#")
    }

    ; "cmd.flow.start" -> "res.flow.start"
    static _ResType(cmdType) {
        return "res." (SubStr(cmdType, 1, 4) = "cmd." ? SubStr(cmdType, 5) : cmdType)
    }

    ; sys.welcome with an error (PROTOCOL 6): denied, the peer must end.
    static _IsDenied(payload) {
        return payload.Has("error") || (payload.Has("ok") && !payload["ok"])
    }

    static _Opt(options, key, fallback) {
        if (!IsObject(options))
            return fallback
        if (options is Map)
            return options.Get(key, fallback)
        return options.HasOwnProp(key) ? options.%key% : fallback
    }
}
