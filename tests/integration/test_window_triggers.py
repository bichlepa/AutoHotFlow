"""WI-0132: the window triggers Trigger_Window_Opens, Trigger_Window_Closes, Trigger_Window_Gets_Active and
Trigger_Window_Gets_Inactive in a real session (storage, engine, triggerhost; WatchPoll, WindowWatch).

Every window a test uses is an own window (support/ownwindow.py, a helper Gui with a unique title): no window of the user
is found, activated or closed. The focus is taken under the machine-wide input lock (doc/TEST-STRATEGY.md); the window
that a flow activates is activated by Action_Activate_Window of a manual flow. The variable A_WindowID is read with a
probe of the flow (the value of the instance that fired).
"""

import time
import uuid

import pytest

from support import inputlock, ownwindow
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled
from support.triggerwait import trigger_state, wait_armed

HOST_ROLES = "storage,engine,triggerhost"
POLL_MS = "100"                    # the poll of the tests: short enough to see a change within a second
QUIET_S = 1.5                      # how long a test waits to see that nothing fires


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


@pytest.fixture
def focus(request):
    """The input lock and the focus of the desktop for a test that activates windows (skipped when the desktop is not
    usable)."""
    reason = inputlock.session_skip_reason(inputlock.input_desktop_open(), inputlock.logonui_running())
    if reason:
        pytest.skip(reason)
    with inputlock.input_lock():
        yield


def title_of(prefix="AhfTriggerWindow"):
    return prefix + "-" + uuid.uuid4().hex


def window_flow(name, cls, **pars):
    """trigger -> probe of A_WindowID -> done. The trigger is the window trigger with the parameters."""
    fb = FlowBuilder(name)
    trigger = fb.trigger(cls, **pars)
    probe = fb.probe("A_WindowID")
    done = fb.action("Action_Do_nothing")
    fb.chain(trigger, probe, done)
    return fb, trigger


def window_pars(title, **extra):
    pars = {"Wintitle": title, "TitleMatchMode": "3", "interval": POLL_MS, "NotTriggerOnEnable": "1"}
    pars.update(extra)
    return pars


def activate(host_flows, title):
    """Runs a manual flow that activates the own window with the title (Action_Activate_Window, WI-0125)."""
    fb = FlowBuilder("activate " + title)
    fb.chain(fb.trigger(), fb.action("Action_Activate_Window", Wintitle=title, TitleMatchMode="3"),
             fb.action("Action_Do_nothing"))
    fid = host_flows.add(fb)
    run = host_flows.run(fid, timeout=scaled(20))
    assert run.reason == "finished" and not run.exceptions, (run.reason, run.exceptions, host_flows.stderr_text())


def arm(host_flows, flow_id):
    """Starts the session and enables the flow (its trigger is armed by the engine)."""
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


def test_a_new_window_fires_once_and_gives_its_id(host_flows, tmp_path):
    title = title_of()
    fb, trigger = window_flow("Window opens", "Trigger_Window_Opens", **window_pars(title))
    fid = host_flows.add(fb)
    arm(host_flows, fid)
    assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
    window = ownwindow.start(tmp_path, title=title)
    try:
        assert len(host_flows.ended(fid, count=1, timeout=scaled(10))) >= 1, host_flows.stderr_text()
        time.sleep(QUIET_S)
        assert len(host_flows.ended(fid, count=1, timeout=0)) == 1, "fired more than once for one window"
        assert int(host_flows.read_probe("A_WindowID").text) == window.hwnd
    finally:
        window.end()


def test_a_window_that_exists_at_the_arming_does_not_fire_with_not_trigger_on_enable(host_flows, tmp_path):
    title = title_of()
    window = ownwindow.start(tmp_path, title=title)
    try:
        fb, trigger = window_flow("Window opens existing", "Trigger_Window_Opens", **window_pars(title))
        fid = host_flows.add(fb)
        arm(host_flows, fid)
        assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
        time.sleep(QUIET_S)
        assert host_flows.ended(fid, count=0, timeout=0) == [], "the window that existed fired"
    finally:
        window.end()


def test_without_not_trigger_on_enable_a_window_that_exists_fires_at_the_first_poll(host_flows, tmp_path):
    title = title_of()
    window = ownwindow.start(tmp_path, title=title)
    try:
        fb, trigger = window_flow("Window opens at enable", "Trigger_Window_Opens",
                                  **window_pars(title, NotTriggerOnEnable="0"))
        fid = host_flows.add(fb)
        arm(host_flows, fid)
        assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
        assert len(host_flows.ended(fid, count=1, timeout=scaled(10))) >= 1, host_flows.stderr_text()
        assert int(host_flows.read_probe("A_WindowID").text) == window.hwnd
    finally:
        window.end()


def test_a_closed_window_fires_closes_with_its_id(host_flows, tmp_path):
    title = title_of()
    window = ownwindow.start(tmp_path, title=title)
    hwnd = window.hwnd
    fb, trigger = window_flow("Window closes", "Trigger_Window_Closes", **window_pars(title))
    fid = host_flows.add(fb)
    arm(host_flows, fid)
    assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
    time.sleep(QUIET_S)
    assert host_flows.ended(fid, count=0, timeout=0) == [], "fired while the window is open"
    window.end()
    assert len(host_flows.ended(fid, count=1, timeout=scaled(10))) >= 1, host_flows.stderr_text()
    assert int(host_flows.read_probe("A_WindowID").text) == hwnd


@pytest.mark.gui      # needs the real foreground: Windows refuses the focus while the user works in another window
def test_gets_active_fires_when_the_matching_window_becomes_the_active_one(host_flows, tmp_path, focus):
    title, other = title_of(), title_of("AhfOtherWindow")
    matching = ownwindow.start(tmp_path, noactivate=False, title=title)                  # active when it is started
    second = ownwindow.start(tmp_path, noactivate=True, title=other)
    try:
        assert matching.is_active(), "the own window did not get the focus"
        fb, trigger = window_flow("Gets active", "Trigger_Window_Gets_Active", **window_pars(title))
        fid = host_flows.add(fb)
        arm(host_flows, fid)
        assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
        time.sleep(QUIET_S)
        assert host_flows.ended(fid, count=0, timeout=0) == [], "the window that was active at the arming fired"
        activate(host_flows, other)                                    # the other window is active now
        time.sleep(QUIET_S)
        assert host_flows.ended(fid, count=0, timeout=0) == [], "fired for another window"
        activate(host_flows, title)
        assert len(host_flows.ended(fid, count=1, timeout=scaled(10))) >= 1, host_flows.stderr_text()
        assert int(host_flows.read_probe("A_WindowID").text) == matching.hwnd
    finally:
        second.end()
        matching.end()


@pytest.mark.gui      # needs the real foreground: Windows refuses the focus while the user works in another window
def test_gets_inactive_fires_with_the_id_of_the_window_that_lost_the_focus(host_flows, tmp_path, focus):
    title, other = title_of(), title_of("AhfOtherWindow")
    matching = ownwindow.start(tmp_path, noactivate=False, title=title)                  # active at the arming: the baseline
    second = ownwindow.start(tmp_path, noactivate=True, title=other)
    try:
        assert matching.is_active(), "the own window did not get the focus"
        fb, trigger = window_flow("Gets inactive", "Trigger_Window_Gets_Inactive", **window_pars(title))
        fid = host_flows.add(fb)
        arm(host_flows, fid)
        assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
        time.sleep(QUIET_S)
        assert host_flows.ended(fid, count=0, timeout=0) == [], "fired before the matching window lost the focus"
        activate(host_flows, other)
        assert len(host_flows.ended(fid, count=1, timeout=scaled(10))) >= 1, host_flows.stderr_text()
        assert int(host_flows.read_probe("A_WindowID").text) == matching.hwnd
    finally:
        second.end()
        matching.end()


def test_a_window_that_opens_and_closes_between_two_polls_is_not_seen(host_flows, tmp_path):
    """The poll is 3 s: a window that lives for about 1 s between two polls is not in the list of either poll. Documented
    in the help page (polling, not a Windows event); the test fixes what happens, not a timing of the window."""
    title = title_of()
    fb, trigger = window_flow("Short window", "Trigger_Window_Opens", **window_pars(title, interval="3000"))
    fid = host_flows.add(fb)
    arm(host_flows, fid)
    assert wait_armed(host_flows, fid, trigger.id), host_flows.stderr_text()
    window = ownwindow.start(tmp_path, title=title)
    time.sleep(1.0)
    window.end()
    time.sleep(scaled(4.0))                                             # the first poll is 3 s after the arming
    assert host_flows.ended(fid, count=0, timeout=0) == [], "a window closed before the poll was seen"


def test_a_window_without_identification_is_not_armed_and_says_so(host_flows):
    fb, trigger = window_flow("No window", "Trigger_Window_Opens", **window_pars(""))
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    state = wait_state(host_flows, fid, trigger.id, lambda s: s["message"] == "No window specified")
    assert state is not None and state["armed"] is False, state


def test_a_bad_interval_of_a_window_trigger_is_not_armed_and_gives_the_v1_text(host_flows):
    title = title_of()
    fb, trigger = window_flow("Bad interval", "Trigger_Window_Gets_Active", **window_pars(title, interval="0"))
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    state = wait_state(host_flows, fid, trigger.id, lambda s: s["message"] == "Parameter 'interval' has invalid value: 0")
    assert state is not None and state["armed"] is False, state
