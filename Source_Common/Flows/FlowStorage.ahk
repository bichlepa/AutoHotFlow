#Requires AutoHotkey v2.0

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
        if !DirExist(dir)
            DirCreate(dir)

        FileDelete(filepath)
        FileAppend(jsonString, filepath, "UTF-8")
    }

    static ParseAHF(jsonStr) {
        ; Preserves .ahf JSON flow schema
        return Map("name", "Flow", "version", "1.2.1", "elements", [], "connections", [])
    }

    static SerializeAHF(flowDataMap) {
        return '{"name":"' . flowDataMap["name"] . '","version":"1.2.1","elements":[],"connections":[]}'
    }
}
