#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ScriptHost.ahk

; Trigger AutoHotkey script of the package Default (WI-0130, E0039, E0104): the script runs while the trigger is armed. Each
; the trigger call of the script fires the trigger with the export variables; TriggerVariables sets them as instance variables.
; The import variables are read by the engine at the arming (ImportNames, PROTOCOL 4.4) and given to the script as globals.
; Class ID, parameter IDs and language keys are those of v1 (Source_Elements/Default/Triggers/AutoHotkey_Script.ahk); the
; default code is v2 (MIGRATION M-0158, M-0159).
;
; Mode trigger: the process is read by a timer every 50 ms (never blocking). A process that ends by itself is reported as
; evt.trigger.error (its stderr text or its exit code) and the trigger stays armed without effect (REQ-TRG-010). Disable
; ends the process at once. The timer is a chain of ctx.After calls, so it ends with the disarm.
class Trigger_AutoHotkey_Script extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := true
    static Level := "Programmer"
    static Stability := "Experimental"
    static Icon := ""
    static POLL_MS := 50

    static Name() => Lang("AutoHotkey script")
    static Category() => Lang("Expert")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("AutoHotkey script"), WarnIfEmpty: true},
        {type: "multilineEdit", id: "Script", default: "Loop`n{`n    Sleep 10000`n    " . "x_" . "trigger()`n}", WarnIfEmpty: false},
        {type: "Label", label: Lang("Variables that should be imported to script before enabling")},
        {type: "multiLineEdit", id: "ImportVariables"},
        {type: "Label", label: Lang("Variables that should be exported from script on trigger")},
        {type: "multiLineEdit", id: "ExportVariables"}
    ]

    static GenerateName(ctx, params) {
        script := params.HasProp("Script") ? params.Script : ""
        return Lang("AutoHotkey script") "`n" SubStr(script, 1, 50)
    }

    static ImportNames(params) => ScriptHost.NameList(params.HasProp("ImportVariables") ? params.ImportVariables : "")

    ; Starts the process (the imports come from the arming, ctx.imports) and the poll timer. Errors of the start are
    ; the arming's error (ok false).
    static Enable(ctx, params) {
        exports := ScriptHost.NameList(params.HasProp("ExportVariables") ? params.ExportVariables : "")
        imports := ctx.imports
        info := ScriptHost.Start(params.HasProp("Script") ? params.Script : "", imports, exports)
        ctx.State.proc := info
        ctx.State.errText := ""
        ctx.State.poll := ctx.Guard(() => this._Poll(ctx))
        ctx.After(this.POLL_MS, ctx.State.poll)
        return ""
    }

    ; Stops the process (and the poll, which ends with the disarm).
    static Disable(ctx) {
        if (ctx.State.HasProp("proc"))
            ScriptHost.Stop(ctx.State.proc)
    }

    ; The export variables of the fire: the data of the event, texts, numbers and objects as JSON (ScriptHost.FireData).
    static TriggerVariables(params, data) {
        vars := Map()
        if (!(data is Map))              ; a start that no event caused (a manual start) has no data
            return vars
        for name, value in data {
            if (SubStr(name, 1, 5) = "json:")
                continue
            if (data.Has("json:" name)) {
                try vars[name] := Json.Parse(value)
                catch
                    vars[name] := value
            } else {
                vars[name] := value
            }
        }
        return vars
    }

    ; One poll: the fire lines fire the trigger, and the end of the process is reported. The next poll is scheduled before
    ; an error is thrown, so the timer chain goes on while the process runs.
    static _Poll(ctx) {
        info := ctx.State.proc
        if (ScriptHost.Running(info))
            ctx.After(this.POLL_MS, ctx.State.poll)
        for line in info["stdout"].ReadLines() {
            msg := ScriptHost.ParseLine(line)
            if (IsObject(msg) && msg["ahf"] = "fire" && ctx.IsOpen)
                ctx.Fire(ScriptHost.FireData(msg.Get("vars", Map())))
        }
        ctx.State.errText .= this._Text(info["stderr"].ReadLines())
        if (ScriptHost.Running(info))
            return
        for line in info["stdout"].Drain() {
            msg := ScriptHost.ParseLine(line)
            if (IsObject(msg) && msg["ahf"] = "fire" && ctx.IsOpen)
                ctx.Fire(ScriptHost.FireData(msg.Get("vars", Map())))
        }
        ctx.State.errText .= this._Text(info["stderr"].Drain())
        code := ScriptHost.ExitCode(info)
        ScriptHost.Close(info)
        text := Trim(ctx.State.errText, "`r`n")
        if (text = "")
            text := Lang("AutoHotkey script ended (exit code %1%).", code)
        throw ElementError(text)
    }

    static _Text(lines) {
        text := ""
        for line in lines
            text .= line "`n"
        return text
    }
}
