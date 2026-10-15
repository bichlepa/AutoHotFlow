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
#Include ReportFiles.ahk

; Storage role (WI-0012, ARCHITECTURE D0007 and 4, PROTOCOL 4.6). The only process that touches files
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
    ; Log queue (WI-0025): limit and bundle size. The limit is lowered by --log-queue-max-lines (tests).
    static LOG_QUEUE_MAX_LINES := 20000
    static LOG_QUEUE_MAX_CHARS := 8 * 1024 * 1024
    static LOG_BUNDLE_MAX_LINES := 500
    static LOG_BUNDLE_MAX_CHARS := 64 * 1024
    ; At most this many lost lines of one bundle are listed one by one in the own log.
    static LOG_LOST_REPORT_MAX := 5
    static SelfLogFn := (level, source, text, flowId := "") => Role.Current._SelfLog(level, source, text, flowId)

    __New(args) {
        super.__New(args)
        this.queue := WriteQueue()
        this._shutdownUntil := 0
        this.logLinesLost := 0   ; log lines that could not be written even after the retries (F-0004)
        this.logBuffers := Map()           ; file name -> Map(items, scheduled): lines waiting for the file
        this.logQueuedEntries := 0         ; entries not yet written to all their files
        this.logQueuedChars := 0
        this.logLinesDropped := 0          ; entries dropped because the log queue was full (WI-0025)
        this.logDropPending := 0           ; dropped entries not yet announced in the log
        this.logQueueMaxLines := Integer(args.Get("log-queue-max-lines", Storage.LOG_QUEUE_MAX_LINES))
        this.logQueueMaxChars := Integer(args.Get("log-queue-max-chars", Storage.LOG_QUEUE_MAX_CHARS))
    }

    ; Creates the folders before the connection starts. A failure is logged to the console; the
    ; operations then fail with their own error and the role keeps running.
    Start() {
        this._EnsureFolders()
        super.Start()
        this._QueueTempCleanup()
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
        this.On("cmd.storage.report.write", (msg) => this._CmdReportWrite(msg))
        this.On("evt.log.append", (msg) => this._EvtLogAppend(msg))
    }

    ; Role part of the snapshot (doc/PROTOCOL.md 4.9): queue lengths and the log counters. No file names, no content.
    DiagInfo() {
        return Map("queue", Map("requests", this.queue.RequestCount, "log", this.queue.LogCount)
            , "logQueuedEntries", this.logQueuedEntries, "logQueuedChars", this.logQueuedChars
            , "logLinesLost", this.logLinesLost, "logLinesDropped", this.logLinesDropped)
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

    ; cmd.storage.report.write (WI-0028, PROTOCOL 4.9): only the supervisor builds reports. The contents are checked
    ; again by ReportFiles (names), the write runs in the request queue like every other file operation.
    _CmdReportWrite(msg) {
        if (msg.from != "supervisor")
            throw AhfError("cmd.storage.report.write is reserved for the supervisor, not for '" msg.from "'", ErrCode.DENIED)
        p := msg.payload
        stamp := p.Get("stamp", "")
        reason := p.Get("reason", "")
        files := p.Get("files", "")
        return this._Defer(msg, "report.write", reason
            , () => ReportFiles.Write(this.dataDir, stamp, reason, files))
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
    ; Never blocks and never has a deadline. The log queue is limited (logQueueMaxLines entries or
    ; logQueueMaxChars characters): over the limit the entry is dropped and counted, and a line
    ; "<n> log lines dropped" is written as soon as there is room again.
    _EnqueueLog(ts, level, source, thread, text, flowId) {
        if (this.logQueuedEntries >= this.logQueueMaxLines || this.logQueuedChars >= this.logQueueMaxChars) {
            if (this.logDropPending = 0)
                Role.Console("a0", "storage", "log queue full (" this.logQueuedEntries " entries), dropping new log lines")
            this.logDropPending += 1
            this.logLinesDropped += 1
            return
        }
        this._WriteDropNote()
        this._EnqueueLogEntry(ts, level, source, thread, text, flowId)
    }

    ; Writes the note for dropped lines (called when the queue has room).
    _WriteDropNote() {
        if (this.logDropPending = 0)
            return
        count := this.logDropPending
        this.logDropPending := 0
        this._EnqueueLogEntry(FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss"), "a0", "storage", "storage"
            , count " log lines dropped (log queue was full, " this.logLinesDropped " in total)", "")
    }

    _EnqueueLogEntry(ts, level, source, thread, text, flowId) {
        entry := Map("ts", ts, "level", level, "source", source, "text", text)
        if (flowId != "")
            entry["flowId"] := flowId
        line := LogSink.Line(LogSink.LocalStamp(ts), thread, source, text)
        names := LogSink.FileNames(source)
        ; The record lives until all files of the entry are written ("left" counts them).
        rec := Map("entry", entry, "line", line, "left", names.Length, "chars", StrLen(line))
        this.logQueuedEntries += 1
        this.logQueuedChars += rec["chars"]
        for index, fileName in names
            this._LogToFile(fileName, Map("rec", rec, "last", index = names.Length))
    }

    ; Adds the item to the pending lines of the file. One queue operation per file at a time writes the
    ; pending lines in one go (a bundle), so a file is opened once per bundle, not once per line.
    _LogToFile(fileName, item) {
        if (!this.logBuffers.Has(fileName))
            this.logBuffers[fileName] := Map("items", [], "scheduled", false)
        buf := this.logBuffers[fileName]
        buf["items"].Push(item)
        if (!buf["scheduled"]) {
            buf["scheduled"] := true
            this.queue.AddLow(this._LogFileOp(fileName, buf))
        }
    }

    ; A separate method, so each closure has its own parameters (loop variables are shared by closures).
    ; state["n"] is the number of lines the last run tried to write. The lines stay in the buffer until
    ; the write worked, so a retry keeps the order and lines that arrive meanwhile join the next bundle.
    _LogFileOp(fileName, buf) {
        state := Map("n", 0)
        logDir := StoragePaths.LogDir(this.dataDir)
        return Map("deadline", "", "retryMs", Storage.LOG_RETRY_MS, "retryDelayMs", Storage.LOG_RETRY_DELAY_MS
            , "run", () => this._RunLogBundle(logDir, fileName, buf, state)
            , "finish", (payload) => this._FinishLogBundle(fileName, buf, state, payload))
    }

    ; Writes up to LOG_BUNDLE_MAX_LINES / LOG_BUNDLE_MAX_CHARS of the pending lines of one file.
    ; Returns the retry request of the queue while another process holds the file (F-0004).
    _RunLogBundle(logDir, fileName, buf, state) {
        text := ""
        n := 0
        for item in buf["items"] {
            line := item["rec"]["line"]
            if (n > 0 && (n >= Storage.LOG_BUNDLE_MAX_LINES || StrLen(text) + StrLen(line) > Storage.LOG_BUNDLE_MAX_CHARS))
                break
            text .= line
            n += 1
        }
        state["n"] := n
        busy := LogSink.AppendTo(logDir, fileName, text)
        if (busy != "")
            return Map("retry", true, "message", fileName ": " busy)
        return Map()
    }

    ; After the bundle (written or lost) every entry whose last file is done goes to the topic "log".
    ; Lines that could not be written are counted and reported in the own log, never dropped silently.
    ; A failure before the first run (FailAll at shutdown) loses all pending lines of the file.
    _FinishLogBundle(fileName, buf, state, payload) {
        items := buf["items"]
        n := state["n"]
        neverRan := (n = 0)
        if (neverRan)
            n := items.Length
        done := []
        loop n
            done.Push(items[A_Index])
        if (n > 0)
            items.RemoveAt(1, n)
        buf["scheduled"] := false
        reported := 0
        for item in done {
            rec := item["rec"]
            if (!payload["ok"]) {
                reported += 1
                if (reported <= Storage.LOG_LOST_REPORT_MAX)
                    this._LogLineLost(rec["entry"], fileName, payload["error"]["message"])
                else
                    this.logLinesLost += 1
            }
            if (item["last"])
                this.peer.Send("topic:log", "evt.log.entry", rec["entry"])
            rec["left"] -= 1
            if (rec["left"] = 0) {
                this.logQueuedEntries -= 1
                this.logQueuedChars -= rec["chars"]
            }
        }
        if (reported > Storage.LOG_LOST_REPORT_MAX)
            this._SelfLog("a0", "storage", "log line lost: " fileName ", " (reported - Storage.LOG_LOST_REPORT_MAX)
                " more lines not listed, " this.logLinesLost " lost in total. " payload["error"]["message"])
        if (items.Length > 0 && !neverRan) {
            buf["scheduled"] := true
            this.queue.AddLow(this._LogFileOp(fileName, buf))
        } else if (items.Length = 0 && this.logBuffers.Get(fileName, "") == buf) {
            this.logBuffers.Delete(fileName)
        }
        ; announce dropped lines when the queue is at most half full again (also without new lines)
        if (this.logDropPending > 0 && this.logQueuedEntries * 2 <= this.logQueueMaxLines)
            this._WriteDropNote()
    }

    _LogLineLost(entry, fileName, message) {
        this.logLinesLost += 1
        Role.Console("a0", "storage", "log line lost (" this.logLinesLost " in total) in " fileName ": " message)
        if (SubStr(entry["text"], 1, 14) = "log line lost:")
            return   ; the report itself is not reported again
        this._SelfLog("a0", "storage", "log line lost: " fileName ", source '" entry["source"] "', text '"
            SubStr(entry["text"], 1, 80) "', " this.logLinesLost " lost in total. " message)
    }

    ; --- temp files left by a hard stop ---------------------------------------------------------

    ; Deletes stale "*.ahf-<pid>.tmp" files in Flows/ and Variables/ as the first log-priority
    ; operation, so the start of the role (sys.hello) and the first requests do not wait for the scan.
    _QueueTempCleanup() {
        this.queue.AddLow(Map("deadline", "", "run", () => this._RunTempCleanup()
            , "finish", (payload) => this._FinishTempCleanup(payload)))
    }

    _RunTempCleanup() {
        removed := AtomicFile.RemoveStaleTemps(StoragePaths.FlowsDir(this.dataDir))
        removed += AtomicFile.RemoveStaleTemps(StoragePaths.VarsDir(this.dataDir))
        return Map("removed", removed)
    }

    _FinishTempCleanup(payload) {
        if (!payload["ok"])
            this._Log("a0", "storage", "cleanup of stale temp files failed: " payload["error"]["message"])
        else if (payload["removed"] > 0)
            this._Log("a1", "storage", "removed " payload["removed"] " stale temp file(s) of stopped processes")
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
