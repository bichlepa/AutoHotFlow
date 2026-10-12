#Requires AutoHotkey v2.0
#Include ..\core\Json.ahk

; The readable summary (summary.txt) of a diagnostic report (WI-28, doc/PROTOKOLL.md 4.9). A pure function of the
; collected snapshots: no I/O, no messages. The full data is in report.json; this text is for the person who
; opens the folder first.
;
;   text := ReportText.Build(meta, snapshots, missing)
;     meta       Map: reason, auto (0/1), createdAt (local time text), session, version, ahkVersion
;     snapshots  Map: role name -> snapshot Map (PROTOKOLL 4.9), the supervisor under "supervisor"
;     missing    Array of Map(name, why): roles without a snapshot
class ReportText {
    static LOG_LINES := 20
    static ERROR_LINES := 15
    static OUTPUT_LINES := 10

    static Build(meta, snapshots, missing) {
        t := "AutoHotFlow diagnostic report`n"
        t .= "reason:   " meta["reason"] (ReportText._On(meta["auto"]) ? "  (automatic)" : "  (manual)") "`n"
        t .= "created:  " meta["createdAt"] " (local time)`n"
        t .= "session:  " meta["session"] "   version " meta["version"] "   AutoHotkey " meta["ahkVersion"] "`n"
        t .= "roles with a snapshot: " snapshots.Count "   without: " missing.Length "`n"
        sup := snapshots.Get("supervisor", "")
        if (IsObject(sup))
            t .= ReportText._Processes(sup)
        t .= "`n== Roles ==`n"
        for name, snap in snapshots
            t .= ReportText._Role(name, snap)
        if (missing.Length) {
            t .= "`n== Roles without a snapshot ==`n"
            for item in missing
                t .= "  " item["name"] ": " item["why"] "`n"
        }
        t .= ReportText._Errors(snapshots)
        if (IsObject(sup))
            t .= ReportText._Ended(sup) ReportText._Tail(sup)
        return t
    }

    static _Processes(sup) {
        t := "`n== Processes (supervisor, pid " sup["pid"] ") ==`n"
        t .= ReportText._Pad("name", 16) ReportText._Pad("role", 12) ReportText._Pad("state", 10) ReportText._Pad("pid", 8)
            . ReportText._Pad("exit", 6) "restarts`n"
        for c in sup["children"] {
            t .= ReportText._Pad(c["name"], 16) ReportText._Pad(c["role"], 12) ReportText._Pad(c["state"], 10)
                . ReportText._Pad(c["pid"], 8) ReportText._Pad(c["exitCode"], 6) c["restarts"] "`n"
        }
        return t
    }

    static _Role(name, snap) {
        mb := Round(snap["rssBytes"] / 1048576, 1)
        t := name "  (pid " snap["pid"] ", up " Round(snap["uptimeMs"] / 1000, 1) " s, " mb " MB, " snap["handles"] " handles)`n"
        if (snap.Has("peer") && snap["peer"].Count) {
            p := snap["peer"]
            t .= "  peer: " p["status"] ", pending " p["pending"] ", queued frames " p["queuedFrames"] ", late replies "
                . p["lateReplies"] ", bad frames " p["badFrames"] ", dropped sends " p["droppedSends"]
                . ", handler errors " p["handlerErrors"] "`n"
        }
        if (snap.Has("hub")) {
            t .= "  hub: " snap["hub"]["links"].Length " connection(s), " snap["hub"]["pending"] " pending request(s), "
                . snap["hub"]["droppedAnswers"] " dropped answer(s)`n"
        }
        t .= "  log: " snap["log"]["recent"].Length " recent entries, " snap["log"]["queued"] " queued, "
            . snap["log"]["dropped"] " dropped, " snap["log"]["sinkErrors"] " sink errors`n"
        t .= "  unhandled errors: " snap["errors"]["count"] "`n"
        if (snap.Has("info"))
            t .= ReportText._Info(snap["info"])
        return t
    }

    ; The most useful numbers of the role part. The full part is in report.json.
    static _Info(info) {
        t := ""
        if (info.Has("error"))
            return "  role part failed: " info["error"] "`n"
        if (info.Has("flows") && info.Has("instances")) {
            t .= "  flows " info["flows"].Length ", instances " info["instances"].Length ", seq " info["seq"] "`n"
            for inst in info["instances"] {
                t .= "    " inst["instanceId"] " of " inst["flowId"] " " inst["state"] ", threads:"
                for th in inst["threads"]
                    t .= " " th["threadId"] "=" th["elementId"] "/" th["state"]
                t .= "`n"
            }
        }
        if (info.Has("workers")) {
            w := info["workers"]
            t .= "  worker pool: size " w["size"] ", warm " w["warm"] ", spawning " w["spawning"] ", failures " w["failures"] ", slots:"
            for slot in w["slots"]
                t .= " " slot["name"] "=" slot["state"]
            t .= "`n"
        }
        if (info.Has("queue"))
            t .= "  queues: " info["queue"]["requests"] " request(s), " info["queue"]["log"] " log operation(s); log lines lost "
                . info["logLinesLost"] ", dropped " info["logLinesDropped"] "`n"
        if (info.Has("job") && IsObject(info["job"]))
            t .= "  job: " info["job"]["class"] " (" info["job"]["execId"] ") for " info["job"]["sinceMs"] " ms`n"
        if (info.Has("topics"))
            t .= "  topics: " ReportText._Join(info["topics"]) "`n"
        return t
    }

    static _Errors(snapshots) {
        lines := []
        for name, snap in snapshots {
            for e in snap["errors"]["recent"]
                lines.Push("  " e["ts"] "  " name "  " e["errorType"] ": " e["message"] " (" e["file"] ", line " e["line"] ")")
        }
        if (lines.Length = 0)
            return "`n== Unhandled errors ==`n  none`n"
        t := "`n== Unhandled errors (newest last, at most " ReportText.ERROR_LINES ") ==`n"
        loop Min(lines.Length, ReportText.ERROR_LINES)
            t .= lines[lines.Length - Min(lines.Length, ReportText.ERROR_LINES) + A_Index] "`n"
        return t
    }

    ; Last words (stderr and stdout) of the children that are no longer running.
    static _Ended(sup) {
        t := ""
        for c in sup["children"] {
            if (c["state"] = "ready" || c["state"] = "starting" || c["output"].Length = 0)
                continue
            if (c["state"] = "exited" && c["exitCode"] = 0)
                continue
            if (t = "")
                t := "`n== Output of ended children (last " ReportText.OUTPUT_LINES " lines) ==`n"
            t .= c["name"] " (" c["state"] ", exit " c["exitCode"] "):`n"
            loop Min(c["output"].Length, ReportText.OUTPUT_LINES)
                t .= "  " c["output"][c["output"].Length - Min(c["output"].Length, ReportText.OUTPUT_LINES) + A_Index] "`n"
        }
        return t
    }

    ; The newest log lines of the supervisor (it logs the starts, ends and hangs of all children).
    static _Tail(sup) {
        recent := sup["log"]["recent"]
        if (recent.Length = 0)
            return ""
        t := "`n== Log of the supervisor (last " Min(recent.Length, ReportText.LOG_LINES) " entries) ==`n"
        loop Min(recent.Length, ReportText.LOG_LINES) {
            e := recent[recent.Length - Min(recent.Length, ReportText.LOG_LINES) + A_Index]
            t .= "  " e["ts"] " " e["level"] " " e["source"] ": " e["text"] "`n"
        }
        return t
    }

    ; Truth of a flag that may be Json.True/Json.False (objects, always "true" for AHK) or 0/1.
    static _On(flag) {
        if (flag == Json.True)
            return true
        return IsObject(flag) ? false : (flag ? true : false)
    }

    static _Join(list) {
        out := ""
        for item in list
            out .= (out = "" ? "" : ", ") item
        return out
    }

    static _Pad(value, width) {
        text := String(value)
        return StrLen(text) >= width ? text " " : text Format("{:" (width - StrLen(text)) "}", "")
    }
}
