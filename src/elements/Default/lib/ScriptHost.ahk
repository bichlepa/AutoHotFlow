#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Json.ahk
#Include ..\..\..\core\ChildLauncher.ahk

; Script host of the AutoHotkey script elements (WI-0130, E0039, E0104). Shared by the action (worker) and the trigger
; (trigger host). It runs the user's AutoHotkey v2 code in a process of its own:
;
;   info := ScriptHost.Start(code, imports, exports)   ; Map: pid, process, job, stdout, stderr (ChildPipe), prologueLines
;   ScriptHost.ParseLine(line)                        ; Map of a protocol line of the script, or "" (any other line)
;   ScriptHost.Running(info) / ScriptHost.ExitCode(info) / ScriptHost.Stop(info)
;
; The interpreter is A_AhkPath (the running AutoHotFlow; S0009 adds the compiled program with /script), started as
; "AutoHotkey64.exe /ErrorStdOut=UTF-8 *": the script text comes in through stdin (AutoHotkey docs, Scripts.htm).
; The text is a prologue, generated here, and the user's code (line numbers of the user's code are the lines minus
; prologueLines):
;   - the import variables as globals of the script, with their values as literals (texts, numbers, Map, Array),
;   - the function the trigger call (writes the export variables as one JSON line, "fire"),
;   - an OnExit handler that writes the export variables as one JSON line, "exit",
;   - an OnError handler that writes the error with its line to stderr and ends the script with exit code 1.
; Protocol lines are JSON objects on stdout: {"ahf":"fire"|"exit","vars":{...}}. Other stdout text is ignored.
;
; The process runs in a job object with KILL_ON_JOB_CLOSE (ChildLauncher.StartWithInput): when the host closes the job,
; or dies, the script ends. Stop ends the process at once. The input is written into the stdin pipe at the start
; (at most ChildLauncher.INPUT_MAX bytes, the pipe holds them, so the start does not wait for the script).
;
; Names: a variable name is an identifier (letters, digits, underscore, not starting with a digit), not a built-in
; variable (A_...) and not starting with "ahf" (the prologue's own names). Errors are ElementError with a readable text.
class ScriptHost {
    static LIMIT_TEXT := "The script is larger than the pipe buffer (" ChildLauncher.INPUT_MAX " bytes)."

    ; Starts the script. imports: a Map name -> value (texts, numbers, Map, Array). exports: an Array of names.
    static Start(code, imports, exports) {
        for name in exports
            ScriptHost.CheckName(name)
        for name, value in imports
            ScriptHost.CheckName(name)
        text := ScriptHost._Text(code, imports, exports)
        input := ScriptHost._Input(text)
        commandLine := Chr(34) A_AhkPath Chr(34) " /ErrorStdOut=UTF-8 *"
        info := ChildLauncher.StartWithInput(commandLine, input)
        info["prologueLines"] := ScriptHost._Lines(ScriptHost._Head(imports, exports, 0))
        return info
    }

    ; One protocol line as a Map, or "" when the line is not a protocol line (user text, a broken line).
    static ParseLine(line) {
        if (SubStr(line, 1, 1) != "{")
            return ""
        try v := Json.Parse(line)
        catch
            return ""
        return (v is Map && v.Has("ahf")) ? v : ""
    }

    ; The data of evt.trigger.fired from the vars of a "fire" line: texts and numbers as they are; an object as its JSON text
    ; with the key "json:<name>" set to 1 (TriggerVariables parses it back).
    static FireData(vars) {
        data := Map()
        for name, value in vars {
            if (IsObject(value)) {
                data[name] := Json.Stringify(value)
                data["json:" name] := 1
            } else {
                data[name] := value
            }
        }
        return data
    }

    ; The lines of a text, as names: separators are the v1 ones (|, comma, space, line break).
    static NameList(text) {
        names := []
        text := RegExReplace(String(text), "[|,\r\n ]+", "`n")
        for name in StrSplit(text, "`n") {
            if (name != "")
                names.Push(name)
        }
        return names
    }

    ; Throws ElementError if name cannot be a variable of the script; returns the name.
    static CheckName(name) {
        if (!RegExMatch(name, "^[A-Za-z_][A-Za-z0-9_]*$") || SubStr(StrLower(name), 1, 2) = "a_" || SubStr(StrLower(name), 1, 3) = "ahf")
            throw ElementError("Variable name '" name "' is not valid for an AutoHotkey script.")
        return name
    }

    static Running(info) {
        return DllCall("WaitForSingleObject", "ptr", info["process"], "uint", 0, "uint") = 0x102   ; WAIT_TIMEOUT: still alive
    }

    ; The exit code of an ended process, -1 while it runs.
    static ExitCode(info) {
        code := 0
        if (!DllCall("GetExitCodeProcess", "ptr", info["process"], "uint*", &code))
            return -1
        return (code = 0x103) ? -1 : code     ; STILL_ACTIVE
    }

    ; Ends the process at once (TerminateProcess) and releases every handle of the script. The job kills the processes
    ; that the script started as well.
    static Stop(info) {
        if (!IsObject(info))
            return
        if (info["process"] != 0 && ScriptHost.Running(info))
            DllCall("TerminateProcess", "ptr", info["process"], "uint", 1)
        ScriptHost.Close(info)
    }

    ; Releases the handles (the process, the job and the two pipes). Safe to call twice. keepChildren: the script ended by
    ; itself, so the processes it started keep running (WI-0130, as v1); a stop passes false and the job kills them.
    static Close(info, keepChildren := false) {
        if (!IsObject(info))
            return
        if (info.Get("job", 0) != 0) {
            if (keepChildren)
                ChildLauncher.ReleaseJob(info["job"])
            else
                DllCall("CloseHandle", "ptr", info["job"])
            info["job"] := 0
        }
        if (info.Get("process", 0) != 0) {
            DllCall("CloseHandle", "ptr", info["process"])
            info["process"] := 0
        }
        for key in ["stdout", "stderr"] {
            if (info.Has(key) && IsObject(info[key]))
                info[key].Close()
        }
    }

    ; The prologue and the user's code as one text (the same text is what the tests read back).
    static _Text(code, imports, exports) {
        head := ScriptHost._Head(imports, exports, 0)
        offset := ScriptHost._Lines(head)
        return ScriptHost._Head(imports, exports, offset) String(code) "`n"
    }

    ; The prologue text. offset: the number of lines before the user's code (ahfLine subtracts it).
    static _Head(imports, exports, offset) {
        text := StrReplace(ScriptHost._Base(), "XTRIGGER", "x_" . "trigger")
        text .= "ahfLine(n) {`n    return n - " offset "`n}`n"
        for name, value in imports
            text .= name " := " ScriptHost.Literal(value) "`n"
        text .= ScriptHost._ExportFunction(exports)
        text .= "OnExit(ahfOnExit)`nOnError(ahfOnError)`n"
        return text
    }

    ; ahfExports(): a Map of the export variables that are set (the names are globals of the script).
    static _ExportFunction(exports) {
        list := ""
        for name in exports
            list .= (list = "" ? "" : ", ") name
        text := "ahfExports() {`n"
        if (list != "")
            text .= "    global " list "`n"
        text .= "    ahfVars := Map()`n"
        for name in exports
            text .= "    if IsSet(" name ")`n        ahfVars[`"" name "`"] := " name "`n"
        text .= "    return ahfVars`n}`n"
        return text
    }

    ; The text as UTF-8 without a byte order mark: read from stdin, a BOM is taken for text and breaks line 1 (test run).
    static _Input(text) {
        tmp := Buffer(StrLen(text) * 4 + 4, 0)
        size := StrPut(text, tmp, "UTF-8") - 1     ; the count includes the terminating null
        input := Buffer(size, 0)
        DllCall("RtlMoveMemory", "ptr", input, "ptr", tmp, "uptr", size)
        return input
    }

    static _Lines(text) {
        return StrLen(text) - StrLen(StrReplace(text, "`n", ""))
    }

    ; A value as an AutoHotkey v2 literal: a text is quoted (Quote), an Integer or Float is written as a number,
    ; a Map is Map(key, value, ...), an Array is [ ... ].
    static Literal(value) {
        if (value is Map) {
            parts := ""
            for k, v in value
                parts .= (parts = "" ? "" : ", ") ScriptHost.Quote(String(k)) ", " ScriptHost.Literal(v)
            return "Map(" parts ")"
        }
        if (value is Array) {
            parts := ""
            for v in value
                parts .= (parts = "" ? "" : ", ") ScriptHost.Literal(v)
            return "[" parts "]"
        }
        if (value is Integer)
            return String(value)
        if (value is Float) {
            text := String(value)
            if (!InStr(text, "#") && !InStr(text, "?"))     ; not "inf" or "nan"
                return text
        }
        return ScriptHost.Quote(IsObject(value) ? "" : String(value))
    }

    ; A text as an AutoHotkey string literal (escape sequences of the v2 backtick).
    static Quote(text) {
        bt := Chr(96)
        text := StrReplace(text, bt, bt bt)
        text := StrReplace(text, Chr(34), bt Chr(34))
        text := StrReplace(text, "`n", bt "n")
        text := StrReplace(text, "`r", bt "r")
        text := StrReplace(text, "`t", bt "t")
        return Chr(34) text Chr(34)
    }

    ; The part of the prologue that is the same for every script. A continuation section: its text is taken as it is
    ; (no backtick escapes here; the line breaks are real ones).
    static _Base() {
        text := "
(
#Requires AutoHotkey v2.0
#NoTrayIcon
ahfQ(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, Chr(34), "\" Chr(34))
    s := StrReplace(s, Chr(10), "\n")
    s := StrReplace(s, Chr(13), "\r")
    s := StrReplace(s, Chr(9), "\t")
    return Chr(34) s Chr(34)
}
ahfJ(v) {
    if (v is Map) {
        out := ""
        for k, x in v
            out .= (out = "" ? "" : ",") ahfQ(String(k)) ":" ahfJ(x)
        return Chr(123) out Chr(125)
    }
    if (v is Array) {
        out := ""
        for x in v
            out .= (out = "" ? "" : ",") ahfJ(x)
        return "[" out "]"
    }
    if (v is Integer)
        return String(v)
    if (v is Float) {
        t := String(v)
        if (InStr(t, "#") || InStr(t, "?"))
            return ahfQ(t)
        return t
    }
    return ahfQ(String(v))
}
ahfEmit(kind, vars) {
    FileAppend(Chr(123) ahfQ("ahf") ":" ahfQ(kind) "," ahfQ("vars") ":" ahfJ(vars) Chr(125) Chr(10), "*", "UTF-8")
}
XTRIGGER(*) {
    ahfEmit("fire", ahfExports())
}
ahfOnExit(reason, code) {
    ahfEmit("exit", ahfExports())
    return 0
}
ahfOnError(e, mode) {
    FileAppend("Line " ahfLine(e.Line) ": " e.Message Chr(10), "**", "UTF-8")
    ExitApp(1)
}
)"
        return text
    }
}
