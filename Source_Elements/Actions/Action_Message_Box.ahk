#Requires AutoHotkey v2.0
#Include ../lib/ElementBase.ahk

class Action_Message_Box extends ElementBase {
    static Name => "Message Box"
    static Category => "User interaction"

    run(env, params) {
        evalParams := this.autoEvaluateParameters(env, params)
        msg := evalParams.Has("message") ? evalParams["message"] : "Hello World"
        title := evalParams.Has("title") ? evalParams["title"] : "AutoHotFlow"

        ; Delegate UI dialog to IPC client
        if (env.HasOwnProp("RequestUIDialog")) {
            env.RequestUIDialog(Map("type", "msgbox", "title", title, "message", msg))
        }
        this.finish(env, "normal")
    }
}
