#Requires AutoHotkey v2.0
#Include "../../lib/ElementBase.ahk"

class Condition_File_Exists extends ElementBase {
    static Name => "File Exists"
    static Category => "File system"
    static Level => "Beginner"
    static Stability => "Stable"

    static GetParametrizationDetails(env) {
        params := []
        params.Push(Map("type", "Label", "label", x_lang("File Path")))
        params.Push(Map("type", "FileSelect", "id", "filePath", "default", "", "content", "String"))
        return params
    }

    static GenerateName(env, params) {
        path := params.Has("filePath") ? params["filePath"] : ""
        return x_lang("File Exists") . " (" . path . ")"
    }

    run(env, params) {
        evalParams := this.autoEvaluateParameters(env, params)
        path := evalParams.Has("filePath") ? evalParams["filePath"] : ""

        if FileExist(path) {
            env.SetVariable("_condition_result", true)
            this.finish(env, "normal", "True")
        } else {
            env.SetVariable("_condition_result", false)
            this.finish(env, "normal", "False")
        }
    }
}
