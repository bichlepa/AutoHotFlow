#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\core\AhfVersion.ahk
#Include ReportText.ahk

; Crash and diagnostic reports of the supervisor (WI-0028, doc/PROTOCOL.md 4.9, ARCHITECTURE 6.2).
;
; A report asks every connected child for cmd.diag.snapshot (all at once, SNAPSHOT_MS per role), adds the own
; snapshot of the supervisor, builds report.json and summary.txt and hands them to "storage"
; (cmd.storage.report.write). The supervisor never writes a file. Nothing waits without a deadline:
;   - a role that does not answer within SNAPSHOT_MS is listed in "missing" ("no answer within ..."),
;   - the write has WRITE_TIMEOUT_MS,
;   - when storage is not connected, the finished report waits at most STORAGE_WAIT_MS for it.
; After that the caller gets "peer_gone"; the report stays in memory (at most KEEP_UNWRITTEN) and is written as
; soon as storage says sys.hello (OnStorageHello), under its original stamp.
;
; Automatic reports (Auto) come from the supervisor's own observations: a child that ended unexpectedly, the
; restart limit, a hung child, a burst of unhandled errors (NoteError). At most one per AUTO_MIN_INTERVAL_MS, none
; while the session ends. Manual reports (Request) are not limited.
;
;   report := DiagReport(hub, children, () => supervisor.Snapshot(), "main")
;   report.Request("manual", false, (payload) => hub.Reply(msg, payload))   ; payload: ok, path, ... or an error
;   report.Auto("crashed", "engine")
;   report.OnStorageHello()
;
; The hub needs: HasLink(name), LinkNames(), Request(name, type, payload, cb, timeoutMs).
; The children need: Names(), State(name), IsGone(name), shuttingDown.
class DiagReport {
    static SNAPSHOT_MS := 2000
    static WRITE_TIMEOUT_MS := 15000
    static STORAGE_WAIT_MS := 10000
    static AUTO_MIN_INTERVAL_MS := 60000
    static KEEP_UNWRITTEN := 5
    static ERROR_BURST := 10
    static ERROR_WINDOW_MS := 60000
    static REASON_MAX := 60
    static STORAGE := "storage"

    __New(hub, children, snapshotFn, session := "main") {
        this.hub := hub
        this.children := children
        this.snapshotFn := snapshotFn
        this.session := session
        this.snapshotMs := DiagReport.SNAPSHOT_MS
        this.storageWaitMs := DiagReport.STORAGE_WAIT_MS
        this.writeTimeoutMs := DiagReport.WRITE_TIMEOUT_MS
        this.autoMinMs := DiagReport.AUTO_MIN_INTERVAL_MS
        this.written := 0
        this.autoSuppressed := 0
        this._lastAutoMs := 0
        this._unwritten := []          ; finished jobs that wait for storage
        this._errorTimes := Map()      ; role name -> times (ms) of its unhandled errors
        this._seq := 0
    }

    Stats() => Map("written", this.written, "unwritten", this._unwritten.Length, "autoSuppressed", this.autoSuppressed)

    ; reason: free text (letters, digits . _ - are kept, the rest becomes "-"), at most REASON_MAX characters.
    static SafeReason(text) {
        text := RegExReplace(String(text), "[^A-Za-z0-9._-]", "-")
        text := SubStr(text, 1, DiagReport.REASON_MAX)
        return (text = "") ? "report" : text
    }

    ; --- starting a report -------------------------------------------------------------------

    ; Starts a report. onDone(payload) is called exactly once with the answer payload (ok, path, ... or an error), also
    ; when storage never comes. Returns the job (a Map), for the tests.
    Request(reason, auto := false, onDone := "") {
        this._seq += 1
        job := Map("id", this._seq, "reason", DiagReport.SafeReason(reason), "auto", auto ? true : false  ; arch-ok: wire-bool internal job record, never sent
            , "stamp", FormatTime(A_Now, "yyyyMMdd-HHmmss"), "createdAt", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
            , "snapshots", Map(), "missing", [], "open", 0, "onDone", onDone, "files", "", "state", "collecting"
            , "waitFn", "", "waitDueAt", 0)
        Log.Write("a1", "report", "report '" job["reason"] "' started" (auto ? " (automatic)" : ""))
        asked := 0
        for name in this.children.Names() {
            if (this.hub.HasLink(name)) {
                asked += 1
                job["open"] += 1
                this.hub.Request(name, "cmd.diag.snapshot", Map(), ObjBindMethod(this, "_OnSnapshot", job, name)
                    , this.snapshotMs)
            } else {
                state := this.children.State(name)
                if (state != "exited")
                    job["missing"].Push(Map("name", name, "why", "not connected (" state ")"))
            }
        }
        if (asked = 0)
            SetTimer(ObjBindMethod(this, "_Assemble", job), -1)
        return job
    }

    ; An automatic report for an incident (kind "crashed", "restart-limit", "hung", "errors"; name of the child).
    ; Returns true when a report was started, false when it was suppressed (rate limit, shutdown).
    Auto(kind, name) {
        if (this.children.shuttingDown)
            return false
        now := Time.NowMs()
        if (this._lastAutoMs > 0 && now - this._lastAutoMs < this.autoMinMs) {
            this.autoSuppressed += 1
            Log.Write("a1", "report", "automatic report '" kind "-" name "' suppressed (rate limit, "
                . this.autoSuppressed " so far)")
            return false
        }
        this._lastAutoMs := now
        this.Request(kind "-" name, true)
        return true
    }

    ; An unhandled error of a role (evt.diag.error). ERROR_BURST of them within ERROR_WINDOW_MS start an automatic report.
    NoteError(from) {
        now := Time.NowMs()
        if (!this._errorTimes.Has(from))
            this._errorTimes[from] := []
        times := this._errorTimes[from]
        times.Push(now)
        while (times.Length && now - times[1] > DiagReport.ERROR_WINDOW_MS)
            times.RemoveAt(1)
        if (times.Length >= DiagReport.ERROR_BURST) {
            this._errorTimes[from] := []
            return this.Auto("errors", from)
        }
        return false
    }

    ; --- collecting ----------------------------------------------------------------------------

    _OnSnapshot(job, name, answer) {
        if (!IsObject(answer)) {
            job["missing"].Push(Map("name", name, "why", "connection lost before the answer"))
        } else if (answer.payload.Get("ok", false) && answer.payload.Get("snapshot", "") is Map) {
            job["snapshots"][name] := answer.payload["snapshot"]
        } else {
            err := answer.payload.Get("error", "")
            code := (err is Map) ? err.Get("code", "error") : "error"
            job["missing"].Push(Map("name", name, "why", (code = ErrCode.TIMEOUT)
                ? "no answer within " this.snapshotMs " ms" : "error: " code))
        }
        job["open"] -= 1
        if (job["open"] <= 0 && job["state"] = "collecting")
            this._Assemble(job)
    }

    ; All answers (or deadlines) are in: add the own snapshot and build the two files.
    _Assemble(job) {
        if (job["state"] != "collecting")
            return
        job["state"] := "building"
        try {
            job["snapshots"]["supervisor"] := this.snapshotFn.Call()
            meta := Map("reason", job["reason"], "auto", Json.Bool(job["auto"]), "createdAt", job["createdAt"]
                , "session", this.session, "version", AhfVersion.Current, "ahkVersion", A_AhkVersion)
            report := Map("meta", meta, "snapshots", job["snapshots"], "missing", job["missing"])
            files := Map("report.json", Json.Stringify(report, 2)
                , "summary.txt", ReportText.Build(meta, job["snapshots"], job["missing"]))
            job["files"] := files
        } catch as e {
            Log.Write("a0", "report", "report '" job["reason"] "' could not be built: " Type(e) ": " e.Message)
            this._Done(job, Map("ok", false, "error", Map("code", ErrCode.INTERNAL, "message", "report not built: " e.Message)))
            return
        }
        this._Deliver(job)
    }

    ; --- delivery to storage ---------------------------------------------------------------------

    _Deliver(job) {
        if (!this.hub.HasLink(DiagReport.STORAGE)) {
            this._Park(job)
            return
        }
        job["state"] := "writing"
        payload := Map("stamp", job["stamp"], "reason", job["reason"], "files", job["files"])
        this.hub.Request(DiagReport.STORAGE, "cmd.storage.report.write", payload
            , ObjBindMethod(this, "_OnWritten", job), this.writeTimeoutMs)
    }

    _OnWritten(job, answer) {
        if (!IsObject(answer) || (answer.payload.Get("error", "") is Map && answer.payload["error"].Get("code", "") = ErrCode.PEER_GONE)) {
            this._Park(job)
            return
        }
        if (answer.payload.Get("ok", false)) {
            this.written += 1
            result := Map("ok", true, "path", answer.payload.Get("path", ""), "dir", answer.payload.Get("dir", "")
                , "roles", job["snapshots"].Count, "missing", job["missing"])
            Log.Write("a1", "report", "report written to " result["path"] " (" result["roles"] " role(s), "
                . job["missing"].Length " missing)")
            this._Done(job, result)
            return
        }
        err := answer.payload.Get("error", "")
        code := (err is Map) ? err.Get("code", ErrCode.INTERNAL) : ErrCode.INTERNAL
        text := (err is Map) ? err.Get("message", "") : "no details"
        Log.Write("a0", "report", "storage did not write report '" job["reason"] "': " code ": " text)
        this._Done(job, Map("ok", false, "error", Map("code", code, "message", "report not written: " text)))
    }

    ; Storage is away: the finished report waits for it in memory. The caller is answered after STORAGE_WAIT_MS at
    ; the latest; the report stays in the list until it is written or pushed out by newer ones.
    _Park(job) {
        job["state"] := "waiting"
        this._unwritten.Push(job)
        while (this._unwritten.Length > DiagReport.KEEP_UNWRITTEN) {
            old := this._unwritten.RemoveAt(1)
            if (IsObject(old["waitFn"]))
                SetTimer(old["waitFn"], 0)
            Log.Write("a0", "report", "report '" old["reason"] "' dropped: storage was not available for too long")
            this._Done(old, Map("ok", false, "error", Map("code", ErrCode.PEER_GONE
                , "message", "storage not available, the report was dropped")))
        }
        if (IsObject(job["onDone"])) {
            job["waitFn"] := ObjBindMethod(this, "_OnStorageWaitOver", job)
            job["waitDueAt"] := Time.NowMs() + this.storageWaitMs
            SetTimer(job["waitFn"], -this.storageWaitMs)
        }
        Log.Write("a0", "report", "report '" job["reason"] "' waits for storage (" this._unwritten.Length " waiting)")
    }

    ; The supervisor stood still for ms (Stall, WI-0033, F-0016): the wait for storage keeps its rest of the time. The timer
    ; is set again for the new time. A timer that came due during the stand-still and ran before the tick that noticed
    ; it only answers the caller early ("kept and written when storage is back"); the report itself is not lost.
    Shift(now, ms) {
        for job in this._unwritten {
            if (IsObject(job["waitFn"])) {
                job["waitDueAt"] += ms
                SetTimer(job["waitFn"], -Max(1, Integer(job["waitDueAt"] - now)))
            }
        }
    }

    _OnStorageWaitOver(job) {
        job["waitFn"] := ""
        this._Done(job, Map("ok", false, "error", Map("code", ErrCode.PEER_GONE
            , "message", "storage not available, the report is kept and written when storage is back")))
    }

    ; storage said sys.hello: write what waits, oldest first, under the original stamps.
    OnStorageHello() {
        waiting := this._unwritten
        this._unwritten := []
        for job in waiting {
            if (IsObject(job["waitFn"])) {
                SetTimer(job["waitFn"], 0)
                job["waitFn"] := ""
            }
            this._Deliver(job)
        }
    }

    ; Calls onDone once.
    _Done(job, payload) {
        fn := job["onDone"]
        job["onDone"] := ""
        if (!IsObject(fn))
            return
        try {
            fn(payload)
        } catch as e {
            Log.Write("a0", "report", "answer of report '" job["reason"] "' failed: " Type(e) ": " e.Message)
        }
    }
}
