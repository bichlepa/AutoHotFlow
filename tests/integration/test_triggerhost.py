"""WI-0061: trigger host role (src/triggerhost/, PROTOCOL 4.4, REQ-TRG-010).

The trigger host runs as a real process (tests/integration/helpers/AutoHotFlowTest.ahk --role=triggerhost, started through
tools/ahkrun.py). Its hub is the Python stand-in tests/support/pyhub.py (RoleHub). The test plays the engine: an AhfClient
named "engine" sends cmd.trigger.* and receives evt.trigger.*. The test triggers are in tests/elements/Test/Triggers/.

Counting rules: a count of events is bounded from above by the time the timer could run at most (a single timer cannot
fire faster than its interval), so these bounds are not relaxed under load; the lower bounds are generous.
"""

import time

import pytest

from support.ahfclient import AhfClient
from support.timing import scaled
from test_role import RoleHub, ahk_process, launch, wait_hello

ROLE = "triggerhost"
ROOT_TIMEOUT_S = 5.0
FLOW = "Flow 1"
ELEMENT = "element0000000001"
KEY = FLOW + "/" + ELEMENT
OTHER_KEY = FLOW + "/element0000000002"
TIMER_MS = 100


@pytest.fixture
def pipe(session_id):
    return "ahf.trig.%s" % session_id


@pytest.fixture
def runs(procs):
    started = []
    yield started
    for run in started:
        run.close_files()


@pytest.fixture
def hub(pipe):
    with RoleHub(pipe) as h:
        yield h


@pytest.fixture
def host(procs, datadir, runs, pipe, session_id, hub):
    """The trigger host, said hello, and the engine stand-in."""
    run = launch(procs, datadir, runs, pipe, session_id, ROLE)
    wait_hello(hub, ROLE)
    engine = AhfClient(pipe, "engine")
    yield engine
    engine.close()


# --- helpers ---------------------------------------------------------------------------------------------------------

def arm(engine, cls, key=KEY, gen=1, params=None, context="", element=None):
    """cmd.trigger.arm of a class of the test package (a bare class name); returns the answer payload."""
    element = element or key.split("/", 1)[1]
    class_id = cls if "." in cls else "Test." + cls
    payload = {"triggerKey": key, "gen": gen, "flowId": key.split("/", 1)[0], "elementId": element,
               "class": class_id, "params": params or {}, "context": context}
    answer = engine.request(ROLE, "cmd.trigger.arm", payload, timeout=ROOT_TIMEOUT_S)
    assert answer["type"] == "res.trigger.arm", answer
    return answer["payload"]


def disarm(engine, key=KEY):
    answer = engine.request(ROLE, "cmd.trigger.disarm", {"triggerKey": key}, timeout=ROOT_TIMEOUT_S)
    assert answer["type"] == "res.trigger.disarm", answer
    return answer["payload"]


def reset(engine):
    answer = engine.request(ROLE, "cmd.trigger.reset", {}, timeout=ROOT_TIMEOUT_S)
    assert answer["type"] == "res.trigger.reset", answer
    return answer["payload"]


def armed_keys(engine):
    """The armed triggers of the host, from its snapshot (DiagInfo)."""
    answer = engine.request(ROLE, "cmd.diag.snapshot", {}, timeout=ROOT_TIMEOUT_S)
    return [entry["triggerKey"] for entry in answer["payload"]["snapshot"]["info"]["armed"]]


def collect(engine, type_, seconds):
    """The payloads of the events of one type that arrive within `seconds`; also returns the seconds really waited."""
    started = time.monotonic()
    found = []
    while time.monotonic() - started < seconds:
        for msg in engine.events(timeout=0.1):
            if msg.get("type") == type_:
                found.append(msg["payload"])
    return found, time.monotonic() - started


def drain(engine):
    """Takes the events that have already arrived, so that the next collect sees only what comes later."""
    for _ in engine.events(timeout=0.05):
        pass


def fired_for(events, key):
    return [e for e in events if e.get("triggerKey") == key]


# --- arming, firing, disarming ---------------------------------------------------------------------------------------

def test_timer_trigger_fires_about_every_interval_and_stops_at_disarm(host):
    answer = arm(host, "Trigger_TestTimer", params={"Interval": TIMER_MS})
    assert answer["ok"] is True, answer
    events, waited = collect(host, "evt.trigger.fired", scaled(0.5))
    fired = fired_for(events, KEY)
    upper = waited / (TIMER_MS / 1000) + 2          # a timer cannot fire faster than its interval
    assert 3 <= len(fired) <= upper, (len(fired), upper)
    assert [e["data"]["count"] for e in fired] == list(range(1, len(fired) + 1))
    assert all(e["gen"] == 1 and e["flowId"] == FLOW and e["elementId"] == ELEMENT for e in fired)

    assert disarm(host)["ok"] is True
    drain(host)
    later, _ = collect(host, "evt.trigger.fired", scaled(0.4))
    assert fired_for(later, KEY) == [], "events after the disarm"
    assert KEY not in armed_keys(host)


def test_arming_an_armed_key_replaces_it_and_does_not_double_the_events(host):
    assert arm(host, "Trigger_TestTimer", params={"Interval": TIMER_MS}, gen=1)["ok"] is True
    assert arm(host, "Trigger_TestTimer", params={"Interval": TIMER_MS}, gen=2)["ok"] is True
    events, waited = collect(host, "evt.trigger.fired", scaled(0.5))
    fired = fired_for(events, KEY)
    upper = waited / (TIMER_MS / 1000) + 2
    assert len(fired) <= upper, "two timers for one key: %d events in %.2f s" % (len(fired), waited)
    assert {e["gen"] for e in fired} == {2}, "events of the replaced arming"
    assert armed_keys(host) == [KEY]


def test_a_failing_enable_is_answered_not_ok_and_the_host_keeps_working(host):
    answer = arm(host, "Trigger_TestFail")
    assert answer["ok"] is False
    assert answer["message"] == "test trigger fails on purpose", answer
    assert KEY not in armed_keys(host), "a failed arming leaves nothing armed"
    assert arm(host, "Trigger_TestTimer", key=OTHER_KEY, params={"Interval": TIMER_MS})["ok"] is True
    events, _ = collect(host, "evt.trigger.fired", scaled(0.3))
    assert fired_for(events, OTHER_KEY), "the other trigger does not fire"


def test_a_disable_that_throws_still_drops_the_trigger_and_its_events(host):
    assert arm(host, "Trigger_TestDisableThrows")["ok"] is True
    assert disarm(host)["ok"] is True
    assert KEY not in armed_keys(host)
    events, _ = collect(host, "evt.trigger.fired", scaled(0.6))      # its event was due after 300 ms
    assert fired_for(events, KEY) == [], "the timer of a dropped trigger still ran"
    assert arm(host, "Trigger_TestDisableThrows")["ok"] is True, "the key is free again"


def test_a_throwing_callback_is_reported_and_the_trigger_stays_armed(host):
    assert arm(host, "Trigger_TestCallbackThrows", gen=4)["ok"] is True
    events, _ = collect(host, "evt.trigger.error", scaled(0.6))
    errors = fired_for(events, KEY)
    assert len(errors) >= 2, errors
    assert errors[0]["message"] == "test callback fails, round 1", errors[0]
    assert errors[1]["message"] == "test callback fails, round 2", errors[1]
    assert {e["gen"] for e in errors} == {4}
    assert KEY in armed_keys(host)


def test_the_start_context_reaches_enable_and_fires_there(host):
    assert arm(host, "Trigger_TestFireOnEnable", context="ahfStartup")["ok"] is True
    fired = host.wait_event("evt.trigger.fired", timeout=scaled(2.0))
    assert fired["payload"]["triggerKey"] == KEY
    assert fired["payload"]["data"] == {"startup": 1}
    drain(host)
    assert arm(host, "Trigger_TestFireOnEnable", key=OTHER_KEY, context="")["ok"] is True
    events, _ = collect(host, "evt.trigger.fired", scaled(0.3))
    assert fired_for(events, OTHER_KEY) == [], "fired without the start context"


def test_an_unknown_class_is_not_found_and_a_non_trigger_class_is_refused(host):
    answer = host.request(ROLE, "cmd.trigger.arm", {"triggerKey": KEY, "gen": 1, "flowId": FLOW,
                                                    "elementId": ELEMENT, "class": "Default.Trigger_Nothing",
                                                    "params": {}, "context": ""}, timeout=ROOT_TIMEOUT_S)
    assert answer["payload"]["ok"] is False
    assert answer["payload"]["error"]["code"] == "not_found", answer
    refused = arm(host, "Action_TestEchoWorker")
    assert refused["ok"] is False and "is not a trigger" in refused["message"], refused


def test_disarm_of_an_unknown_key_is_ok(host):
    assert disarm(host, "Flow 9/none")["ok"] is True


# --- reset, shutdown -----------------------------------------------------------------------------------------------

def test_reset_disarms_every_trigger(host):
    assert arm(host, "Trigger_TestTimer", params={"Interval": TIMER_MS})["ok"] is True
    assert arm(host, "Trigger_TestTimer", key=OTHER_KEY, params={"Interval": TIMER_MS})["ok"] is True
    assert reset(host)["ok"] is True
    assert armed_keys(host) == []
    drain(host)
    events, _ = collect(host, "evt.trigger.fired", scaled(0.4))
    assert events == [], "events after the reset"


def test_shutdown_disarms_every_trigger_and_ends_with_bye(procs, datadir, runs, session_id, pipe):
    with RoleHub(pipe) as hub:
        run = launch(procs, datadir, runs, pipe, session_id, ROLE)
        pid = wait_hello(hub, ROLE)
        ahk = ahk_process(pid)
        with AhfClient(pipe, "engine") as engine:
            assert arm(engine, "Trigger_TestTimer", params={"Interval": TIMER_MS})["ok"] is True
            events, _ = collect(engine, "evt.trigger.fired", scaled(0.3))
            assert fired_for(events, KEY), "the trigger did not fire before the shutdown"
            hub.send_to(ROLE, "sys.shutdown", {"reason": "user", "deadlineMs": 2000})
            assert ahk.wait(timeout=10) == 0, run.stderr_text()
        bye_index = next((i for i, m in enumerate(hub.received)
                          if m.get("type") == "sys.bye" and m.get("from") == ROLE), None)
        assert bye_index is not None, "no sys.bye"
        late = [m for m in hub.received[bye_index + 1:] if m.get("type") == "evt.trigger.fired"]
        assert late == [], "events after sys.bye"
        assert run.wait_exit(timeout=10) == 0, run.stderr_text()
