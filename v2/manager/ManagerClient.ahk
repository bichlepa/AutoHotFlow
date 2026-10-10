#Requires AutoHotkey v2.0
#Include ../lib/NamedPipeIPC.ahk

class ManagerClient {
    __New() {
        this.ipc := NamedPipeIPC("manager", (msg) => this.handleMessage(msg))
        this.flowsList := []

        this.initGui()
    }

    initGui() {
        this.gui := Gui("+Resize", "AutoHotFlow v2 Manager")
        this.gui.OnEvent("Close", (*) => this.onClose())

        ; TreeView / Flow list
        this.tree := this.gui.AddTreeView("w250 h400")

        ; Action buttons
        this.btnNew := this.gui.AddButton("x270 y10 w100 h28", "New Flow")
        this.btnEdit := this.gui.AddButton("x270 y45 w100 h28", "Edit Flow")
        this.btnRun := this.gui.AddButton("x270 y80 w100 h28", "Run Selected")
        this.btnRun.OnEvent("Click", (*) => this.runSelectedFlow())

        this.statusBar := this.gui.AddStatusBar(, "Engine connected")
    }

    Show() {
        if (this.gui)
            this.gui.Show("w400 h450")
    }

    handleMessage(msg) {
        action := msg.Has("action") ? msg["action"] : ""
        if (action == "flow:updated" || action == "flow:list_response") {
            this.updateFlowList(msg["payload"])
        }
    }

    runSelectedFlow() {
        msg := this.ipc.createMessage("command", "engine", "flow:start", Map("flow_id", "flow_selected"))
        return this.ipc.serialize(msg)
    }

    updateFlowList(payload) {
        if (this.tree) {
            this.tree.Delete()
            parent := this.tree.Add("Flows")
            this.tree.Add("Demo Flow 1", parent)
        }
    }

    onClose() {
        this.gui.Hide()
    }
}
