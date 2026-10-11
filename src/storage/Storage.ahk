#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Role.ahk
#Include ..\core\Time.ahk
#Include ..\core\ipc\Deferred.ahk
#Include WriteQueue.ahk
#Include StoragePaths.ahk
#Include AtomicFile.ahk
#Include FlowFiles.ahk
#Include VarFiles.ahk
#Include LogSink.ahk

; Storage role (WI-12, ARCHITECTURE D7 and 4, PROTOCOL 4.6). The only process that touches files
; under the data directory: flows, variables and logs. Requests are queued (WriteQueue) and answered
; when their operation has run, so a large write never stops the message pump.
;
; Layout under --data (v1 names where they exist): Flows/ (v1 "Saved Flows"), Flows/backup/,
; Variables/, Variables/<flowId>/, Log/.
;
; Errors: every failed request gets ok:false with error.code, and an evt.storage.error goes to the
; topic "engine" (PROTOCOL 4.3). Nothing shows a dialog. Shutdown: queued operations run until the
; deadline, then the rest is answered with shutting_down, then sys.bye (ARCHITECTURE 6.3).
class Storage extends Role {
    static DEFAULT_TIMEOUT_MS := 30000
    ; Time kept from the shutdown deadline for the last answers and the sys.bye.
    static SHUTDOWN_MARGIN_MS := 500
    ; A log file held by another process is retried for this long (per file and entry), every delay.
    static LOG_RETRY_MS := 3000
    static LOG_RETRY_DELAY_MS := 20
    ; Log sink of this process: its own entries go straight into the queue (no evt.log.append to itself).
    static SelfLogFn := (level, source, text, flowId := "") => Role.Current._SelfLog(level, source, text, flowId)

    __New(args) {
        super.__New(args)
        this.queue := WriteQueue()
        this._shutdownUntil := 0
        this.logLinesLost := 0   ; log lines that could not be written even after the retries (F-04)
    }

    ; Creates the folders before the connection starts. A failure is logged to the console; the
    ; operations then fail with their own error and the role keeps running.
    Start() {
        this._EnsureFolders()
        super.Start()
        Log.Configure(Storage.SelfLogFn)
    }

    RegisterHandlers() {
        this.On("cmd.storage.flows.list", (msg) => this._CmdFlowsList(msg))
        this.On("cmd.storage.flow.read", (msg) => this._CmdFlowRead(msg))
        this.On("cmd.storage.flow.write", (msg) => this._CmdFlowWrite(msg))
        this.On("cmd.storage.var.get", (msg) => this._CmdVarGet(msg))
        this.On("cmd.storage.var.set", (msg) => this._CmdVarSet(msg))
        this.On("cmd.storage.var.delete", (msg) => this._CmdVarDelete(msg))
        this.On("cmd.storage.var.list", (msg) => this._CmdVarList(msg))
        this.On("evt.log.append", (msg) => this._EvtLogAppend(msg))
    }

    ; sys.shutdown: the time to finish the queue is the deadline minus a margin.
    OnShutdown(deadlineMs) {
        this._shutdownUntil := Time.NowMs() + Max(deadlineMs - Storage.SHUTDOWN_MARGIN_MS, 0)
    }

    ; Replaces Role._FinishShutdown (called by the bye timer). Waits, in timer steps, while operations
    ; are queued and the time is not over. Then the rest is answered and the role says sys.bye.
    _FinishShutdown() {
        if (this.closing)
            return
        if (this.queue.Pending > 0 && Time.NowMs() < this._shutdownUntil) {
            SetTimer(Role.ByeFn, -20)
            return
        }
        this.queue.FailAll(ErrCode.SHUTTING_DOWN, "storage is stopping")
        super._FinishShutdown()
    }

    ; --- requests ----------------------------------------------------------------------------

    _CmdFlowsList(msg) {
        return this._Defer(msg, "flows.list", "", () => Map("files", FlowFiles.List(this.dataDir)))
    }

    _CmdFlowRead(msg) {
        flowPath := msg.payload.Get("path", "")
        return this._Defer(msg, "flow.read", flowPath
            , () => Map("text", FlowFiles.Read(this.dataDir, flowPath)))
    }

    _CmdFlowWrite(msg) {
        flowPath := msg.payload.Get("path", "")
        text := msg.payload.Get("text", "")
        backup := msg.payload.Get("backup", true)
        return this._Defer(msg, "flow.write", flowPath
            , () => this._RunFlowWrite(flowPath, text, backup))
    }

    _CmdVarGet(msg) {
        p := msg.payload
        scope := p.Get("scope", "global")
        flowId := p.Get("flowId", "")
        name := p.Get("name", "")
        return this._Defer(msg, "var.get", name, () => VarFiles.Get(this.dataDir, scope, flowId, name))
    }

    _CmdVarSet(msg) {
        p := msg.payload
        scope := p.Get("scope", "global")
        flowId := p.Get("flowId", "")
        name := p.Get("name", "")
        varType := p.Get("type", "normal")
        content := p.Get("content", "")
        return this._Defer(msg, "var.set", name
            , () => this._RunVarSet(scope, flowId, name, varType, content))
    }

    _CmdVarDelete(msg) {
        p := msg.payload
        scope := p.Get("scope", "global")
        flowId := p.Get("flowId", "")
        name := p.Get("name", "")
        return this._Defer(msg, "var.delete", name, () => VarFiles.Delete(this.dataDir, scope, flowId, name))
    }

    _CmdVarList(msg) {
        scope := msg.payload.Get("scope", "global")
        flowId := msg.payload.Get("flowId", "")
        return this._Defer(msg, "var.list", flowId, () => VarFiles.List(this.dataDir, scope, flowId))
    }

    ; evt.log.append (noReply): no answer. Invalid entries are reported to the console only.
    _EvtLogAppend(msg) {
        p := msg.payload
        if (!p.Has("text") || !p.Has("source")) {
            Role.Console("a0", "storage", "evt.log.append without source or text from " msg.from)
            return
        }
        this._EnqueueLog(p.Get("ts", ""), p.Get("level", "a1"), p.Get("source", ""), msg.from
            , p.Get("text", ""), p.Get("flowId", ""))
    }

    ; --- queueing and answers ----------------------------------------------------------------

    ; Queues one operation for the request and returns the marker: the answer comes later (Reply).
    _Defer(msg, opName, subject, run) {
        timeoutMs := (msg.timeoutMs > 0) ? msg.timeoutMs : Storage.DEFAULT_TIMEOUT_MS
        this.queue.Add(Map("deadline", Time.NowMs() + timeoutMs, "run", run
            , "finish", (payload) => this._Finish(msg, opName, subject, payload)))
        return Deferred.Marker()
    }

    ; Answers the request. A failure is also reported to the engine as evt.storage.error (PROTOCOL 4.3).
    _Finish(msg, opName, subject, payload) {
        this.peer.Reply(msg, payload)
        if (payload["ok"])
            return
        code := payload["error"]["code"]
        message := payload["error"]["message"]
        this._Log("a0", "storage", opName " '" subject "' failed (" code "): " message)
        this.peer.Send("topic:engine", "evt.storage.error"
            , Map("op", opName, "path", subject, "code", code, "message", message))
    }

    ; --- operations (run inside the queue, one at a time) ------------------------------------

    _RunFlowWrite(flowPath, text, backup) {
        FlowFiles.Write(this.dataDir, flowPath, text, backup)
        return Map()
    }

    _RunVarSet(scope, flowId, name, varType, content) {
        VarFiles.Set(this.dataDir, scope, flowId, name, varType, content)
        return Map()
    }

    ; --- log ---------------------------------------------------------------------------------

    _SelfLog(level, source, text, flowId := "") {
        this._EnqueueLog(FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss"), level, source, "storage", text, flowId)
    }

    ; Queues one log entry: written to the files, then forwarded to the topic "log" (PROTOCOL 4.6).
    ; The queue has no deadline for logs: a log line must not be dropped by a timeout.
    _EnqueueLog(ts, level, source, thread, text, flowId) {
        entry := Map("ts", ts, "level", level, "source", source, "text", text)
        if (flowId != "")
            entry["flowId"] := flowId
        logDir := StoragePaths.LogDir(this.dataDir)
        line := LogSink.Line(LogSink.LocalStamp(ts), thread, source, text)
        ; One operation per file, so a retry of one file never writes the other one twice. The queue
        ; keeps the order, a locked file holds back the entries behind it for at most LOG_RETRY_MS.
        names := LogSink.FileNames(source)
        for index, fileName in names
            this.queue.Add(this._LogOp(entry, logDir, fileName, line, index = names.Length))
    }

    ; A separate method, so each closure has its own parameters (loop variables are shared by closures).
    _LogOp(entry, logDir, fileName, line, isLast) {
        return Map("deadline", "", "retryMs", Storage.LOG_RETRY_MS, "retryDelayMs", Storage.LOG_RETRY_DELAY_MS
            , "run", () => this._RunLogAppend(logDir, fileName, line)
            , "finish", (payload) => this._FinishLog(entry, fileName, isLast, payload))
    }

    ; Returns the retry request of the queue while another process holds the file (F-04).
    _RunLogAppend(logDir, fileName, line) {
        busy := LogSink.AppendTo(logDir, fileName, line)
        if (busy != "")
            return Map("retry", true, "message", fileName ": " busy)
        return Map()
    }

    ; After the last file of an entry the entry goes to the topic "log". A line that could not be
    ; written is counted and reported in the own log, never dropped silently.
    _FinishLog(entry, fileName, last, payload) {
        if (!payload["ok"])
            this._LogLineLost(entry, fileName, payload["error"]["message"])
        if (last)
            this.peer.Send("topic:log", "evt.log.entry", entry)
    }

    _LogLineLost(entry, fileName, message) {
        this.logLinesLost += 1
        Role.Console("a0", "storage", "log line lost (" this.logLinesLost " in total) in " fileName ": " message)
        if (SubStr(entry["text"], 1, 14) = "log line lost:")
            return   ; the report itself is not reported again
        this._SelfLog("a0", "storage", "log line lost: " fileName ", source '" entry["source"] "', text '"
            SubStr(entry["text"], 1, 80) "', " this.logLinesLost " lost in total. " message)
    }

    ; --- folders -----------------------------------------------------------------------------

    _EnsureFolders() {
        for dirPath in [StoragePaths.FlowsDir(this.dataDir), StoragePaths.VarsDir(this.dataDir)
            , StoragePaths.LogDir(this.dataDir)] {
            try {
                DirCreate(dirPath)
            } catch as e {
                Role.Console("a0", "storage", "cannot create '" dirPath "': " Type(e) ": " e.Message)
            }
        }
    }
}
