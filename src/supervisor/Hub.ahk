#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Time.ahk
#Include ..\core\Role.ahk
#Include ..\core\Json.ahk
#Include ..\core\ipc\Message.ahk
#Include ..\core\ipc\Dispatcher.ahk
#Include ..\core\ipc\PipeListener.ahk
#Include ..\core\ipc\Wake.ahk

; The hub of the star topology (doc/ARCHITEKTUR.md D6, doc/PROTOKOLL.md 1, 2, 3, 5).
; Owned by the supervisor. It accepts pipe clients, performs the handshake (sys.hello/sys.welcome),
; routes messages by `to`, keeps the topic subscriptions and answers the messages addressed to
; "supervisor". It contains no business logic: the supervisor registers handlers with On().
;
;   hub := Hub("ahf.main.hub", "main")
;   hub.On("cmd.app.", (msg) => Map())      ; local handlers, prefix as in Dispatcher
;   hub.onHello := (link) => ...            ; function property, called after sys.welcome
;   hub.onLinkLost := (link, reason) => ... ; function property, called once per lost link
;   hub.Start()                             ; creates the pipe (throws if the name is taken)
;   hub.Publish("process", "evt.process.ready", Map("name", "echo"))
;
; Rules that are enforced here:
;   - `from` is set from the connection, a value sent by the client is replaced.
;   - Nothing but sys.hello is accepted before the handshake.
;   - Every cmd.* gets an answer (res.*), also when the target is unknown (not_found) or gone (peer_gone).
;   - A client whose send queue overflows is removed; the supervisor decides what that means.
;   - Nothing blocks: pipe I/O is overlapped and handled in Pump(), requests to clients carry no wait.
; Requests the supervisor sends itself (Request) get exactly one callback: the answer, a synthetic
; answer {ok:false, error:{code:"timeout"}} when timeoutMs has passed, or "" when the link is lost first.
; A real answer that comes after the timeout is dropped and counted in droppedAnswers (Peer does the same).
class Hub {
    static PROTOCOL := 1
    static SUPERVISOR := "supervisor"
    ; Default deadline of Request. Every request has one: nothing waits without a time limit.
    static DEFAULT_REQUEST_TIMEOUT_MS := 5000
    ; A pipe connection has this long to say sys.hello, then it is closed.
    static HELLO_TIMEOUT_MS := 5000
    ; Accepts per Pump, so a flood of new clients cannot keep the message loop busy.
    static ACCEPTS_PER_PUMP := 64

    onHello := ""
    onLinkLost := ""
    session := ""
    Listener := ""
    ; Answers that arrived after their request had timed out or ended (or with an unknown corr).
    droppedAnswers := 0

    __New(pipeName, session) {
        this.pipeName := pipeName
        this.session := session
        this._anon := Map()       ; ObjPtr(conn) -> Map("conn", conn, "since", ms)
        this._links := Map()      ; name -> link Map (see _Link)
        this._byConn := Map()     ; ObjPtr(conn) -> name
        this._pending := Map()    ; request id -> Map("to", name, "type", msgType, "cb", fn, "timerFn", fn)
        this._dispatcher := Dispatcher()
        this._dispatcher.On("cmd.topic.", (msg) => this._SetTopic(msg))
        this._pumpFn := () => this.Pump()
    }

    ; Registers a handler for messages addressed to "supervisor" (sys.*, cmd.*). Same rules as Dispatcher.On.
    On(typePrefix, handler) {
        this._dispatcher.On(typePrefix, handler)
    }

    ; Creates the listener and installs the wake-up. Throws AhfError if the pipe name is already served.
    Start() {
        this.Listener := PipeListener(this.pipeName)
        Wake.Install(this._pumpFn)
    }

    ; Accepts new clients and reads what has arrived. Called on wake-up and by the fallback timer.
    Pump() {
        if (!IsObject(this.Listener))
            return
        loop Hub.ACCEPTS_PER_PUMP {
            try {
                conn := this.Listener.Accept()
            } catch as e {
                Log.Write("a0", "hub", "accept failed: " Type(e) ": " e.Message)
                break
            }
            if (conn = "")
                break
            this._AdoptAnon(conn)
        }
        for conn in this._Conns() {
            try {
                conn.Pump()
            } catch as e {
                ; One broken connection must not stop the others. Its state is handled by its own close.
                Log.Write("a0", "hub", "pump failed: " Type(e) ": " e.Message)
            }
        }
    }

    ; Closes connections that have not said sys.hello in time. Called by the supervisor's timer.
    Tick(now) {
        for key, rec in this._anon.Clone() {
            if (now - rec["since"] >= Hub.HELLO_TIMEOUT_MS) {
                Log.Write("a1", "hub", "connection closed: no sys.hello within " Hub.HELLO_TIMEOUT_MS " ms")
                rec["conn"].Close()
            }
        }
    }

    ; Closes the listener and every connection (local close, no notification to the hub callbacks
    ; beyond the normal ones). Called at the end of the supervisor's life.
    Close() {
        if (IsObject(this.Listener))
            this.Listener.Close()
        for conn in this._Conns()
            conn.Close()
        Wake.Uninstall()
    }

    ; --- queries for the supervisor -----------------------------------------------------------

    HasLink(name) => this._links.Has(name)

    LinkNames() {
        names := []
        for name, _ in this._links
            names.Push(name)
        return names
    }

    ; Names of the connected clients whose base name (before ":") is one of bases (an Array).
    LinkNamesWithBase(bases) {
        names := []
        for name, _ in this._links
            if (Hub._InList(Role.BaseName(name), bases))
                names.Push(name)
        return names
    }

    ; Sends a message to a connected client without waiting. Returns false if there is no such client
    ; or its connection refused the frame.
    Send(name, msgType, payload := "", corr := "") {
        link := this._links.Get(name, "")
        if (link = "")
            return false
        return this._SendFrame(link, Message(name, Hub.SUPERVISOR, this._NextId(), msgType, payload, corr).Serialize())
    }

    ; Asks a client a cmd.* question. cb(answer) is called exactly once: with the answer message, with the
    ; synthetic timeout answer after timeoutMs, or with "" when the client is gone before it answers.
    ; Returns the id. Throws AhfError (bad_args) for a non-cmd type or a timeoutMs that is not a positive integer.
    Request(name, msgType, payload, cb, timeoutMs := 5000) {
        if (SubStr(msgType, 1, 4) != "cmd.")
            throw AhfError("Hub.Request: '" msgType "' is not a cmd.* message", ErrCode.BAD_ARGS)
        if (!IsInteger(timeoutMs) || timeoutMs < 1)
            throw AhfError("Hub.Request: timeoutMs must be a positive integer", ErrCode.BAD_ARGS)
        id := this._NextId()
        link := this._links.Get(name, "")
        ; Not sent: the callback runs on the next message loop turn, never inside the caller.
        if (link = "") {
            SetTimer(() => this._CallBack(cb, ""), -1)
            return id
        }
        ; The id is registered before the frame leaves, so the answer (corr = id) always finds its callback.
        ; The timer starts after the frame: a refused frame leaves no timer behind.
        this._pending[id] := Map("to", name, "type", msgType, "cb", cb, "timerFn", "")
        if (!this._SendFrame(link, Message(name, Hub.SUPERVISOR, id, msgType, payload, "", timeoutMs).Serialize())) {
            this._pending.Delete(id)
            SetTimer(() => this._CallBack(cb, ""), -1)
            return id
        }
        timerFn := () => this._OnTimeout(id)
        this._pending[id]["timerFn"] := timerFn
        SetTimer(timerFn, -timeoutMs)
        return id
    }

    ; Publishes an event to every client subscribed to topic (from "supervisor").
    Publish(topic, msgType, payload := "") {
        text := Message("topic:" topic, Hub.SUPERVISOR, this._NextId(), msgType, payload).Serialize()
        this._Fanout(topic, text, "")
    }

    ; --- connections -------------------------------------------------------------------------

    _AdoptAnon(conn) {
        conn.OnFrame := (c, text) => this._OnFrame(c, text)
        conn.OnClose := (c, reason) => this._OnClose(c, reason)
        this._anon[ObjPtr(conn)] := Map("conn", conn, "since", Time.NowMs())
    }

    _Conns() {
        conns := []
        for _, rec in this._anon
            conns.Push(rec["conn"])
        for _, link in this._links
            conns.Push(link["conn"])
        return conns
    }

    _OnFrame(conn, text) {
        name := this._byConn.Get(ObjPtr(conn), "")
        try {
            msg := Message.Parse(text)
        } catch as e {
            this._BadFrame(conn, name, text, e.Message)
            return
        }
        if (name = "") {
            this._Hello(conn, msg)
            return
        }
        this._Route(this._links[name], msg)
    }

    ; A frame that does not validate is dropped; a readable command still gets its error answer.
    _BadFrame(conn, name, text, reason) {
        Log.Write("a0", "hub", "bad frame dropped (" (name = "" ? "before hello" : name) "): " reason)
        if (name = "")
            return
        try {
            data := Json.Parse(text)
        } catch {
            return
        }
        if (Type(data) != "Map" || !data.Has("id") || !data.Has("type"))
            return
        if (Type(data["type"]) != "String" || SubStr(data["type"], 1, 4) != "cmd." || Type(data["id"]) != "String")
            return
        this._Reply(this._links[name], data["type"], data["id"]
            , Map("ok", false, "error", Map("code", ErrCode.BAD_PAYLOAD, "message", reason)))
    }

    ; sys.hello: the first message of every connection. Replies with sys.welcome, or denies and closes.
    _Hello(conn, msg) {
        key := ObjPtr(conn)
        if (msg.type != "sys.hello") {
            Log.Write("a1", "hub", "message " msg.type " before sys.hello dropped")
            return
        }
        claimed := msg.payload.Get("name", "")
        name := (Type(claimed) = "String") ? claimed : ""
        if (name = "" || name = Hub.SUPERVISOR || SubStr(name, 1, 6) = "topic:" || name = "*") {
            this._Deny(conn, msg, "invalid name '" name "'")
            return
        }
        if (msg.payload.Get("protocol", 0) != Hub.PROTOCOL) {
            this._Deny(conn, msg, "protocol " msg.payload.Get("protocol", "?") " not supported, need " Hub.PROTOCOL)
            return
        }
        if (this._links.Has(name)) {
            ; A reconnect may arrive before the old connection is noticed as lost. The new one wins.
            old := this._links[name]
            Log.Write("a1", "hub", "client '" name "' reconnected, old connection replaced")
            this._Unlink(name)
            this._FailPending(name)
            old["conn"].Close()
        }
        this._anon.Delete(key)
        link := Map("name", name, "conn", conn, "pid", msg.payload.Get("pid", 0)
            , "hwnd", msg.payload.Get("hwnd", 0), "topics", Map(), "helloAt", Time.NowMs())
        this._links[name] := link
        this._byConn[key] := name
        conn.PeerHwnd := Integer(link["hwnd"])
        peers := Map()
        for n, l in this._links
            peers[n] := Map("hwnd", l["hwnd"])
        welcome := Map("ok", true, "session", this.session, "peers", peers, "settingsRev", 0)
        this._SendFrame(link, Message(name, Hub.SUPERVISOR, this._NextId(), "sys.welcome", welcome, msg.id).Serialize())
        Log.Write("a1", "hub", "client '" name "' connected (pid " link["pid"] ")")
        fn := this.onHello
        if (IsObject(fn)) {
            try {
                fn(link)
            } catch as e {
                Log.Write("a0", "hub", "onHello failed: " Type(e) ": " e.Message)
            }
        }
    }

    _Deny(conn, msg, reason) {
        Log.Write("a0", "hub", "client denied: " reason)
        to := (Type(msg.payload.Get("name", "")) = "String" && msg.payload["name"] != "") ? msg.payload["name"] : "unknown"
        text := Message(to, Hub.SUPERVISOR, this._NextId(), "sys.welcome"
            , Map("ok", false, "error", Map("code", ErrCode.DENIED, "message", reason)), msg.id).Serialize()
        try {
            conn.SendFrame(text)
        } catch {
        }
        ; Close after the frame has had the chance to leave; the close itself is not an error.
        SetTimer(() => conn.Close(), -50)
    }

    _OnClose(conn, reason) {
        key := ObjPtr(conn)
        if (this._anon.Has(key)) {
            this._anon.Delete(key)
            return
        }
        name := this._byConn.Get(key, "")
        if (name = "")
            return
        link := this._links[name]
        this._Unlink(name)
        this._FailPending(name)
        Log.Write("a1", "hub", "client '" name "' gone (" reason ")")
        fn := this.onLinkLost
        if (IsObject(fn)) {
            try {
                fn(link, reason)
            } catch as e {
                Log.Write("a0", "hub", "onLinkLost failed: " Type(e) ": " e.Message)
            }
        }
    }

    _Unlink(name) {
        link := this._links[name]
        this._byConn.Delete(ObjPtr(link["conn"]))
        this._links.Delete(name)
    }

    ; --- routing -----------------------------------------------------------------------------

    _Route(link, msg) {
        ; The sender is the connection, not the message. A forged `from` is replaced here.
        msg := Message(msg.to, link["name"], msg.id, msg.type, msg.payload, msg.corr, msg.timeoutMs)
        to := msg.to
        if (to = Hub.SUPERVISOR) {
            this._Local(link, msg)
            return
        }
        if (SubStr(to, 1, 6) = "topic:") {
            this._Fanout(SubStr(to, 7), msg.Serialize(), link["name"])
            return
        }
        if (to = "*") {
            this._Refuse(link, msg, ErrCode.DENIED, "'*' is reserved for the supervisor")
            return
        }
        target := this._links.Get(to, "")
        if (target = "") {
            this._Refuse(link, msg, ErrCode.NOT_FOUND, "no peer '" to "'")
            return
        }
        try {
            text := msg.Serialize()
            sent := this._SendFrame(target, text)
        } catch as e {
            this._Refuse(link, msg, ErrCode.BAD_PAYLOAD, "message cannot be forwarded: " e.Message)
            return
        }
        if (!sent)
            this._Refuse(link, msg, ErrCode.PEER_GONE, "'" to "' does not accept the message")
    }

    _Local(link, msg) {
        if (SubStr(msg.type, 1, 4) = "res.") {
            this._Answer(msg)
            return
        }
        result := this._dispatcher.Invoke(msg)
        if (SubStr(msg.type, 1, 4) = "cmd.")
            this._Reply(link, msg.type, msg.id, result)
        else if (!result["ok"])
            Log.Write("a1", "hub", "no handler for " msg.type " from " link["name"] ": " result["error"]["message"])
    }

    ; Answers a request that came from a client (cmd.* to the supervisor or unroutable target).
    _Reply(link, reqType, reqId, payload) {
        if (!IsObject(link))
            return
        resType := "res." SubStr(reqType, 5)
        this._SendFrame(link, Message(link["name"], Hub.SUPERVISOR, this._NextId(), resType, payload, reqId).Serialize())
    }

    _Refuse(link, msg, code, text) {
        if (SubStr(msg.type, 1, 4) = "cmd.")
            this._Reply(link, msg.type, msg.id, Map("ok", false, "error", Map("code", code, "message", text)))
        else
            Log.Write("a1", "hub", "message " msg.type " from " link["name"] " dropped: " text)
    }

    _Answer(msg) {
        if (msg.corr = "" || !this._pending.Has(msg.corr)) {
            this.droppedAnswers += 1
            Log.Write("a1", "hub", "late or unknown answer " msg.type " dropped (" this.droppedAnswers " so far)")
            return
        }
        this._Finish(msg.corr, msg)
    }

    ; The deadline of a request passed: the callback gets the synthetic answer, a real one comes later and is dropped.
    _OnTimeout(id) {
        if (!this._pending.Has(id))
            return
        rec := this._pending[id]
        Log.Write("a1", "hub", "request " rec["type"] " to '" rec["to"] "' timed out, no answer")
        text := "no answer from '" rec["to"] "' within the request timeout"
        this._Finish(id, Message(Hub.SUPERVISOR, rec["to"], id, "res." SubStr(rec["type"], 5)
            , Map("ok", false, "error", Map("code", ErrCode.TIMEOUT, "message", text)), id))
    }

    ; Removes a request, stops its timer and calls its callback once. Returns false if it was not pending.
    _Finish(id, answer) {
        if (!this._pending.Has(id))
            return false
        rec := this._pending[id]
        this._pending.Delete(id)
        if (IsObject(rec["timerFn"]))
            SetTimer(rec["timerFn"], 0)
        this._CallBack(rec["cb"], answer)
        return true
    }

    _CallBack(cb, answer) {
        if (!IsObject(cb))
            return
        try {
            cb(answer)
        } catch as e {
            Log.Write("a0", "hub", "callback failed: " Type(e) ": " e.Message)
        }
    }

    _FailPending(name) {
        pendingIds := []
        for id, rec in this._pending
            if (rec["to"] = name)
                pendingIds.Push(id)
        for id in pendingIds
            this._Finish(id, "")
    }

    ; Sends text to every client subscribed to topic except `except` (the sender of an event).
    _Fanout(topic, text, except) {
        for name, link in this._links.Clone() {
            if (name != except && link["topics"].Has(topic))
                this._SendFrame(link, text)
        }
    }

    _SetTopic(msg) {
        topic := msg.payload.Get("topic", "")
        if (Type(topic) != "String" || topic = "")
            throw AhfError("missing topic", ErrCode.BAD_PAYLOAD)
        link := this._links.Get(msg.from, "")
        if (link = "")
            throw AhfError("sender is not connected", ErrCode.PEER_GONE)
        if (msg.type = "cmd.topic.subscribe")
            link["topics"][topic] := true
        else
            link["topics"].Delete(topic)
        return Map()
    }

    _SendFrame(link, text) {
        return link["conn"].SendFrame(text)
    }

    _NextId() {
        return Ids.Next(Hub.SUPERVISOR "#")
    }

    static _InList(value, list) {
        for item in list
            if (item = value)
                return true
        return false
    }
}
