#Requires AutoHotkey v2.0
#Include ..\..\..\src\core\Errors.ahk
#Include ..\..\..\src\core\Json.ahk
#Include ..\..\..\src\core\Args.ahk
#Include ..\..\..\src\elements\base\SystemOps.ahk

; System provider of the test entries of the worker and the trigger host (E0103, WI-0117). It records every call of
; SystemOps (function, arguments, element, flow) and answers from a script, so an element that shuts down, locks, ejects,
; blocks the input or plays a sound runs headless: none of the real functions is called in a test.
;
; The script and the log are files in <data>\TestSystem\, so the worker and the trigger host of the session share them:
;   script.json    {"answers": {"<Function>": [ {...}, {...} ]}, "idleBaseMs": N}
;                  The n-th call of a function takes the n-th entry, in any process. An entry is
;                    "value"   the return value
;                    "error"   the call throws AhfError: the element ends with "exception"
;                  No entry left: the call returns the empty value of the function (0, "" or an empty Array) and is
;                  logged with scripted false; nothing real runs, so the call does not block.
;                  "idleBaseMs": TimeIdle and TimeIdlePhysical answer idleBaseMs plus the time since the provider started,
;                  unless an entry for them exists.
;   requests.jsonl one JSON object per line and per call: function, args, scripted, answer or error, element, flow,
;                  pid, role.
; Registration is not tied to --test-roles: the test entries of the worker and the trigger host call Register() before AhfMain.
class TestSystemProvider {
    ; Registers the provider in this process. The product entries never include this file (rule system-seam).
    static Register() {
        SystemOps.UseProvider(TestSystemProvider())
    }

    __New() {
        opts := Args.Parse(A_Args)
        this.role := opts.Get("role", "")
        this.dir := opts.Has("data") ? opts["data"] "\TestSystem" : A_Temp "\ahf_nodata_TestSystem"
        this.scriptPath := this.dir "\script.json"
        this.logPath := this.dir "\requests.jsonl"
        this.started := A_TickCount
    }

    Shutdown(flags) => this._Call("Shutdown", [flags], 0)
    LockWorkStation() => this._Call("LockWorkStation", [], 0)
    Hibernate(force := 0) => this._Call("Hibernate", [force], 0)
    Suspend(force := 0) => this._Call("Suspend", [force], 0)

    DriveEject(args*) => this._Call("DriveEject", args, 0)
    DriveSetLabel(args*) => this._Call("DriveSetLabel", args, 0)
    DriveLock(args*) => this._Call("DriveLock", args, 0)
    DriveUnlock(args*) => this._Call("DriveUnlock", args, 0)

    FileRecycle(args*) => this._Call("FileRecycle", args, 0)
    FileRecycleEmpty(args*) => this._Call("FileRecycleEmpty", args, 0)

    ChangeDisplaySettings(args*) => this._Call("ChangeDisplaySettings", args, 0)

    SoundBeep(args*) => this._Call("SoundBeep", args, 0)
    SoundPlay(args*) => this._Call("SoundPlay", args, 0)
    SoundSetMute(args*) => this._Call("SoundSetMute", args, 0)
    SoundSetVolume(args*) => this._Call("SoundSetVolume", args, 0)
    SpeakText(text, rate := 0, volume := 100, wait := 1) => this._Call("SpeakText", [text, rate, volume, wait], 0)
    SpeechVoices() => this._Call("SpeechVoices", [], [])

    BlockInput(args*) => this._Call("BlockInput", args, 0)
    Click(args*) => this._Call("Click", args, 0)
    MouseClickDrag(args*) => this._Call("MouseClickDrag", args, 0)
    MouseMove(args*) => this._Call("MouseMove", args, 0)
    Send(keys, mode := "") => this._Call("Send", [keys, mode], 0)
    SetCapsLockState(args*) => this._Call("SetCapsLockState", args, 0)
    SetNumLockState(args*) => this._Call("SetNumLockState", args, 0)
    SetScrollLockState(args*) => this._Call("SetScrollLockState", args, 0)

    TimeIdle() => this._Idle("TimeIdle")
    TimeIdlePhysical() => this._Idle("TimeIdlePhysical")

    ; Answers a call from its entry (or the empty value), logs it and returns the answer.
    _Call(name, args, empty) {
        entry := this._Take(name)
        if (entry = "") {
            this._Log(name, args, false, empty, "")
            return empty
        }
        if (entry.Has("error")) {
            this._Log(name, args, true, "", entry["error"])
            throw AhfError("test system: " name " failed: " entry["error"], ErrCode.EXCEPTION)
        }
        value := entry.Get("value", empty)
        this._Log(name, args, true, value, "")
        return value
    }

    _Idle(name) {
        if (this._Take(name) = "") {
            base := this._Script().Get("idleBaseMs", "")
            if (base != "") {
                value := base + (A_TickCount - this.started)
                this._Log(name, [], true, value, "")
                return value
            }
        }
        return this._Call(name, [], 0)
    }

    ; The entry the next call of the function takes: the calls logged so far with an entry are counted.
    _Take(name) {
        entries := this._Entries(name)
        used := this._Used(name)
        return used < entries.Length ? entries[used + 1] : ""
    }

    _Used(name) {
        n := 0
        needle := '"function":"' name '"'
        for line in StrSplit(this._ReadFile(this.logPath), "`n") {
            if (InStr(line, needle) && InStr(line, '"scripted":true'))
                n += 1
        }
        return n
    }

    _Entries(name) {
        answers := this._Script().Get("answers", Map())
        return answers.Has(name) ? answers[name] : []
    }

    _Script() {
        text := this._ReadFile(this.scriptPath)
        return text = "" ? Map() : Json.Parse(text)
    }

    _Log(name, args, scripted, answer, error) {
        row := Map("function", name, "args", args, "scripted", scripted ? Json.True : Json.False, "pid", ProcessExist(),
            "role", this.role, "element", SystemOps.elementId, "flow", SystemOps.flowId)
        if (error != "")
            row["error"] := error
        else
            row["answer"] := answer
        try {
            DirCreate(this.dir)
        } catch {
            ; exists already
        }
        FileAppend(Json.Stringify(row) "`n", this.logPath, "UTF-8-RAW")
    }

    _ReadFile(path) {
        try {
            return FileRead(path, "UTF-8")
        } catch {
            return ""       ; not written yet
        }
    }
}
