"""Waiting for the armed state of a trigger in a running session (cmd.engine.snapshot), for the hotkey tests."""

import time

from support.timing import scaled

WAIT_S = 10.0


def trigger_state(runner, flow_id, element_id):
    try:
        answer = runner.request_ok("engine", "cmd.engine.snapshot", {})
    except Exception:
        return None
    for flow in answer["flows"]:
        if flow["flowId"] == flow_id:
            for t in flow.get("triggers", []):
                if t["elementId"] == element_id:
                    return t
    return None


def wait_armed(runner, flow_id, element_id, armed=True, timeout=WAIT_S):
    deadline = time.monotonic() + scaled(timeout)
    while time.monotonic() < deadline:
        state = trigger_state(runner, flow_id, element_id)
        if state is not None and state["armed"] is armed:
            return state
        time.sleep(0.05)
    return None
