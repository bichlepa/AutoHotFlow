#Requires AutoHotkey v2.0
#Include ../lib/NamedPipeIPC.ahk

class ManagerClientGUI {
    __New() {
        this.ipc := NamedPipeIPC("manager", (msg) => this.handleMessage(msg))
    }

    buildGui() {
        this.guiObj := Gui("+Resize", "AutoHotFlow v2 - Manager")
        this.treeView := this.guiObj.Add("TreeView", "w300 h400")
        this.btnStart := this.guiObj.Add("Button", "x+10 w100", "Start Flow")
        this.btnStart.OnEvent("Click", (btn, info) => this.onStartClicked())
        return this.guiObj
    }

    onStartClicked() {
        msg := this.ipc.createMessage("command", "engine", "flow:start", Map("flow_id", "selected_flow"))
        ; Send via IPC
    }

    handleMessage(msg) {
        ; Update TreeView status based on IPC events from Engine
    }
}
