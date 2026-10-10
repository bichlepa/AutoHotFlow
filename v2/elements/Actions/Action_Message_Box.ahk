#Requires AutoHotkey v2.0
#Include "../../lib/ElementBase.ahk"

class Action_Message_Box extends ElementBase {
    static Name => "Message Box"
    static Category => "User interaction"
    static Level => "Beginner"
    static Stability => "Stable"

    static GetParametrizationDetails(env) {
        params := []
        params.Push(Map("type", "Label", "label", x_lang("Title")))
        params.Push(Map("type", "Edit", "id", "title", "default", x_lang("Title"), "content", "String"))
        params.Push(Map("type", "Label", "label", x_lang("Message")))
        params.Push(Map("type", "multiLineEdit", "id", "message", "default", x_lang("Message"), "content", "String"))
        return params
    }

    static GenerateName(env, params) {
        title := params.Has("title") ? params["title"] : ""
        return x_lang("Message Box") . " - " . title
    }

    run(env, params) {
        evalParams := this.autoEvaluateParameters(env, params)
        title := evalParams.Has("title") ? evalParams["title"] : "Notification"
        msg := evalParams.Has("message") ? evalParams["message"] : ""

        ; In Engine runtime: MsgBox or delegate to UI client
        MsgBox(msg, title)
        this.finish(env, "normal")
    }
}
