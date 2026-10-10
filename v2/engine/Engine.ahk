#Requires AutoHotkey v2.0
#Include ../lib/NamedPipeIPC.ahk
#Include ../lib/ElementBase.ahk
#Include ../Source_Common/Flows/FlowStorage.ahk
#Include ../Source_Common/Expressions/ExpressionEvaluator.ahk
#Include ../Source_Common/Language/Language.ahk

class FlowInstance {
    __New(instanceId, flowId, flowData, clientName) {
        this.id := instanceId
        this.flowId := flowId
        this.data := flowData
        this.client := clientName
        this.state := "running" ; "running", "stopped", "finished", "error"
        this.variables := Map()
        this.conditionResults := Map()
        this.currentElementId := ""
    }

    SetVariable(varName, val) {
        this.variables[varName] := val
    }

    GetVariable(varName, defaultVal := "") {
        return this.variables.Has(varName) ? this.variables[varName] : defaultVal
    }
}

class EngineProcess {
    __New() {
        this.ipc := NamedPipeIPC("engine", (msg) => this.handleMessage(msg))
        this.flows := Map()
        this.activeInstances := Map()
        this.registeredTriggers := Map()
        this.elementClasses := Map()
        this.isShuttingDown := false

        Language.Init("en")
    }

    RegisterElementClass(className, clsObj) {
        this.elementClasses[className] := clsObj
    }

    handleMessage(msg) {
        action := msg.Has("action") ? msg["action"] : ""
        from := msg.Has("from") ? msg["from"] : ""
        type := msg.Has("type") ? msg["type"] : ""
        corrId := msg.Has("id") ? msg["id"] : ""

        if (action == "system:shutdown") {
            this.shutdown(from, corrId)
        } else if (action == "flow:load") {
            path := msg["payload"].Has("filepath") ? msg["payload"]["filepath"] : ""
            flowData := FlowStorage.LoadFlow(path)
            flowId := msg["payload"].Has("flow_id") ? msg["payload"]["flow_id"] : "flow_" . A_TickCount
            this.flows[flowId] := flowData
            resp := this.ipc.createMessage("response", from, "flow:load_ack", Map("flow_id", flowId, "status", "loaded"), corrId)
            this.sendToClient(resp)
        } else if (action == "flow:start") {
            flowId := msg["payload"].Has("flow_id") ? msg["payload"]["flow_id"] : "flow_default"
            triggerId := msg["payload"].Has("trigger_id") ? msg["payload"]["trigger_id"] : "manual"
            instId := this.startFlow(flowId, triggerId, from)
            resp := this.ipc.createMessage("response", from, "flow:start_ack", Map("instance_id", instId, "status", "started"), corrId)
            this.sendToClient(resp)
        } else if (action == "flow:stop") {
            instId := msg["payload"].Has("instance_id") ? msg["payload"]["instance_id"] : ""
            this.stopFlow(instId)
            resp := this.ipc.createMessage("response", from, "flow:stop_ack", Map("instance_id", instId, "status", "stopped"), corrId)
            this.sendToClient(resp)
        } else if (action == "trigger:register") {
            trigKey := msg["payload"].Has("trigger_key") ? msg["payload"]["trigger_key"] : ""
            flowId := msg["payload"].Has("flow_id") ? msg["payload"]["flow_id"] : ""
            this.registeredTriggers[trigKey] := flowId
            resp := this.ipc.createMessage("response", from, "trigger:register_ack", Map("status", "registered"), corrId)
            this.sendToClient(resp)
        }
    }

    startFlow(flowId, triggerId := "manual", clientName := "editor_1") {
        instId := "inst_" . A_TickCount . "_" . Random(100, 999)
        flowData := this.flows.Has(flowId) ? this.flows[flowId] : Map("elements", [], "connections", [])

        inst := FlowInstance(instId, flowId, flowData, clientName)
        this.activeInstances[instId] := inst

        evtCreated := this.ipc.createMessage("event", clientName, "instance:created", Map("instance_id", instId, "flow_id", flowId))
        this.sendToClient(evtCreated)

        ; Asynchronously run flow graph
        SetTimer(() => this.executeFlowGraph(instId), -1)
        return instId
    }

    executeFlowGraph(instId) {
        if (!this.activeInstances.Has(instId))
            return

        inst := this.activeInstances[instId]
        clientName := inst.client
        elements := inst.data.Has("elements") ? inst.data["elements"] : []

        for idx, elemMap in elements {
            if (this.isShuttingDown || inst.state != "running")
                break

            elemId := elemMap.Has("id") ? elemMap["id"] : "elem_" . idx
            elemType := elemMap.Has("type") ? elemMap["type"] : "ElementBase"
            inst.currentElementId := elemId

            evtRun := this.ipc.createMessage("event", clientName, "instance:element_running", Map("instance_id", instId, "element_id", elemId))
            this.sendToClient(evtRun)

            ; Safe execution wrapped in try/catch to ensure Engine process safety
            status := "normal"
            errMsg := ""
            try {
                if this.elementClasses.Has(elemType) {
                    clsObj := this.elementClasses[elemType]
                    elemObj := clsObj()
                    elemObj.run(inst, elemMap.Has("parameters") ? elemMap["parameters"] : Map())
                }
            } catch err {
                status := "exception"
                errMsg := err.Message
                Logger.Log("Engine", "Error executing element " . elemId . ": " . errMsg)
            }

            evtFinish := this.ipc.createMessage("event", clientName, "instance:element_finished", Map("instance_id", instId, "element_id", elemId, "status", status, "error", errMsg))
            this.sendToClient(evtFinish)
        }

        if (this.activeInstances.Has(instId) && inst.state == "running") {
            inst.state := "finished"
            evtFinished := this.ipc.createMessage("event", clientName, "instance:finished", Map("instance_id", instId, "status", "success"))
            this.sendToClient(evtFinished)
        }
    }

    stopFlow(instId) {
        if (this.activeInstances.Has(instId)) {
            inst := this.activeInstances[instId]
            inst.state := "stopped"
        }
    }

    shutdown(from, corrId) {
        this.isShuttingDown := true
        for instId, inst in this.activeInstances {
            this.stopFlow(instId)
        }
        resp := this.ipc.createMessage("response", from, "system:shutdown_ack", Map("status", "ok"), corrId)
        this.sendToClient(resp)
    }

    sendToClient(msgMap) {
        raw := this.ipc.serialize(msgMap)
        return raw
    }
}
