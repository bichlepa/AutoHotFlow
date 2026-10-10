#Requires AutoHotkey v2.0
#Include "../../lib/ElementBase.ahk"

class Trigger_Hotkey extends ElementBase {
    static Name => "Hotkey Trigger"
    static Category => "Triggers"
    static Level => "Beginner"
    static Stability => "Stable"

    static GetParametrizationDetails(env) {
        params := []
        params.Push(Map("type", "Label", "label", x_lang("Hotkey")))
        params.Push(Map("type", "Hotkey", "id", "hotkeyStr", "default", "^!z", "content", "String"))
        return params
    }

    static GenerateName(env, params) {
        hk := params.Has("hotkeyStr") ? params["hotkeyStr"] : ""
        return x_lang("Hotkey") . ": " . hk
    }

    run(env, params) {
        evalParams := this.autoEvaluateParameters(env, params)
        hk := evalParams.Has("hotkeyStr") ? evalParams["hotkeyStr"] : ""

        if (hk != "") {
            try {
                Hotkey(hk, (hkName) => this.onTriggerFired(env, hkName))
            } catch {
                ; Hotkey error handling
            }
        }
        this.finish(env, "normal")
    }

    onTriggerFired(env, hkName) {
        if (env.HasOwnProp("OnTriggerFired")) {
            env.OnTriggerFired(this, hkName)
        }
    }
}
