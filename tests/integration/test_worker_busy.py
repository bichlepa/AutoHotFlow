"""WI-27: sys.busy. A worker with a job is not pinged and not judged by pongs (ARCHITEKTUR 6.4, PROTOKOLL 4.1)."""

import time

from test_supervisor import alive, event, wait_ready, watch_for
from test_worker_pool import READY_S, ask, clients, started  # noqa: F401  (fixtures)


def run_payload(exec_id, cls):
    return {"execId": exec_id, "class": cls, "params": {}, "imports": {},
            "env": {"flowId": "Flow 1", "elementId": "element0000000001", "instanceId": "inst-1", "threadId": "thr-1"},
            "timeoutMs": 5000}


def done_for(client, exec_id, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for msg in client.events(timeout=0.5):
            if msg.get("type") == "evt.worker.done" and msg["payload"].get("execId") == exec_id:
                return msg["payload"]
    return None


def test_worker_that_blocks_longer_than_the_pong_timeout_is_not_hung_while_it_has_a_job(started, clients):
    """Action_TestLongBlockWorker blocks in one call for 7.5 s (pong timeout 6 s): before WI-27 the heartbeat
    declared the worker hung and ended it (decision of WI-11, 'no tolerance')."""
    sup = started()
    engine = clients(sup.pipe, "engine")
    # a second client watches the process events: two readers on one client would take each other's messages
    watch = watch_for(clients(sup.pipe, "obs"))
    name = ask(engine, "supervisor", "cmd.process.spawn", {"role": "worker"})["name"]
    pid = wait_ready(engine, [name], timeout=READY_S)[name][1]
    assert ask(engine, name, "cmd.worker.run", run_payload("lb1", "Action_TestLongBlockWorker"))["ok"]
    done = done_for(engine, "lb1", timeout=15.0)
    assert done is not None, "no evt.worker.done (hung?):\n" + sup.text()
    assert done["result"] == "normal", done
    assert not watch.find(event("evt.process.hung", name=name)), sup.text()
    assert not watch.find(event("evt.process.crashed", name=name))
    assert alive(pid)
    # idle again: the heartbeat watches it as before (pings are answered)
    pong = ask(engine, name, "sys.ping", {"n": 1}, timeout=3.0)
    assert pong["n"] == 1
    watch.stop()
