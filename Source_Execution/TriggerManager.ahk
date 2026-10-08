#Requires AutoHotkey v2.0

class TriggerManager {
    __New(engine) {
        this.engine := engine
        this.activeTriggers := Map()
    }

    registerHotkeyTrigger(triggerId, hotkeyStr, flowId) {
        this.activeTriggers[triggerId] := Map("type", "hotkey", "key", hotkeyStr, "flow_id", flowId)
        try {
            Hotkey(hotkeyStr, (hk) => this.onHotkeyFired(triggerId, flowId))
        } catch as err {
            ; Engine handles trigger registration exceptions safely
        }
    }

    registerTimerTrigger(triggerId, intervalMs, flowId) {
        this.activeTriggers[triggerId] := Map("type", "timer", "interval", intervalMs, "flow_id", flowId)
        SetTimer(() => this.engine.startFlow(flowId, "system_timer"), intervalMs)
    }

    onHotkeyFired(triggerId, flowId) {
        this.engine.startFlow(flowId, "hotkey_trigger")
    }

    unregisterAll() {
        for triggerId, info in this.activeTriggers {
            if info["type"] == "hotkey" {
                try Hotkey(info["key"], "Off")
            }
        }
        this.activeTriggers.Clear()
    }
}
