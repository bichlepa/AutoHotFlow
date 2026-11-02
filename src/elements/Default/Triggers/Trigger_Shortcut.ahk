#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Trigger Shortcut of the package Default (WI-0133, REQ-TRG-240, REQ-DST-040, REQ-TRG-200): when armed, it writes a shortcut
; file that starts AutoHotFlow with the command "Trigger|<flow>|<element>"; the engine then starts the flow at this trigger
; (PROTOCOL 4.1 cmd.app.command, 4.2 cmd.flow.startAtTrigger). Disarmed by the user (or re-armed with another path), it
; removes the file when the option RemoveShortcutOnDisabling is on. Parameters, GenerateName and language keys are those of
; v1 (Source_Elements/Default/Triggers/Shortcut.ahk), except the default path (DEVIATIONS below).
;
; DEVIATIONS from v1 (MIGRATION M-0179):
;   - the path must be absolute (v1 took a relative path from the working directory); the file must end with .lnk;
;   - the default path is "%A_Desktop%\AutoHotFlow shortcut.lnk" (v1: "Flow <name>.lnk" of the flow).
;   - the command line of the shortcut names the session and the data folder of this instance (--session, --data) and the
;     program script that runs (ctx.launch, the option --app-script of the supervisor), so a shortcut started from a test
;     session reaches that session and no other.
;
; The trigger host has no file access: the file is written and removed by storage (cmd.storage.shortcut.write / remove,
; PROTOCOL 4.6) through ctx.Request. The arming answers at once; a failure of the write comes as evt.trigger.error.
class Trigger_Shortcut extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Shortcut")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Path of the shortcut")},
        {type: "File", id: "ShortCutPath", default: "%A_Desktop%\AutoHotFlow shortcut.lnk", label: Lang("Set the shortcut path"), options: 32, filter: Lang("Shortcut") " (*.lnk)", WarnIfEmpty: true},
        {type: "Label", label: Lang("Options")},
        {type: "Checkbox", id: "RemoveShortcutOnDisabling", default: 1, label: Lang("Remove shortcut when disabling")}
    ]

    ; "Shortcut - C:\Users\...\AutoHotFlow shortcut.lnk" (v1 Element_GenerateName_Trigger_Shortcut, one line).
    static GenerateName(ctx, params) => Lang("Shortcut") " - " (params.HasProp("ShortCutPath") ? params.ShortCutPath : "")

    static CheckSettings(form, params, staticValues) {
    }

    ; Arms the trigger: checks the path, then asks storage for the shortcut (the answer comes later). A bad path refuses
    ; the arming with the v1 text, so nothing is written. The state keeps the path and the option for Disable.
    static Enable(ctx, params) {
        path := params.HasProp("ShortCutPath") ? params.ShortCutPath : ""
        if (IsObject(path) || !this.PathOk(path))
            throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "ShortCutPath", IsObject(path) ? "" : path))
        ctx.State.path := String(path)
        ctx.State.remove := params.HasProp("RemoveShortcutOnDisabling") && this._Truth(params.RemoveShortcutOnDisabling)
        ctx.Request("storage", "cmd.storage.shortcut.write", this.Shortcut(ctx, ctx.State.path)
            , (ans) => this._Written(ctx, ans), 15000)
        return ""
    }

    ; Removes the shortcut when the user switched the trigger off or re-armed it, and the option is on. Not at a reset of
    ; the trigger host (the engine restarts its arming) and not at a shutdown: the shortcut stays for the next start.
    static Disable(ctx) {
        if (!ctx.State.HasProp("path") || !ctx.State.remove)
            return
        if (ctx.DisarmReason != "disarm" && ctx.DisarmReason != "rearm")
            return
        ctx.Request("storage", "cmd.storage.shortcut.remove", Map("path", ctx.State.path)
            , (ans) => this._Removed(ctx, ans), 15000)
    }

    ; The thread variables: none (the trigger starts the flow with no data).
    static TriggerVariables(params, data) => Map()

    ; The fields of cmd.storage.shortcut.write: the program that runs (the interpreter with the program script, the session
    ; and the data folder of this instance) and the command. The one place that builds the command line of the shortcut.
    static Shortcut(ctx, path) {
        launch := ctx.launch
        script := launch.Get("script", "")
        if (script = "")
            throw ElementError("the program of AutoHotFlow is not known to this instance; the shortcut cannot be made")
        args := '"' script '"'
        if (launch.Get("session", "") != "")
            args .= ' "--session=' launch["session"] '"'
        if (launch.Get("data", "") != "")
            args .= ' "--data=' launch["data"] '"'
        args .= ' "--command=' this.Command(ctx.flowId, ctx.elementId) '"'
        return Map("path", path, "target", A_AhkPath, "args", args
            , "workDir", SubStr(script, 1, InStr(script, "\", , -1) - 1))
    }

    ; The command text of a shortcut: "Trigger|<flow>|<element>" (PROTOCOL 4.1).
    static Command(flowId, elementId) => "Trigger|" flowId "|" elementId

    ; An absolute path (drive or UNC), one line, extension .lnk (the rules of the storage role, checked here first).
    static PathOk(path) => RegExMatch(path, "^([A-Za-z]:\\|\\\\[^\\]+\\)") && !InStr(path, "`n") && !InStr(path, "`r")
        && RegExMatch(path, "i)\.lnk$")

    ; The answer of the write: a failure is the trigger's error (evt.trigger.error, the trigger stays armed).
    static _Written(ctx, ans) {
        if (ans.Get("ok", false)) {
            ctx.Log("a1", "shortcut " ans.Get("action", "") ": " ctx.State.path)
            return
        }
        throw ElementError(Lang("Can't create shortcut in path '%1%'", ctx.State.path) this._Reason(ans))
    }

    static _Removed(ctx, ans) {
        if (ans.Get("ok", false)) {
            ctx.Log("a1", "shortcut " ans.Get("action", "") ": " ctx.State.path)
            return
        }
        ctx.Log("f0", "the shortcut '" ctx.State.path "' was not removed" this._Reason(ans))
    }

    ; ": message" of an error answer, "" when there is no text.
    static _Reason(ans) {
        if (ans.Has("error") && ans["error"] is Map && ans["error"].Has("message"))
            return ": " ans["error"]["message"]
        return ""
    }

    ; A checkbox value: 1 or true is on (the flow file keeps 1 or 0, as v1).
    static _Truth(value) => !IsObject(value) && (String(value) = "1" || StrLower(String(value)) = "true")
}
