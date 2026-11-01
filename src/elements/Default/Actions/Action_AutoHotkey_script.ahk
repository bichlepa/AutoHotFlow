#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ScriptHost.ahk

; Action AutoHotkey script of the package Default (WI-0130, E0039, E0104): runs AutoHotkey v2 code of the user in a process
; of its own and waits for its end. The import variables are globals of the script at its start; the export variables
; (and result and resultmessage, as in v1) are set when the script ends. Class ID, parameter IDs and language keys are
; those of v1 (Source_Elements/Default/Actions/AutoHotkey_script.ahk), the code is v2 (MIGRATION M-0158, M-0159).
;
; Mode worker: the wait is a loop of Sleep(50) (the messages of the worker, the cancel among them, run during the Sleep),
; and the stdout of the script is read in the loop, so a script that writes much does not block. Stop (cancel) ends
; the process at once. A job deadline is not set: the script runs until it ends or is stopped.
class Action_AutoHotkey_script extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Programmer"
    static Stability := "Experimental"
    static Icon := ""
    static JobTimeoutMs := 0

    static Name() => Lang("AutoHotkey script")
    static Category() => Lang("Expert")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("AutoHotkey script")},
        {type: "multilineEdit", id: "Script", content: "RawString", default: "", WarnIfEmpty: false},
        {type: "Label", label: Lang("Variables that should be imported to script prior to execution")},
        {type: "multiLineEdit", id: "ImportVariables", content: "String"},
        {type: "Label", label: Lang("Variables that should be exported from script after execution")},
        {type: "multiLineEdit", id: "ExportVariables", content: "String"}
    ]

    static GenerateName(ctx, params) {
        script := params.HasProp("Script") ? params.Script : ""
        return Lang("AutoHotkey script") "`n" SubStr(script, 1, 50)
    }

    static ImportNames(params) => ScriptHost.NameList(params.HasProp("ImportVariables") ? params.ImportVariables : "")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        imports := Map()
        for name in ScriptHost.NameList(p.ImportVariables)
            imports[name] := ctx.GetVar(name, "")
        exports := ScriptHost.NameList(p.ExportVariables)
        for name in ["result", "resultmessage"] {
            known := false
            for e in exports
                known := known || (e = name)
            if (!known)
                exports.Push(name)
        }
        info := ScriptHost.Start(p.Script, imports, exports)
        ctx.State.proc := info
        out := ""                       ; the vars of the exit line, a Map, when it came
        errText := ""
        while (!ctx.stopped) {
            Sleep(50)
            out := this._Collect(info["stdout"], out)
            errText .= this._Text(info["stderr"].ReadLines())
            if (!ScriptHost.Running(info))
                break
        }
        if (ctx.stopped) {
            ScriptHost.Stop(info)
            return
        }
        out := this._Collect(info["stdout"], out, true)
        errText .= this._Text(info["stderr"].Drain())
        code := ScriptHost.ExitCode(info)
        ScriptHost.Close(info)
        if (errText != "")
            throw ElementError(Trim(errText, "`r`n"))
        if (!IsObject(out))
            throw ElementError(Lang("AutoHotkey script ended without a result (exit code %1%).", code))
        for name in exports
            if (out.Has(name))
                ctx.SetVar(name, out[name])
        if (out.Get("result", "") = "exception") {
            message := out.Get("resultmessage", "")
            ctx.Finish("exception", message = "" ? Lang("Unknown error") : String(message))
        } else {
            ctx.Finish("normal", String(out.Get("resultmessage", "")))
        }
    }

    ; Stops the script: the process ends at once (no finish is reported; the worker sends "stopped").
    static Stop(ctx, params) {
        if (ctx.State.HasProp("proc"))
            ScriptHost.Stop(ctx.State.proc)
    }

    ; Reads the stdout lines and keeps the vars of the "exit" line (a Map), or the given value.
    static _Collect(pipe, current, last := false) {
        for line in pipe.ReadLines(65536) {
            msg := ScriptHost.ParseLine(line)
            if (IsObject(msg) && msg["ahf"] = "exit")
                current := msg.Get("vars", Map())
        }
        if (last) {
            for line in pipe.Drain() {
                msg := ScriptHost.ParseLine(line)
                if (IsObject(msg) && msg["ahf"] = "exit")
                    current := msg.Get("vars", Map())
            }
        }
        return current
    }

    static _Text(lines) {
        text := ""
        for line in lines
            text .= line "`n"
        return text
    }
}
