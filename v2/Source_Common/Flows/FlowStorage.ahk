#Requires AutoHotkey v2.0
#Include "../../lib/NamedPipeIPC.ahk"

class FlowStorage {
    static LoadFlow(filepath) {
        if !FileExist(filepath)
            throw TargetError("Flow file not found: " . filepath)

        content := FileRead(filepath, "UTF-8")
        flowData := FlowStorage.ParseAHF(content)
        return flowData
    }

    static SaveFlow(filepath, flowDataMap) {
        jsonString := FlowStorage.SerializeAHF(flowDataMap)
        dir := RegExReplace(filepath, "\\[^\\]+$")
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)

        if FileExist(filepath)
            FileDelete(filepath)
        FileAppend(jsonString, filepath, "UTF-8")
    }

    static ParseAHF(jsonStr) {
        msg := JSON.parse(jsonStr)
        flowMap := Map()
        flowMap["name"] := msg.Has("name") ? msg["name"] : "Unnamed Flow"
        flowMap["version"] := msg.Has("version") ? msg["version"] : "2.0.0"
        flowMap["elements"] := msg.Has("elements") ? msg["elements"] : []
        flowMap["connections"] := msg.Has("connections") ? msg["connections"] : []
        flowMap["variables"] := msg.Has("variables") ? msg["variables"] : Map()
        flowMap["settings"] := msg.Has("settings") ? msg["settings"] : Map()
        return flowMap
    }

    static SerializeAHF(flowDataMap) {
        return JSON.stringify(flowDataMap)
    }
}
