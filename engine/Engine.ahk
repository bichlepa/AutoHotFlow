#Requires AutoHotkey v2.0
#Include ../lib/NamedPipeIPC.ahk
#Include ../lib/ElementBase.ahk

class EngineProcess {
    __New() {
        this.ipc := NamedPipeIPC("engine", (msg) => this.handleMessage(msg))
        this.activeInstances := Map()
        this.clientConnected := false
        this.isShuttingDown := false
    }

    handleMessage(msg) {
        action := msg.Has("action") ? msg["action"] : ""
        from := msg.Has("from") ? msg["from"] : ""
        type := msg.Has("type") ? msg["type"] : ""
        corrId := msg.Has("id") ? msg["id"] : ""

        if (action == "system:shutdown") {
            this.shutdown(from, corrId)
        } else if (action == "flow:start") {
            flowId := msg["payload"].Has("flow_id") ? msg["payload"]["flow_id"] : "flow_default"
            instId := this.startFlow(flowId, from)
            resp := this.ipc.createMessage("response", from, "flow:start_ack", Map("instance_id", instId, "status", "started"), corrId)
            this.sendToClient(resp)
        } else if (action == "flow:stop") {
            instId := msg["payload"].Has("instance_id") ? msg["payload"]["instance_id"] : ""
            this.stopFlow(instId)
            resp := this.ipc.createMessage("response", from, "flow:stop_ack", Map("instance_id", instId, "status", "stopped"), corrId)
            this.sendToClient(resp)
        }
    }

    startFlow(flowId, clientName) {
        instId := "inst_" . A_TickCount
        this.activeInstances[instId] := Map("flow_id", flowId, "state", "running", "client", clientName)

        evtCreated := this.ipc.createMessage("event", clientName, "instance:created", Map("instance_id", instId, "flow_id", flowId))
        this.sendToClient(evtCreated)

        ; Execute elements of the flow asynchronously
        this.executeFlowElements(instId, flowId, clientName)
        return instId
    }

    executeFlowElements(instId, flowId, clientName) {
        elements := ["elem_trigger_1", "elem_action_1", "elem_action_2"]
        for idx, elemId in elements {
            if (this.isShuttingDown || !this.activeInstances.Has(instId) || this.activeInstances[instId]["state"] != "running")
                break

            evtRun := this.ipc.createMessage("event", clientName, "instance:element_running", Map("instance_id", instId, "element_id", elemId))
            this.sendToClient(evtRun)

            evtFinish := this.ipc.createMessage("event", clientName, "instance:element_finished", Map("instance_id", instId, "element_id", elemId, "status", "normal"))
            this.sendToClient(evtFinish)
        }

        if (this.activeInstances.Has(instId)) {
            this.activeInstances[instId]["state"] := "finished"
            evtFinished := this.ipc.createMessage("event", clientName, "instance:finished", Map("instance_id", instId, "status", "success"))
            this.sendToClient(evtFinished)
        }
    }

    stopFlow(instId) {
        if (this.activeInstances.Has(instId)) {
            this.activeInstances[instId]["state"] := "stopped"
        }
    }

    shutdown(from, corrId) {
        this.isShuttingDown := true
        for instId, data in this.activeInstances {
            this.stopFlow(instId)
        }
        resp := this.ipc.createMessage("response", from, "system:shutdown_ack", Map("status", "ok"), corrId)
        this.sendToClient(resp)
    }

    sendToClient(msgMap) {
        raw := this.ipc.serialize(msgMap)
        ; In production, writes to Named Pipe handle.
        return raw
    }
}
