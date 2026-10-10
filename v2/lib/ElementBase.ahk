#Requires AutoHotkey v2.0

class ElementBase {
    static Name => "Base Element"
    static Category => "General"
    static Level => "Beginner"
    static Stability => "Stable"

    static GetParametrizationDetails(env) {
        return []
    }

    static GenerateName(env, params) {
        return this.Name
    }

    autoEvaluateParameters(env, params) {
        eval := Map()
        if params is Map {
            for k, v in params {
                eval[k] := v
            }
        }
        return eval
    }

    run(env, params) {
        this.finish(env, "normal")
    }

    stop(env, params) {
    }

    finish(env, status := "normal", resultMessage := "") {
        if (env.HasOwnProp("OnElementFinished")) {
            env.OnElementFinished(this, status, resultMessage)
        }
    }
}
