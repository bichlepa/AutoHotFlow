#Requires AutoHotkey v2.0
#Include "../../lib/ElementBase.ahk"

class Action_Sleep extends ElementBase {
    static Name => "Sleep"
    static Category => "Timing"
    static Level => "Beginner"
    static Stability => "Stable"

    static GetParametrizationDetails(env) {
        params := []
        params.Push(Map("type", "Label", "label", x_lang("Duration (ms)")))
        params.Push(Map("type", "Edit", "id", "duration", "default", "1000", "content", "Number"))
        return params
    }

    static GenerateName(env, params) {
        dur := params.Has("duration") ? params["duration"] : "1000"
        return x_lang("Sleep") . " " . dur . " ms"
    }

    run(env, params) {
        evalParams := this.autoEvaluateParameters(env, params)
        dur := evalParams.Has("duration") ? Number(evalParams["duration"]) : 1000
        Sleep(dur)
        this.finish(env, "normal")
    }
}
