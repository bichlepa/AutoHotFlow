"""WI-50: faults while a worker element asks the engine for variables (cmd.engine.var.*, PROTOCOL 4.5).

A worker element (Action_TestVarBenchWorker with a large Count) asks the engine all the time; the test kills the
engine or the worker in the middle. Expected (acceptance of WI-50): no process hangs (the flow runner fails the test
for a process left behind), the engine has no unhandled error, and the next worker job runs.
"""

import time

import psutil
import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.timing import scaled

pytestmark = pytest.mark.slow


def _asking_flow(flows):
    fb = FlowBuilder("asking")
    element = fb.action("Action_TestVarBenchWorker", Count=1000000, Tag="faults")
    fb.chain(fb.trigger(), element)
    echo = FlowBuilder("echo")
    echo.chain(echo.trigger(), echo.action("Action_TestEchoWorker"))
    return fb, element, flows.add(echo)


def _wait_running(flows, run, element):
    found = flows._rec.wait(lambda m: m.get("type") == "evt.element.state" and m["payload"].get("elementId")
                            == element.id and m["payload"].get("state") == "running", scaled(10), run._mark)
    assert found, "the worker element did not start"
    time.sleep(0.3)         # it asks a few hundred times by now


def _processes(flows):
    return {p["name"]: p for p in flows.request_ok("supervisor", "cmd.process.list", {})["processes"]}


def _engine_errors(flows):
    return flows.request_ok("engine", "cmd.diag.snapshot", {})["snapshot"]["errors"]


def _wait_until(predicate, timeout):
    end = time.monotonic() + scaled(timeout)
    while time.monotonic() < end:
        try:
            value = predicate()
        except Exception:
            value = None
        if value:
            return value
        time.sleep(0.1)
    return None


def test_engine_killed_while_a_worker_element_asks(flows):
    fb, element, echo_id = _asking_flow(flows)
    run = flows.begin(fb)
    _wait_running(flows, run, element)
    old = _processes(flows)["engine"]
    psutil.Process(old["pid"]).kill()

    def restarted():
        engine = _processes(flows).get("engine")
        return engine and engine["state"] == "ready" and engine["pid"] != old["pid"]
    assert _wait_until(restarted, 20), _processes(flows)
    assert _wait_until(lambda: echo_id in {f["flowId"] for f in flows.request_ok(
        "engine", "cmd.engine.snapshot", {})["flows"]}, 20), "the new engine did not load the flows"
    # the workers of the old engine are gone (E10, orphans of the new engine), the new pool takes the next job
    again = flows.run(echo_id, timeout=20)
    assert again.reason == "finished" and not again.exceptions, again.steps
    assert _engine_errors(flows)["count"] == 0, _engine_errors(flows)


def test_worker_killed_while_its_element_asks(flows):
    fb, element, echo_id = _asking_flow(flows)
    run = flows.begin(fb)
    _wait_running(flows, run, element)
    slots = flows.request_ok("engine", "cmd.diag.snapshot", {})["snapshot"]["info"]["workers"]["slots"]
    busy = [s["name"] for s in slots if s["execId"]]
    assert len(busy) == 1, slots
    psutil.Process(_processes(flows)[busy[0]]["pid"]).kill()
    flows.wait(run, timeout=10)
    assert run.reason == "exception", run.reason
    assert run.exceptions == ["worker crashed (%s)" % busy[0]], run.steps
    again = flows.run(echo_id, timeout=20)
    assert again.reason == "finished" and not again.exceptions, again.steps
    assert _engine_errors(flows)["count"] == 0, _engine_errors(flows)
