"""WI-0131: Trigger_Clipboard_Changes in a real session (storage, engine, triggerhost; OnClipboardChange in the trigger
host). The real Windows clipboard is used: the fixture saves the text of the user before each test and puts it back after
it. All tests of this file share the xdist group `clipboard`, so they never use the clipboard at the same time.
"""

import time
import uuid

import pytest

from support.clipboard import restore, set_text, snapshot
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled
from support.triggerwait import wait_armed

pytestmark = pytest.mark.xdist_group("clipboard")

HOST_ROLES = "storage,engine,triggerhost"


@pytest.fixture(autouse=True)
def clipboard_kept():
    """The clipboard of the user is put back after every test of this file."""
    items = snapshot()
    yield
    restore(items)


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def clipboard_flow(name):
    fb = FlowBuilder(name)
    trigger = fb.trigger("Trigger_Clipboard_Changes")
    done = fb.action("Action_Do_nothing")
    fb.chain(trigger, done)
    return fb, trigger


def test_every_change_of_the_clipboard_fires_the_trigger(host_flows):
    fb, trigger = clipboard_flow("Clipboard changes")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
    set_text("AHF clipboard trigger 1 " + uuid.uuid4().hex)
    assert len(host_flows.ended(fid, count=1, timeout=scaled(10.0))) >= 1, host_flows.stderr_text()
    set_text("AHF clipboard trigger 2 " + uuid.uuid4().hex)
    assert len(host_flows.ended(fid, count=2, timeout=scaled(10.0))) >= 2, host_flows.stderr_text()


def test_a_disabled_clipboard_trigger_does_not_fire(host_flows):
    fb, trigger = clipboard_flow("Clipboard disabled")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": fid})
    assert wait_armed(host_flows, fid, trigger.id, armed=False), host_flows.stderr_text()
    since = host_flows.mark()
    set_text("AHF clipboard trigger 3 " + uuid.uuid4().hex)
    time.sleep(scaled(1.0))
    assert host_flows.ended(fid, since=since, count=0, timeout=0) == [], "fired after the disable"
