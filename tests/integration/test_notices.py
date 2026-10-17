"""WI-0075, REQ-USE-030, REQ-USE-080 (part 1), REQ-EXE-170 (notice): the notices of the engine in a real session.

The session starts the storage, the engine, the headless manager and the headless tray role. What is checked:
an unhandled exception gives one notice (evt.ui.notice on topic notice) and marks its flow in the manager until the user
selects the flow or opens the list; the tray role received it and counts it; a burst of errors gives one notice at once
and one with the count when the throttle window ends; a stop by the runaway guard gives a notice with the limit.
The message texts are Lang keys with arguments (PROTOCOL 4.7), the translation is made by the receivers.
"""

import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled

NOTICE_ROLES = "storage,engine,manager,tray"
START_EXTRA = ("--headless",)
WAIT_S = scaled(5.0)
# The throttle window is 10 s (NoticeThrottle.WINDOW_MS); the count goes out when it ends.
HELD_WAIT_S = scaled(15.0)
LIMIT_S = scaled(60.0)


@pytest.fixture
def shown(procs, datadir, session_id):
    """A FlowRunner whose session also starts the headless manager and the headless tray role."""
    runner = FlowRunner(procs, datadir, session_id, roles=NOTICE_ROLES)
    yield runner
    runner.close()


def start_shown(runner):
    """Starts the session and waits until the manager and the tray role subscribe to topic notice. A notice that is sent
    before a subscriber is connected is lost (PROTOCOL 5a), so the test may not start an error before this."""
    runner.start(extra=START_EXTRA)
    deadline = time.monotonic() + HELD_WAIT_S

    def subscribed():
        links = runner.request("supervisor", "cmd.diag.snapshot", {}).get("snapshot", {}).get("hub", {}).get("links", [])
        return {l["name"] for l in links if "notice" in l.get("topics", [])} >= {"manager", "tray"}
    while not subscribed():
        if time.monotonic() > deadline:
            raise AssertionError("manager or tray did not subscribe to topic notice")
        time.sleep(0.05)


def throwing_flow(name):
    """Every start ends with an unhandled exception: Action_TestThrow has no connection for it."""
    fb = FlowBuilder(name)
    fb.chain(fb.trigger(), fb.action("Action_TestThrow", name="THROWS"))
    return fb


def endless_loop(limit):
    fb = FlowBuilder("runaway-notice", flow_settings={"maxExecutionsPerMinute": limit})
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=1000000)
    body = fb.action("Action_Do_nothing")
    fb.connect(fb.trigger(), loop)
    fb.connect(loop, body, "head")
    fb.connect(body, loop, into="tail")
    return fb


def wait_for(predicate, timeout):
    deadline = time.monotonic() + timeout
    while not predicate():
        if time.monotonic() > deadline:
            return False
        time.sleep(0.05)
    return True


def notices_of(runner, flow_id=None):
    """The payloads of evt.ui.notice seen so far, optionally of one flow."""
    out = [m["payload"] for m in runner.messages(0) if m.get("type") == "evt.ui.notice"]
    return [p for p in out if flow_id is None or p.get("flowId") == flow_id]


def manager_flow(runner, flow_id):
    """The flow's record in the manager, or None while the manager has not answered or has not loaded the flow yet."""
    answer = runner.request("manager", "cmd.test.state", {})
    if not answer.get("ok"):
        return None
    found = [f for f in answer["state"]["flows"] if f["flowId"] == flow_id]
    return found[0] if found else None


def tray_info(runner):
    """The info part of the tray role's snapshot. The tray connects after the engine: the first asks may find no peer."""
    deadline = time.monotonic() + WAIT_S
    while True:
        answer = runner.request("tray", "cmd.diag.snapshot", {})
        if answer.get("ok") or time.monotonic() > deadline:
            return runner.request_ok("tray", "cmd.diag.snapshot", {})["snapshot"]["info"]
        time.sleep(0.05)


def test_an_unhandled_exception_gives_one_notice_marks_the_flow_and_reaches_the_tray(shown):
    fb = throwing_flow("throws")
    flow_id = shown.add(fb)
    start_shown(shown)
    shown.begin(flow_id)
    hit = shown.wait_message(lambda m: m.get("type") == "evt.ui.notice", timeout=WAIT_S)
    assert hit is not None, "no notice for the unhandled exception"
    p = hit[1]["payload"]
    assert (p["kind"], p["level"], p["flowId"], p["key"]) == ("exception", "error", flow_id, "Notice_exception"), p
    assert p["args"][0] == "throws" and p["args"][1] and p["args"][2] and p["held"] == 0, p
    assert wait_for(lambda: (manager_flow(shown, flow_id) or {}).get("unseen") is True, WAIT_S), "the flow is not marked"
    assert wait_for(lambda: tray_info(shown)["notices"] == 1, WAIT_S), "the tray role did not receive the notice"
    assert "The flow throws" in tray_info(shown)["lastNotice"], tray_info(shown)
    assert tray_info(shown)["noticesHeld"] == 0
    # Selecting the flow removes its mark.
    shown.request_ok("manager", "cmd.test.op", {"op": "select", "flowId": flow_id})
    assert manager_flow(shown, flow_id)["unseen"] is False


def test_opening_the_list_of_notices_removes_the_marks_and_keeps_the_entries(shown):
    first = shown.add(throwing_flow("first"))
    second = shown.add(throwing_flow("second"))
    start_shown(shown)
    shown.begin(first)
    shown.begin(second)                       # another flow: its own throttle key, so it is not held back
    assert wait_for(lambda: len(notices_of(shown)) == 2, WAIT_S), notices_of(shown)
    assert manager_flow(shown, first)["unseen"] is True and manager_flow(shown, second)["unseen"] is True
    answer = shown.request_ok("manager", "cmd.test.op", {"op": "notices"})
    assert manager_flow(shown, first)["unseen"] is False and manager_flow(shown, second)["unseen"] is False
    assert sorted(n["flowId"] for n in answer["notices"]) == sorted([first, second]), answer


@pytest.mark.slow
def test_a_burst_of_errors_gives_one_notice_at_once_and_the_count_when_the_window_ends(shown):
    flow_id = shown.add(throwing_flow("burst"))
    start_shown(shown)
    for _ in range(5):
        shown.begin(flow_id)
    assert len(shown.ended(flow_id, count=5, timeout=WAIT_S)) == 5, "the five starts did not end"
    assert len(notices_of(shown, flow_id)) == 1, "the first notice goes out at once, the others are held back"
    hit = shown.wait_message(lambda m: m.get("type") == "evt.ui.notice" and m["payload"].get("held") == 4,
                             timeout=HELD_WAIT_S)
    assert hit is not None, "the count of the held back notices never came: %s" % notices_of(shown, flow_id)
    assert len(notices_of(shown, flow_id)) == 2, notices_of(shown, flow_id)


def test_a_stop_by_the_runaway_guard_gives_a_notice_with_the_limit(shown):
    flow_id = shown.add(endless_loop(limit=2000))
    start_shown(shown)
    shown.begin(flow_id)
    hit = shown.wait_message(lambda m: m.get("type") == "evt.ui.notice", timeout=LIMIT_S)
    assert hit is not None, "no notice for the stop by the limit"
    p = hit[1]["payload"]
    assert (p["kind"], p["level"], p["flowId"], p["key"]) == ("limit", "warning", flow_id, "Notice_limit"), p
    assert p["args"] == ["runaway-notice", 2000], p
    assert wait_for(lambda: (manager_flow(shown, flow_id) or {}).get("limit") == "executionsPerMinute", WAIT_S)
    assert manager_flow(shown, flow_id)["limitValue"] == 2000, manager_flow(shown, flow_id)


def test_the_tray_holds_back_a_second_error_within_five_seconds(shown):
    """Two errors of two flows (two throttle keys in the engine) reach the tray within 5 s: the tray shows the first only."""
    first = shown.add(throwing_flow("tray-first"))
    second = shown.add(throwing_flow("tray-second"))
    start_shown(shown)
    shown.begin(first)
    shown.begin(second)
    assert wait_for(lambda: tray_info(shown)["notices"] == 2, WAIT_S), tray_info(shown)
    info = tray_info(shown)
    assert info["noticesHeld"] == 1, info
    assert wait_for(lambda: len(notices_of(shown)) == 2, WAIT_S)


def test_a_limit_stop_is_shown_even_within_five_seconds_of_an_error(shown):
    """An error, then a stop by the runaway guard a moment later: the warning bypasses the tray throttle."""
    error_flow = shown.add(throwing_flow("tray-error"))
    loop_flow = shown.add(endless_loop(limit=200))
    start_shown(shown)
    shown.begin(error_flow)
    shown.begin(loop_flow)
    assert wait_for(lambda: tray_info(shown)["notices"] == 2, LIMIT_S), tray_info(shown)
    info = tray_info(shown)
    assert info["noticesHeld"] == 0, info
    assert info["lastNotice"].startswith("The flow runaway-notice was stopped"), info["lastNotice"]
