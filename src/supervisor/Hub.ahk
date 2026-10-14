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

; The hub of the star topology (doc/ARCHITECTURE.md D6, doc/PROTOCOL.md 1, 2, 3, 5).
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
; answer {ok:false, error:{code:"timeout"}} when timeoutMs has passed (checked by Tick, moved by Shift), or "" when the
; link is lost first.
; A real answer that comes after the timeout is dropped and counted in droppedAnswers (Peer does the same).
; Requests between clients (F-40, WI-34): the hub remembers every cmd.* it forwards (head fields only: sender, id,
; type, target) until the answer passes back, or until the deadline of the request (timeoutMs) plus ROUTED_SLACK_MS.
; When the connection of the target ends (the process died, its pipe broke, its queue overflowed, it reconnected),
; every request it has not answered gets the answer {ok:false, error:{code:"peer_gone"}} from the hub at once. The
; connection is read to its end before that, so an answer the target wrote before it died arrives first and is not
; followed by a second one. Without this the sender waited for its own deadline (30 s for a storage read).
class Hub {
    static PROTOCOL := 1
    static SUPERVISOR := "supervisor"
    ; Default deadline of Request. Every request has one: nothing waits without a time limit.
    static DEFAULT_REQUEST_TIMEOUT_MS := 5000
    ; A pipe connection has this long to say sys.hello, then it is closed.
    static HELLO_TIMEOUT_MS := 5000
    ; Accepts per Pump, so a flood of new clients cannot keep the message loop busy.
    static ACCEPTS_PER_PUMP := 64
    ; A forwarded request is forgotten this long after its own deadline (the sender has given up by then; the slack
    ; covers the tick of the hub and a sender whose clock runs a little behind). A request without timeoutMs is kept
    ; for ROUTED_DEFAULT_MS, the longest standard deadline of the protocol (storage operations, PROTOCOL 2).
    static ROUTED_SLACK_MS := 1000
    static ROUTED_DEFAULT_MS := 30000
    ; evt.log.append is droppable (F-275): above this many frames in the send queue to the target the hub drops it
    ; and counts it per target (link["logDropped"]), so a log burst never drives the queue into the hard limit
    ; (PipeConnection.maxQueueFrames, 1000), which would close the link. Other message types are never dropped here.
    static LOG_SOFT_LIMIT := 800

    onHello := ""
    onLinkLost := ""
    session := ""
    Listener := ""
    ; Answers that arrived after their request had timed out or ended (or with an unknown corr).
    droppedAnswers := 0
    ; The newest events of the topic "process" (PROCESS_EVENTS_KEEP), for the snapshot and the crash report.
    static PROCESS_EVENTS_KEEP := 50

    __New(pipeName, session) {
        this.pipeName := pipeName
        this.session := session
        this._anon := Map()       ; ObjPtr(conn) -> Map("conn", conn, "since", ms)
        this._links := Map()      ; name -> link Map (see _Link)
        this._byConn := Map()     ; ObjPtr(conn) -> name
        this._pending := Map()    ; request id -> Map("to", name, "type", msgType, "cb", fn, "dueAt", ms)
        ; forwarded requests between clients (F-40): sender "`n" id -> Map("from", .., "to", .., "type", .., "id", .., "dueAt", ms)
        this._routed := Map()
        this.goneAnswers := 0     ; requests answered with peer_gone because their target went away
        this._dispatcher := Dispatcher()
        this._dispatcher.On("cmd.topic.", (msg) => this._SetTopic(msg))
        this._pumpFn := () => this.Pump()
        this._processEvents := []
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

    ; The deadlines of the hub, called by the supervisor's timer (WI-33): closes connections that have not said
    ; sys.hello in time, and ends the requests whose time limit has passed (the callback gets the synthetic timeout
    ; answer). The deadlines are a list that this tick looks at, not one SetTimer per request: a stand-still of the
    ; supervisor moves them all (Shift) before this tick runs. A SetTimer that came due during the stand-still could
    ; run before the tick that notices the stand-still. The accuracy is one tick (200 ms).
    Tick(now) {
        for key, rec in this._anon.Clone() {
            if (now - rec["since"] >= Hub.HELLO_TIMEOUT_MS) {
                Log.Write("a1", "hub", "connection closed: no sys.hello within " Hub.HELLO_TIMEOUT_MS " ms")
                rec["conn"].Close()
            }
        }
        for name, link in this._links
            if (link.Get("logDropped", 0) > 0)
                this._ReportLogDrops(link)
        due := []
        for id, rec in this._pending
            if (now >= rec["dueAt"])
                due.Push(id)
        for id in due
            this._OnTimeout(id)
        ; Forwarded requests past their deadline: the sender has its own timeout answer, the hub only forgets them.
        expired := []
        for key, rec in this._routed
            if (now >= rec["dueAt"])
                expired.Push(key)
        for key in expired
            this._routed.Delete(key)
    }

    ; The supervisor stood still for ms (Stall): every deadline of the hub moves by that time, so the rest of the time
    ; is kept (WI-33, F-16): the hello time of the new connections and the time limit of the open requests.
    Shift(ms) {
        for _, rec in this._anon
            rec["since"] += ms
        for _, rec in this._pending
            rec["dueAt"] += ms
        for _, rec in this._routed
            rec["dueAt"] += ms
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
        ; A refused frame is removed again at once.
        this._pending[id] := Map("to", name, "type", msgType, "cb", cb, "dueAt", Time.NowMs() + timeoutMs)
        if (!this._SendFrame(link, Message(name, Hub.SUPERVISOR, id, msgType, payload, "", timeoutMs).Serialize())) {
            this._pending.Delete(id)
            SetTimer(() => this._CallBack(cb, ""), -1)
            return id
        }
        return id
    }

    ; Publishes an event to every client subscribed to topic (from "supervisor").
    Publish(topic, msgType, payload := "") {
        text := Message("topic:" topic, Hub.SUPERVISOR, this._NextId(), msgType, payload).Serialize()
        this._Fanout(topic, text, "")
        if (topic = "process") {
            this._processEvents.Push(Map("ts", FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss"), "type", msgType
                , "payload", IsObject(payload) ? payload : Map()))
            while (this._processEvents.Length > Hub.PROCESS_EVENTS_KEEP)
                this._processEvents.RemoveAt(1)
        }
    }

    ; The newest events of the topic "process" (copies of the list, oldest first).
    ProcessEvents() => this._processEvents.Clone()

    ; Connections for the snapshot (doc/PROTOCOL.md 4.9): per client the pid, the send queue and the topics.
    Stats() {
        links := []
        for name, link in this._links {
            topics := []
            for topic, _ in link["topics"]
                topics.Push(topic)
            links.Push(Map("name", name, "pid", link["pid"], "queuedFrames", link["conn"].QueuedFrames
                , "queuedBytes", link["conn"].QueuedBytes, "topics", topics))
        }
        return Map("links", links, "droppedAnswers", this.droppedAnswers, "pending", this._pending.Count
            , "routedOpen", this._routed.Count, "goneAnswers", this.goneAnswers)
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
        ; Frames in the canonical form of Message.Serialize are routed by their head fields only: the payload is
        ; neither parsed nor built again (a 93 KB flow cost 220 ms as a full Message, WI-24). Messages to the
        ; supervisor and everything not in canonical form (white space, other order, ...) take the full way.
        if (name != "") {
            head := Message.ParseHead(text)
            if (IsObject(head) && head["to"] != Hub.SUPERVISOR) {
                this._RouteHead(this._links[name], head, text)
                return
            }
        }
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
            ; A reconnect may arrive before the old connection is noticed as lost. The new one wins. What was sent to
            ; the old connection and not answered is lost with it (its unread frames are dropped by Close).
            old := this._links[name]
            Log.Write("a1", "hub", "client '" name "' reconnected, old connection replaced")
            this._Unlink(name)
            this._FailPending(name)
            this._FailRouted(name, "reconnected")
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
            ; the client is denied anyway and closed below, a failed courtesy frame is of no use
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
        this._FailRouted(name, reason)
        this._ForgetRoutedFrom(name)
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
        if (msg.type = "evt.log.append" && this._DropLog(target))
            return
        try {
            text := msg.Serialize()
            sent := this._SendFrame(target, text)
        } catch as e {
            this._Refuse(link, msg, ErrCode.BAD_PAYLOAD, "message cannot be forwarded: " e.Message)
            return
        }
        if (!sent) {
            this._Refuse(link, msg, ErrCode.PEER_GONE, "'" to "' does not accept the message")
            return
        }
        this._NoteRouted(link["name"], to, msg.type, msg.id, msg.corr, msg.timeoutMs)
    }

    ; True when an evt.log.append for this target is to be dropped (queue above LOG_SOFT_LIMIT); the drop is counted.
    ; Otherwise reports earlier drops, if any, and returns false.
    _DropLog(target) {
        if (target["conn"].QueuedFrames >= Hub.LOG_SOFT_LIMIT) {
            target["logDropped"] := target.Get("logDropped", 0) + 1
            return true
        }
        this._ReportLogDrops(target)
        return false
    }

    ; One line "n log lines dropped" per target when its queue has room again (called when a log message passes
    ; and from Tick). The line goes through the log sink like every hub line.
    _ReportLogDrops(target) {
        n := target.Get("logDropped", 0)
        if (n = 0 || target["conn"].QueuedFrames >= Hub.LOG_SOFT_LIMIT)
            return
        target["logDropped"] := 0
        Log.Write("a1", "hub", n " log lines dropped (send queue to '" target["name"] "' was full)")
    }

    ; The fast way of _Route: the sender is set in the head, the payload text is passed on as it came.
    ; The hub does not look into the payload: an invalid one is refused by the receiver (Peer._RejectFrame).
    _RouteHead(link, head, text) {
        to := head["to"]
        out := Message.WithFrom(text, head, link["name"])
        if (SubStr(to, 1, 6) = "topic:") {
            this._Fanout(SubStr(to, 7), out, link["name"])
            return
        }
        ; Only the head is needed to refuse a command, so the stand-in has no payload.
        stub := Message(to, link["name"], head["id"], head["type"], "", head["corr"], head["timeoutMs"])
        if (to = "*") {
            this._Refuse(link, stub, ErrCode.DENIED, "'*' is reserved for the supervisor")
            return
        }
        target := this._links.Get(to, "")
        if (target = "") {
            this._Refuse(link, stub, ErrCode.NOT_FOUND, "no peer '" to "'")
            return
        }
        if (head["type"] = "evt.log.append" && this._DropLog(target))
            return
        if (!this._SendFrame(target, out)) {
            this._Refuse(link, stub, ErrCode.PEER_GONE, "'" to "' does not accept the message")
            return
        }
        this._NoteRouted(link["name"], to, head["type"], head["id"], head["corr"], head["timeoutMs"])
    }

    ; --- requests between clients (F-40, WI-34) --------------------------------------------------

    ; A message from `from` was forwarded to `to`. A cmd.* is remembered until its answer passes back; a res.* that
    ; passes back ends the request it answers (only when it comes from the target of that request).
    _NoteRouted(from, to, msgType, id, corr, timeoutMs) {
        kind := SubStr(msgType, 1, 4)
        if (kind = "cmd.") {
            limit := (IsInteger(timeoutMs) && timeoutMs > 0) ? Integer(timeoutMs) : Hub.ROUTED_DEFAULT_MS
            this._routed[from "`n" id] := Map("from", from, "to", to, "type", msgType, "id", id
                , "dueAt", Time.NowMs() + limit + Hub.ROUTED_SLACK_MS)
        } else if (kind = "res." && corr != "") {
            key := to "`n" corr
            rec := this._routed.Get(key, "")
            if (IsObject(rec) && rec["to"] = from)
                this._routed.Delete(key)
        }
    }

    ; The connection of name has ended (it was read to its end): every request it has not answered gets peer_gone,
    ; sent by the hub to its sender, if the sender is still connected.
    _FailRouted(name, reason) {
        keys := []
        for key, rec in this._routed
            if (rec["to"] = name)
                keys.Push(key)
        if (keys.Length = 0)
            return
        for key in keys {
            rec := this._routed[key]
            this._routed.Delete(key)
            this.goneAnswers += 1
            sender := this._links.Get(rec["from"], "")
            if (IsObject(sender))
                this._Reply(sender, rec["type"], rec["id"], Map("ok", false, "error", Map("code", ErrCode.PEER_GONE
                    , "message", "'" name "' is gone (" reason ") before it answered " rec["type"])))
        }
        Log.Write("a1", "hub", keys.Length " open request(s) to '" name "' answered with peer_gone")
    }

    ; The sender has gone: nobody waits for the answers of its requests any more.
    _ForgetRoutedFrom(name) {
        keys := []
        for key, rec in this._routed
            if (rec["from"] = name)
                keys.Push(key)
        for key in keys
            this._routed.Delete(key)
    }

    _Local(link, msg) {
        if (SubStr(msg.type, 1, 4) = "res.") {
            this._Answer(msg)
            return
        }
        result := this._dispatcher.Invoke(msg)
        ; The handler answers later with Reply (WI-28: the crash report waits for the snapshots of the roles).
        if (result is Deferred)
            return
        if (SubStr(msg.type, 1, 4) = "cmd.")
            this._Reply(link, msg.type, msg.id, result)
        else if (!result["ok"])
            Log.Write("a1", "hub", "no handler for " msg.type " from " link["name"] ": " result["error"]["message"])
    }

    ; The late answer to a cmd.* request whose handler returned Deferred.Marker(). Returns false when the
    ; sender is not connected any more. payload is a Map, "ok" is added by the caller or Message.Serialize.
    Reply(request, payload) {
        link := this._links.Get(request.from, "")
        if (!IsObject(link))
            return false
        if (!payload.Has("ok"))
            payload["ok"] := true
        this._Reply(link, request.type, request.id, payload)
        return true
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

    ; Removes a request and calls its callback once. Returns false if it was not pending.
    _Finish(id, answer) {
        if (!this._pending.Has(id))
            return false
        rec := this._pending[id]
        this._pending.Delete(id)
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
