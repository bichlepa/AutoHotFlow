import unittest
import json
import time

class ResilientIPCClient:
    def __init__(self, name, timeout_sec=1.0):
        self.name = name
        self.timeout_sec = timeout_sec
        self.pending_requests = {}
        self.connected = True
        self.msg_counter = 0

    def send_rpc(self, target, action, payload):
        if not self.connected:
            raise ConnectionError("Pipe connection broken!")

        self.msg_counter += 1
        msg_id = f"{self.name}-{self.msg_counter}"
        request = {
            "id": msg_id,
            "type": "command",
            "from": self.name,
            "to": target,
            "action": action,
            "payload": payload
        }
        self.pending_requests[msg_id] = {"req": request, "time": time.time()}
        return msg_id

    def receive_response(self, response_msg):
        corr_id = response_msg.get("correlation_id")
        if corr_id in self.pending_requests:
            del self.pending_requests[corr_id]
            return True
        return False

    def check_timeouts(self):
        now = time.time()
        timed_out = []
        for msg_id, data in self.pending_requests.items():
            if now - data["time"] >= self.timeout_sec:
                timed_out.append(msg_id)
        for msg_id in timed_out:
            del self.pending_requests[msg_id]
        return timed_out


class TestIPCResilience(unittest.TestCase):
    def test_client_disconnect_does_not_crash_engine(self):
        client = ResilientIPCClient("editor_1")
        req_id = client.send_rpc("engine", "flow:start", {"flow_id": "f_100"})
        self.assertIn(req_id, client.pending_requests)

        # Simulate abrupt process crash / pipe disconnect
        client.connected = False
        with self.assertRaises(ConnectionError):
            client.send_rpc("engine", "flow:stop", {"instance_id": "inst_1"})

    def test_rpc_request_timeout(self):
        client = ResilientIPCClient("editor_1", timeout_sec=0.1)
        req_id = client.send_rpc("engine", "slow:operation", {})

        time.sleep(0.15)
        timed_out = client.check_timeouts()
        self.assertIn(req_id, timed_out)
        self.assertNotIn(req_id, client.pending_requests)

if __name__ == "__main__":
    unittest.main()
