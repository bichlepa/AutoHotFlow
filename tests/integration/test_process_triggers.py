"""WI-0132: the process triggers Trigger_Process_starts and Trigger_Process_Closes in a real session (storage, engine,
triggerhost; WatchPoll and ProcessSnapshot).

Every process a test starts or ends is its own: a copy of cmd.exe under a unique name (support/ownprocess.py). The name
is the filter of the trigger, so no process of the user can match it. The variables A_ProcessID and A_ProcessName are
read with a probe of the flow.
"""

import time

import pytest

from support import ownprocess
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled
from support.triggerwait import trigger_state, wait_armed

HOST_ROLES = "storage,engine,triggerhost"
POLL_MS = "100"
QUIET_S = 1.5


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


@pytest.fixture
def own_folder(tmp_path):
    """The folder of the copies. Every process a test starts is ended at the end of the test."""
    started = []
    yield tmp_path, started
    for proc in started:
        if proc.alive():
            proc.end()


def start_own(own_folder, name=None):
    """Starts an own process (a copy under the name) and keeps it for the end of the test."""
    folder, started = own_folder
    proc = ownprocess.start_named_copy(folder, name)
    started.append(proc)
    return proc


def process_flow(name, cls, **pars):
    """trigger -> probe of A_ProcessID and A_ProcessName -> done."""
    fb = FlowBuilder(name)
    trigger = fb.trigger(cls, **pars)
    probe = fb.probe("A_ProcessID", "A_ProcessName")
    fb.chain(trigger, probe, fb.action("Action_Do_nothing"))
    return fb, trigger


def arm(host_flows, flow_id):
    host_flows.start()
    host_flows.enable(flow_id)


def wait_state(host_flows, flow_id, element_id, pred, timeout=10.0):
    """The trigger state (snapshot) once pred(state) holds, or None after the timeout."""
    deadline = time.monotonic() + scaled(timeout)
    while time.monotonic() < deadline:
        state = trigger_state(host_flows, flow_id, element_id)
        if state is not None and pred(state):
            return state
        time.sleep(0.05)
    return None


def test_a_started_process_fires_starts_with_its_id_and_name(host_flows, own_folder):
    name = ownprocess.new_name()                    # the filter is armed before the process exists
    fb, trigger = process_flow("Process starts", "Trigger_Process_starts", ProcessName=name, interval=POLL_MS,
                               NotTriggerOnEnable="1")
    fid = host_flows.add(fb)
    arm(host_flows, fid)
    assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
    time.sleep(QUIET_S)
    assert host_flows.ended(fid, count=0, timeout=0) == [], "fired before the process existed"
    proc = start_own(own_folder, name)
    assert len(host_flows.ended(fid, count=1, timeout=scaled(10))) >= 1, host_flows.stderr_text()
    time.sleep(QUIET_S)
    assert int(host_flows.read_probe("A_ProcessID").text) == proc.pid
    assert host_flows.read_probe("A_ProcessName").text == name


def test_a_process_that_runs_at_the_arming_does_not_fire_starts_with_not_trigger_on_enable(host_flows, own_folder):
    proc = start_own(own_folder)
    fb, trigger = process_flow("Process starts running", "Trigger_Process_starts", ProcessName=proc.name,
                               interval=POLL_MS, NotTriggerOnEnable="1")
    fid = host_flows.add(fb)
    arm(host_flows, fid)
    assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
    time.sleep(QUIET_S)
    assert host_flows.ended(fid, count=0, timeout=0) == [], "the process that was running fired"


def test_a_closed_process_fires_closes_with_its_id_and_name(host_flows, own_folder):
    proc = start_own(own_folder)
    pid = proc.pid
    fb, trigger = process_flow("Process closes", "Trigger_Process_Closes", ProcessName=proc.name, interval=POLL_MS)
    fid = host_flows.add(fb)
    arm(host_flows, fid)
    assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
    time.sleep(QUIET_S)
    assert host_flows.ended(fid, count=0, timeout=0) == [], "fired while the process runs"
    proc.end()
    assert len(host_flows.ended(fid, count=1, timeout=scaled(10))) >= 1, host_flows.stderr_text()
    assert int(host_flows.read_probe("A_ProcessID").text) == pid
    assert host_flows.read_probe("A_ProcessName").text == proc.name


def test_the_filter_by_process_id_watches_only_that_process(host_flows, own_folder):
    first = start_own(own_folder)
    second = start_own(own_folder)
    fb, trigger = process_flow("Process closes by ID", "Trigger_Process_Closes", ProcessName=str(first.pid),
                               interval=POLL_MS)
    fid = host_flows.add(fb)
    arm(host_flows, fid)
    assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
    second.end()
    time.sleep(QUIET_S)
    assert host_flows.ended(fid, count=0, timeout=0) == [], "a process that is not the filter fired"
    first.end()
    assert len(host_flows.ended(fid, count=1, timeout=scaled(10))) >= 1, host_flows.stderr_text()


def test_a_bad_interval_of_a_process_trigger_is_not_armed_and_gives_the_v1_text(host_flows):
    fb, trigger = process_flow("Bad process interval", "Trigger_Process_Closes", ProcessName="x.exe", interval="0")
    fid = host_flows.add(fb)
    arm(host_flows, fid)
    state = wait_state(host_flows, fid, trigger.id, lambda s: s["message"] == "Parameter 'interval' has invalid value: 0")
    assert state is not None and state["armed"] is False, state
