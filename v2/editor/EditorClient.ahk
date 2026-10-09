#Requires AutoHotkey v2.0
#Include ../lib/NamedPipeIPC.ahk

class EditorClient {
    __New() {
        this.ipc := NamedPipeIPC("editor_1", (msg) => this.handleMessage(msg))
        this.receivedEvents := []
    }

    handleMessage(msg) {
        action := msg.Has("action") ? msg["action"] : ""
        this.receivedEvents.Push(msg)
    }

    startFlow(flowId) {
        msg := this.ipc.createMessage("command", "engine", "flow:start", Map("flow_id", flowId))
        return this.ipc.serialize(msg)
    }

    stopFlow(instanceId) {
        msg := this.ipc.createMessage("command", "engine", "flow:stop", Map("instance_id", instanceId))
        return this.ipc.serialize(msg)
    }

    shutdownSystem() {
        msg := this.ipc.createMessage("command", "engine", "system:shutdown", Map())
        return this.ipc.serialize(msg)
    }
}
