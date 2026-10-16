#Requires AutoHotkey v2.0
#Include ..\..\..\src\core\Errors.ahk
#Include ..\..\..\src\core\Json.ahk
#Include ..\..\..\src\core\Args.ahk
#Include ..\..\..\src\elements\base\Dialogs.ahk

; Dialog provider of the test entries (E0038, WI-0051): answers the dialogs of elements from a script instead of opening
; a window, so a dialog element runs headless. The test entries register it with TestDialogProvider.Register() before
; AhfMain; the product entries do not include this file (and arch_check.py forbids Dialogs.UseProvider in src/).
;
; The script and the log are files in <data>\TestDialogs\, so every process of the session (engine, every worker) reaches
; the same ones without a message route (a pooled worker cannot be addressed by a test):
;   script.json    {"answers": [ {...}, {...} ]}. The test writes it before the dialog is requested (support/dialogs.py).
;                  The n-th answered dialog (MsgBox, InputBox, FileSelect, DirSelect) takes the n-th entry, in any process.
;     "answer"       the return value: a String (MsgBox: "Yes"; FileSelect, DirSelect: the path, "" = cancelled),
;                    an Array (FileSelect with multi-select), or for InputBox an object {"result": "OK", "value": "text"}.
;     "delayMs"      optional, wait this long before the answer (the dialog is "open" meanwhile).
;     "noAnswer"     true: nobody answers. With a timeout in the options (MsgBox "T2", InputBox "T2") the dialog returns
;                    "Timeout" after that time as the real one does; without it the call waits for ever, in slices of
;                    50 ms, so a cancel of the job still reaches the element.
;     "kind"         optional, the function the entry is meant for; another one is an error (a wrong dialog was requested).
;   requests.jsonl one JSON object per line and per request: index, kind, args (text, title, options, ...), scripted
;                  (true when it took an answer entry), pid, role. A ToolTip is logged and takes no entry.
; Registration is not tied to --test-roles: the flow runner of the tests starts its session without it.
; A dialog with no entry left throws an AhfError in the element, which reports "exception": an unexpected dialog fails
; the test instead of blocking it.
class TestDialogProvider {
    ; Registers the provider in this process. A test entry calls it before AhfMain. Without a script every dialog of an
    ; element fails with an error (no window ever opens in a test). The product entries never include this file.
    static Register() {
        Dialogs.UseProvider(TestDialogProvider())
    }

    __New() {
        opts := Args.Parse(A_Args)
        this.role := opts.Get("role", "")
        this.dir := opts.Has("data") ? opts["data"] "\TestDialogs" : A_Temp "\ahf_nodata_TestDialogs"
        this.scriptPath := this.dir "\script.json"
        this.logPath := this.dir "\requests.jsonl"
    }

    MsgBox(text, title, options) {
        return this._Dialog("MsgBox", Map("text", text, "title", title, "options", options), options)
    }

    InputBox(prompt, title, options, defaultText) {
        answer := this._Dialog("InputBox", Map("prompt", prompt, "title", title, "options", options, "default", defaultText), options)
        if (answer is Map)
            return {Value: answer.Get("value", ""), Result: answer.Get("result", "OK")}
        return {Value: String(answer), Result: "OK"}
    }

    ToolTip(text, x?, y?, which := 1) {
        args := Map("text", text, "which", which)
        if (IsSet(x))
            args["x"] := x
        if (IsSet(y))
            args["y"] := y
        this._Log("ToolTip", args, false, "")
    }

    FileSelect(options, root, title, filter) {
        return this._Dialog("FileSelect", Map("options", options, "root", root, "title", title, "filter", filter), "")
    }

    DirSelect(root, options, prompt) {
        return this._Dialog("DirSelect", Map("root", root, "options", options, "prompt", prompt), "")
    }

    ; The window of Dialogs.Window (WI-0056): the answer is the id of a button, "close" or "timeout". A dialog that nobody
    ; answers returns "timeout" after the timeoutMs of its spec (as the real window), otherwise it waits for ever.
    Window(spec) {
        timeoutMs := spec.Get("timeoutMs", 0)
        args := Map("title", spec.Get("title", ""), "text", spec.Get("text", ""), "buttons", spec.Get("buttons", []),
            "timeoutMs", timeoutMs, "defaultId", spec.Get("defaultId", ""))
        return this._Dialog("Window", args, "", timeoutMs)
    }

    ; The debug window (REQ-DBG-060, WI-0056). The answer entry may have "actions", applied to the view before the answer
    ; ("yes", "no" or "close"; none = "close"): {"op": "set", "name", "value", "object", "convert"} (Write; the result is
    ; the error text), {"op": "delete", "name"}, {"op": "read", "name"} and {"op": "rows"}. The log row keeps what the
    ; window showed at the start (rows: name and scope), readOnly, and the result of every action (results).
    DebugWindow(view) {
        index := this._Count()
        entries := this._Entries()
        if (index >= entries.Length) {
            this._Log("Debug", Map(), false, "no answer scripted")
            throw AhfError("test dialog: no answer scripted for dialog " (index + 1) " (Debug)", ErrCode.NOT_FOUND)
        }
        entry := entries[index + 1]
        if (entry.Has("kind") && entry["kind"] != "Debug") {
            this._Log("Debug", Map(), true, "wrong kind, entry is for " entry["kind"])
            throw AhfError("test dialog: dialog " (index + 1) " is a Debug, the script has " entry["kind"], ErrCode.BAD_PAYLOAD)
        }
        rows := []
        for row in view.Rows() {
            if (row["name"] != "")
                rows.Push(Map("name", row["name"], "scope", row["scope"]))
        }
        args := Map("rows", rows, "readOnly", view.ReadOnly ? 1 : 0, "results", this._RunActions(entry.Get("actions", []), view))
        this._Log("Debug", args, true, "")
        return entry.Has("answer") ? entry["answer"] : "close"
    }

    _RunActions(actions, view) {
        results := []
        for action in actions {
            name := action.Get("name", "")
            switch action["op"], "Off" {
                case "set":
                    err := view.Write(name, action.Get("value", ""), TestDialogProvider._Flag(action.Get("object", 0)),
                        TestDialogProvider._Flag(action.Get("convert", 0)))
                    results.Push(Map("op", "set", "name", name, "error", err))
                case "delete":
                    results.Push(Map("op", "delete", "name", name, "existed", view.Delete(name)))
                case "read":
                    results.Push(Map("op", "read", "name", name, "type", view.Type(name), "text", view.Text(name, 0)))
                case "rows":
                    names := []
                    for row in view.Rows() {
                        if (row["name"] != "")
                            names.Push(row["name"])
                    }
                    results.Push(Map("op", "rows", "names", names))
                default:
                    throw AhfError("test dialog: unknown debug action '" action["op"] "'", ErrCode.BAD_PAYLOAD)
            }
        }
        return results
    }

    ; A JSON true or false of an action (parsed as Json.True / Json.False) as 1 or 0.
    static _Flag(value) {
        return (value == Json.True || value == 1) ? 1 : 0
    }

    ; Takes the next answer entry, logs the request, waits as the entry says and returns the answer. timeoutMs: the
    ; timeout of a window (Window) that nobody answers; 0 for the other dialogs.
    _Dialog(kind, args, options, timeoutMs := 0) {
        index := this._Count()
        entries := this._Entries()
        if (index >= entries.Length) {
            this._Log(kind, args, false, "no answer scripted")
            throw AhfError("test dialog: no answer scripted for dialog " (index + 1) " (" kind ")", ErrCode.NOT_FOUND)
        }
        entry := entries[index + 1]
        if (entry.Has("kind") && entry["kind"] != kind) {
            this._Log(kind, args, true, "wrong kind, entry is for " entry["kind"])
            throw AhfError("test dialog: dialog " (index + 1) " is a " kind ", the script has " entry["kind"], ErrCode.BAD_PAYLOAD)
        }
        this._Log(kind, args, true, "")
        delay := entry.Get("delayMs", 0)
        if (delay > 0)
            Sleep(delay)
        if (entry.Get("noAnswer", 0)) {
            if (timeoutMs > 0) {
                Sleep(timeoutMs)
                return "timeout"
            }
            if (RegExMatch(options, "i)(?:^|\s)T(\d+(?:\.\d+)?)", &m)) {
                Sleep(Integer(Float(m[1]) * 1000))
                return kind = "InputBox" ? Map("result", "Timeout", "value", "") : "Timeout"
            }
            loop {
                Sleep(50)
            }
        }
        return entry.Has("answer") ? entry["answer"] : ""
    }

    ; The number of dialogs that took an answer entry so far (all processes).
    _Count() {
        n := 0
        for line in StrSplit(this._ReadFile(this.logPath), "`n") {
            if (InStr(line, '"scripted":true'))
                n += 1
        }
        return n
    }

    _Entries() {
        text := this._ReadFile(this.scriptPath)
        if (text = "")
            return []
        script := Json.Parse(text)
        return script.Has("answers") ? script["answers"] : []
    }

    _Log(kind, args, scripted, note) {
        row := Map("kind", kind, "args", args, "scripted", scripted ? Json.True : Json.False, "pid", ProcessExist(), "role", this.role)
        if (note != "")
            row["note"] := note
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
