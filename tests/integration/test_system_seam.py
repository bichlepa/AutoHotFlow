"""WI-0117 (E0103): the actions that disturb the computer go through SystemOps (ELEMENT-API-V2 3.3a). In a real session
the worker and the trigger host record every call and answer it from the script (TestSystemProvider); no real function
runs, so nothing shuts down, locks, ejects, plays a sound or blocks the input.
"""

import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner, flows  # noqa: F401  (fixture)
from support.system import SystemScript, error, value
from support.timing import scaled

HOST_ROLES = "storage,engine,triggerhost"

# One function of each group of SystemOps (power, drives, recycle bin, screen, sound, speech, input, idle time), with
# the arguments of the test element (Action_TestSystemWorker: Function, Arg1, Arg2).
GROUP_CALLS = [
    ("Shutdown", "1", ""),
    ("DriveEject", "E:", ""),
    ("FileRecycleEmpty", "C:\\", ""),
    ("MonitorCount", "", ""),
    ("SoundBeep", "", ""),
    ("SpeakText", "hello", ""),
    ("Send", "{Enter}", "Input"),
    ("TimeIdle", "", ""),
]
IDLE_BASE_MS = 5000


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def _worker_flow(calls):
    fb = FlowBuilder("system")
    elements = [fb.action("Action_TestSystemWorker", Tag="c%d" % i, Function=fn, Arg1=a1, Arg2=a2)
                for i, (fn, a1, a2) in enumerate(calls)]
    fb.chain(fb.trigger(), *elements)
    return fb, elements


def test_one_function_of_each_group_is_recorded_and_answered_in_a_worker(flows):
    system = SystemScript(flows.datadir)
    system.script({"Shutdown": [value(1)]}, idle_base_ms=IDLE_BASE_MS)
    fb, elements = _worker_flow(GROUP_CALLS)
    flow_id = flows.add(fb)
    run = flows.run(flow_id, timeout=30)
    assert run.reason == "finished" and not run.exceptions, run.steps

    calls = system.requests()
    assert [c["function"] for c in calls] == [fn for fn, _a1, _a2 in GROUP_CALLS]
    assert {c["role"] for c in calls} == {"worker"}, "the calls ran in a worker, not in the engine"
    assert [c["element"] for c in calls] == [el.id for el in elements]
    assert {c["flow"] for c in calls} == {flow_id}
    # the scripted answer and the error-free default of an unscripted function
    assert [c["scripted"] for c in calls] == [True, False, False, False, False, False, False, True]
    assert calls[0]["answer"] == 1
    assert calls[1]["answer"] == 0, "an unscripted call returns the empty value and does nothing real"
    assert calls[6]["args"] == ["{Enter}", "Input"]
    # the idle time grows from the script's base (the clock of the test)
    assert calls[7]["answer"] >= IDLE_BASE_MS
    assert flows.wait_var("global_system_c0_result")[1] == "1"


def test_a_scripted_error_ends_the_element_with_exception(flows):
    system = SystemScript(flows.datadir)
    system.script({"LockWorkStation": [error("no session to lock")]})
    fb, _elements = _worker_flow([("LockWorkStation", "", "")])
    run = flows.run(flows.add(fb), timeout=30)
    assert run.exceptions and "no session to lock" in run.exceptions[0], run.steps
    assert "no session to lock" in system.requests()[0]["error"]


def test_a_trigger_in_the_trigger_host_records_its_call(host_flows):
    system = SystemScript(host_flows.datadir)
    system.script({"SoundBeep": [value(1)]})
    fb = FlowBuilder("system trigger")
    trigger = fb.trigger("Test.Trigger_TestSystemCall", Function="SoundBeep")
    flow_id = host_flows.add(fb)
    host_flows.start()          # the session with the trigger host; the flow is enabled through it
    host_flows.enable(flow_id)

    deadline = time.monotonic() + scaled(10)
    found = []
    while time.monotonic() < deadline and not found:
        found = [c for c in system.requests() if c["function"] == "SoundBeep"]
        time.sleep(0.1)
    assert found, "the trigger did not call the seam within the time limit"
    call = found[0]
    assert call["role"] == "triggerhost", "a trigger calls the seam in the trigger host"
    assert call["element"] == trigger.id
    assert call["flow"] == flow_id
