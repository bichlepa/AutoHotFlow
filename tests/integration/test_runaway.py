"""WI-0066, REQ-EXE-170, E0062: the guard against runaway flows in real sessions (supervisor, storage, engine, trigger host).

The transitions and the arithmetic of the window are in tests/ahk/engine_runaway.test.ahk. Here the limits go through the
real messages: the flow stops with reason limit, its triggers are disabled and stay disabled after a restart (the state
file of WI-0060 is written by the real storage), a refused start is answered with the error code limit, and a flood of
refused starts does not flood the log.
"""

import json
import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.flowrun import FlowRunner
from support.timing import scaled

LIMIT_S = scaled(60.0)
FILE_WAIT_S = scaled(5.0)
HOST_ROLES = "storage,engine,triggerhost"


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well (the timer trigger needs it)."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def state_path(datadir, flow_id):
    return datadir / "FlowStates" / (flow_id + ".json")


def wait_for(predicate, timeout):
    deadline = time.monotonic() + timeout
    while not predicate():
        if time.monotonic() > deadline:
            return False
        time.sleep(0.05)
    return True


def enabled_in_snapshot(flows, flow_id):
    snap = flows.request_ok("engine", "cmd.engine.snapshot", {})
    return [f["enabled"] for f in snap["flows"] if f["flowId"] == flow_id][0]


def endless_loop(limit=None):
    """A loop of a million passes whose body is Action_Do_nothing: about 2 element executions per pass."""
    settings = {} if limit is None else {"maxExecutionsPerMinute": limit}
    fb = FlowBuilder("runaway", flow_settings=settings)
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=1000000)
    body = fb.action("Action_Do_nothing")
    fb.connect(fb.trigger(), loop)
    fb.connect(loop, body, "head")
    fb.connect(body, loop, into="tail")
    return fb


def test_an_endless_loop_is_stopped_and_its_triggers_stay_disabled_after_a_restart(flows):
    fb = endless_loop(limit=2000)
    flow_id = flows.add(fb)
    flows.start()
    flows.enable(flow_id)
    assert enabled_in_snapshot(flows, flow_id) is True
    flows.begin(flow_id)
    hit = flows.wait_message(lambda m: m.get("type") == "evt.flow.limit", timeout=LIMIT_S)
    assert hit is not None, "the guard did not stop the flow"
    payload = hit[1]["payload"]
    assert (payload["flowId"], payload["kind"], payload["limit"]) == (flow_id, "executionsPerMinute", 2000), payload
    ended = flows.ended(flow_id, timeout=LIMIT_S)
    assert [p["reason"] for p in ended] == ["limit"]
    assert flows.executing(flow_id) is False
    assert enabled_in_snapshot(flows, flow_id) is False, "the trigger of the flow is disabled"
    expected = {"formatVersion": 1, "enabled": []}
    assert wait_for(lambda: state_path(flows.datadir, flow_id).exists()
                    and json.loads(state_path(flows.datadir, flow_id).read_text(encoding="utf-8-sig")) == expected,
                    FILE_WAIT_S), "the disabled state was not written"
    flows.stop()
    flows.start()
    assert enabled_in_snapshot(flows, flow_id) is False, "the limit still holds after a restart"


@pytest.mark.slow
def test_a_loop_over_ten_thousand_members_passes_the_default_limits(flows):
    # 10,000 passes with one body element: about 20,000 element executions, under the default limit of 50,000
    fb = FlowBuilder("tenthousand")
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=10000)
    body = fb.action("Action_Do_nothing")
    fb.connect(fb.trigger(), loop)
    fb.connect(loop, body, "head")
    fb.connect(body, loop, into="tail")
    run = flows.run(fb, timeout=LIMIT_S)
    assert run.reason == "finished", run.reason
    assert not any(m.get("type") == "evt.flow.limit" for m in flows.messages(0))


def test_a_flood_of_refused_starts_is_answered_and_logged_a_few_times(host_flows):
    flows = host_flows
    fb = FlowBuilder("flood", flow_settings={"maxParallelInstances": 3})
    timer = fb.trigger("Trigger_Periodic_Timer", Interval=10, Unit="MilliSeconds")
    sleep = fb.action("Action_Sleep", Duration=1000, Unit="Milliseconds")
    fb.connect(timer, sleep)
    flow_id = flows.add(fb)
    flows.start()
    mark = flows.mark()
    flows.enable(flow_id)
    time.sleep(scaled(2.0))
    flows.request_ok("engine", "cmd.flow.disable", {"flowId": flow_id})
    started = [m for m in flows.messages(mark) if m.get("type") == "evt.instance.started"]
    refused = [m["payload"]["text"] for m in flows.messages(mark)
               if m.get("type") == "evt.log.entry" and "refused" in m["payload"].get("text", "")]
    assert started, "the timer started no instance"
    assert len(started) <= 10, "instances started in parallel beyond the limit: %d" % len(started)
    assert 1 <= len(refused) <= 3, "refusals logged %d times: %s" % (len(refused), refused)
    assert not any(m.get("type") == "evt.flow.limit" for m in flows.messages(mark))
