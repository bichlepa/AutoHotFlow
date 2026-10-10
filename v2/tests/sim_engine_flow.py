import json

# Python verification script simulating the AHK v2 Engine & Editor Pipe message flow

class EngineProcess:
    def __init__(self):
        self.active_instances = {}
        self.emitted_events = []

    def receive_message(self, msg_str):
        msg = json.loads(msg_str)
        action = msg.get("action")
        sender = msg.get("from")
        corr_id = msg.get("id")

        if action == "flow:start":
            flow_id = msg["payload"].get("flow_id", "flow_default")
            inst_id = f"inst_{flow_id}_999"
            self.active_instances[inst_id] = {"flow_id": flow_id, "state": "running"}

            # Send ack
            self.emitted_events.append({
                "type": "response", "from": "engine", "to": sender,
                "action": "flow:start_ack", "correlation_id": corr_id,
                "payload": {"instance_id": inst_id, "status": "started"}
            })

            # Execute 3 elements: Trigger -> Action1 -> Action2
            elements = ["trigger_manual_1", "action_msgbox_1", "action_sleep_2"]
            for elem_id in elements:
                self.emitted_events.append({
                    "type": "event", "from": "engine", "to": sender,
                    "action": "instance:element_running",
                    "payload": {"instance_id": inst_id, "element_id": elem_id}
                })
                self.emitted_events.append({
                    "type": "event", "from": "engine", "to": sender,
                    "action": "instance:element_finished",
                    "payload": {"instance_id": inst_id, "element_id": elem_id, "status": "normal"}
                })

            self.active_instances[inst_id]["state"] = "finished"
            self.emitted_events.append({
                "type": "event", "from": "engine", "to": sender,
                "action": "instance:finished",
                "payload": {"instance_id": inst_id, "status": "success"}
            })

        elif action == "system:shutdown":
            for inst_id in self.active_instances:
                self.active_instances[inst_id]["state"] = "stopped"
            self.emitted_events.append({
                "type": "response", "from": "engine", "to": sender,
                "action": "system:shutdown_ack", "correlation_id": corr_id,
                "payload": {"status": "ok"}
            })

engine = EngineProcess()
start_cmd = json.dumps({
    "id": "editor-1", "type": "command", "from": "editor_1", "to": "engine",
    "action": "flow:start", "payload": {"flow_id": "flow_demo_3_elements"}
})
engine.receive_message(start_cmd)

print(f"Total events emitted by Engine: {len(engine.emitted_events)}")
for ev in engine.emitted_events:
    print(f"  [{ev['type']}] {ev['action']} -> {ev['payload']}")
