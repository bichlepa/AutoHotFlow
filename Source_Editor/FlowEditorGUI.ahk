#Requires AutoHotkey v2.0
#Include ../lib/NamedPipeIPC.ahk

class FlowEditorGUI {
    __New(flowId) {
        this.flowId := flowId
        this.ipc := NamedPipeIPC("editor_" . flowId, (msg) => this.handleMessage(msg))
        this.elements := Map()
        this.selectedElementId := ""
    }

    buildGui() {
        this.guiObj := Gui("+Resize", "AutoHotFlow v2 - Flow Editor: " . this.flowId)
        this.canvas := this.guiObj.Add("Custom", "ClassAutoHotFlowCanvas x10 y10 w800 h500")

        this.btnRun := this.guiObj.Add("Button", "x10 y520 w100", "Run Flow")
        this.btnRun.OnEvent("Click", (btn, info) => this.onRunFlow())

        this.btnStop := this.guiObj.Add("Button", "x120 y520 w100", "Stop Flow")
        this.btnStop.OnEvent("Click", (btn, info) => this.onStopFlow())

        return this.guiObj
    }

    onRunFlow() {
        msg := this.ipc.createMessage("command", "engine", "flow:start", Map("flow_id", this.flowId))
        ; Send via IPC to Engine
    }

    onStopFlow() {
        msg := this.ipc.createMessage("command", "engine", "flow:stop", Map("flow_id", this.flowId))
        ; Send via IPC to Engine
    }

    handleMessage(msg) {
        action := msg.Has("action") ? msg["action"] : ""
        if (action == "instance:element_running") {
            elemId := msg["payload"]["element_id"]
            this.highlightElement(elemId, "red")
        } else if (action == "instance:element_finished") {
            elemId := msg["payload"]["element_id"]
            this.highlightElement(elemId, "default")
        }
    }

    highlightElement(elemId, color) {
        ; Highlights currently executing flow elements on the GDI+ canvas
    }
}
