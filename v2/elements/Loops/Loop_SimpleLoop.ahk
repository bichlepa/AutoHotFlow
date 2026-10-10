#Requires AutoHotkey v2.0
#Include "../../lib/ElementBase.ahk"

class Loop_SimpleLoop extends ElementBase {
    static Name => "Simple Loop"
    static Category => "Control Flow"
    static Level => "Beginner"
    static Stability => "Stable"

    static GetParametrizationDetails(env) {
        params := []
        params.Push(Map("type", "Label", "label", x_lang("Iterations")))
        params.Push(Map("type", "Edit", "id", "iterations", "default", "10", "content", "Number"))
        return params
    }

    static GenerateName(env, params) {
        count := params.Has("iterations") ? params["iterations"] : "10"
        return x_lang("Loop") . " " . count . " " . x_lang("times")
    }

    run(env, params) {
        evalParams := this.autoEvaluateParameters(env, params)
        maxIter := evalParams.Has("iterations") ? Number(evalParams["iterations"]) : 10
        current := env.GetVariable("_loop_iteration", 0) + 1

        if (current <= maxIter) {
            env.SetVariable("_loop_iteration", current)
            this.finish(env, "loop_continue", String(current))
        } else {
            env.SetVariable("_loop_iteration", 0)
            this.finish(env, "loop_break")
        }
    }
}
