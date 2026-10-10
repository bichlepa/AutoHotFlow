#Requires AutoHotkey v2.0
#Include ../lib/NamedPipeIPC.ahk

class EditorClient {
    __New(flowId := "") {
        this.flowId := flowId != "" ? flowId : "flow_default"
        this.ipc := NamedPipeIPC("editor_1", (msg) => this.handleMessage(msg))
        this.receivedEvents := []
        this.currentHighlightElement := ""

        this.initGui()
    }

    initGui() {
        this.gui := Gui("+Resize", "AutoHotFlow v2 Editor - " . this.flowId)
        this.gui.OnEvent("Close", (*) => this.onClose())

        ; Toolbar
        this.btnStart := this.gui.AddButton("w80 h28", "Run Flow")
        this.btnStart.OnEvent("Click", (*) => this.startFlow(this.flowId))

        this.btnStop := this.gui.AddButton("x+10 w80 h28", "Stop Flow")
        this.btnStop.OnEvent("Click", (*) => this.stopFlow())

        ; Canvas placeholder / GDI+ viewport
        this.canvas := this.gui.AddCustom("ClassStatic x10 y45 w780 h500 +Border")
        this.statusBar := this.gui.AddStatusBar(, "Ready")
    }

    Show() {
        if (this.gui)
            this.gui.Show("w800 h580")
    }

    handleMessage(msg) {
        action := msg.Has("action") ? msg["action"] : ""
        this.receivedEvents.Push(msg)

        if (action == "instance:element_running") {
            elemId := msg["payload"].Has("element_id") ? msg["payload"]["element_id"] : ""
            this.currentHighlightElement := elemId
            if (this.statusBar)
                this.statusBar.SetText("Executing element: " . elemId)
        } else if (action == "instance:element_finished") {
            if (this.statusBar)
                this.statusBar.SetText("Element finished")
        } else if (action == "instance:finished") {
            this.currentHighlightElement := ""
            if (this.statusBar)
                this.statusBar.SetText("Flow execution completed.")
        }
    }

    startFlow(flowId := "") {
        if (flowId == "")
            flowId := this.flowId
        msg := this.ipc.createMessage("command", "engine", "flow:start", Map("flow_id", flowId))
        raw := this.ipc.serialize(msg)
        if (this.statusBar)
            this.statusBar.SetText("Starting flow " . flowId . "...")
        return raw
    }

    stopFlow(instanceId := "") {
        msg := this.ipc.createMessage("command", "engine", "flow:stop", Map("instance_id", instanceId))
        raw := this.ipc.serialize(msg)
        if (this.statusBar)
            this.statusBar.SetText("Stopping flow...")
        return raw
    }

    shutdownSystem() {
        msg := this.ipc.createMessage("command", "engine", "system:shutdown", Map())
        return this.ipc.serialize(msg)
    }

    onClose() {
        this.gui.Hide()
    }
}
