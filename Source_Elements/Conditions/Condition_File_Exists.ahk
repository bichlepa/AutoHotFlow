#Requires AutoHotkey v2.0
#Include ../lib/ElementBase.ahk

class Condition_File_Exists extends ElementBase {
    static Name => "File Exists"
    static Category => "File system"

    run(env, params) {
        evalParams := this.autoEvaluateParameters(env, params)
        path := evalParams.Has("filePath") ? evalParams["filePath"] : ""

        exists := FileExist(path) != ""
        if (env.HasOwnProp("SetConditionResult")) {
            env.SetConditionResult(exists)
        }
        this.finish(env, "normal", exists ? "True" : "False")
    }
}
