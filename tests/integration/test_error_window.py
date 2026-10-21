"""WI-0113, REQ-USE-080 (part 2), PROTOCOL 4.2, 4.7a, 4.8: the variables of the branch at an unhandled exception, in a real
session. The engine keeps a bounded copy of the variables of the branch (cmd.flow.error.get answers it); the notice carries
the errorId; a deleted flow keeps no copy; the headless manager asks for the copy of a notice and follows a new error.

The window itself (the list, the status line, the blocking-free behaviour on the screen) is in tests/gui/test_error_window.py
(gui, not run by the agents).
"""

import json
import re
import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled

WAIT_S = scaled(5.0)
MANAGER_ROLES = "storage,engine,manager,tray"
TIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")


@pytest.fixture
def shown(procs, datadir, session_id):
    """A FlowRunner whose session also starts the headless manager and the headless tray role."""
    runner = FlowRunner(procs, datadir, session_id, roles=MANAGER_ROLES)
    yield runner
    runner.close()


def failing_flow(name, steps):
    """Sets the variables of `steps` in the branch, then an element throws with no connection for it (unhandled)."""
    fb = FlowBuilder(name)
    setup = fb.action("Action_TestSetVar", Steps=json.dumps(steps))
    fb.chain(fb.trigger(), setup, fb.action("Action_TestThrow", name="THROWS"))
    return fb


def first_notice(runner, flow_id, timeout=WAIT_S):
    """The payload of the first evt.ui.notice of a flow (the first notice of a flow goes out at once)."""
    hit = runner.wait_message(lambda m: m.get("type") == "evt.ui.notice" and m["payload"].get("flowId") == flow_id,
                              timeout=timeout)
    assert hit is not None, "no notice for the unhandled exception of %s" % flow_id
    return hit[1]["payload"]


def get_error(runner, flow_id, error_id):
    return runner.request("engine", "cmd.flow.error.get", {"flowId": flow_id, "errorId": error_id})



def start_shown(runner):
    """Starts the session and waits until the manager and the tray role subscribe to topic notice (PROTOCOL 5a)."""
    runner.start(extra=("--headless",))
    deadline = time.monotonic() + WAIT_S

    def subscribed():
        links = runner.request("supervisor", "cmd.diag.snapshot", {}).get("snapshot", {}).get("hub", {}).get("links", [])
        return {l["name"] for l in links if "notice" in l.get("topics", [])} >= {"manager", "tray"}
    while not subscribed():
        if time.monotonic() > deadline:
            raise AssertionError("manager or tray did not subscribe to topic notice")
        time.sleep(0.05)


def test_an_unhandled_error_keeps_the_variables_of_its_branch(procs, datadir, session_id):
    runner = FlowRunner(procs, datadir, session_id)
    try:
        steps = [{"op": "set", "name": "x", "value": 5},
                 {"op": "set", "name": "A_Mark", "value": "here", "location": "thread"}]
        flow_id = runner.add(failing_flow("keeps", steps))
        runner.begin(flow_id)
        notice = first_notice(runner, flow_id)
        assert (notice["kind"], notice["key"]) == ("exception", "Notice_exception"), notice
        assert notice["errorId"].startswith("err-"), notice
        entry = get_error(runner, flow_id, notice["errorId"])
        assert entry["ok"], entry
        entry = entry["entry"]
        assert entry["flowName"] == "keeps" and entry["flowId"] == flow_id and entry["errorId"] == notice["errorId"], entry
        assert entry["elementId"] and entry["message"], entry
        assert TIME_RE.match(entry["time"]), entry["time"]
        by_name = {v["name"]: v for v in entry["vars"]}
        assert by_name["x"] == {"scope": "instance", "name": "x", "value": "5"}, by_name
        assert by_name["A_Mark"] == {"scope": "thread", "name": "A_Mark", "value": "here"}, by_name
        assert entry["omitted"] == 0
    finally:
        runner.close()


def test_the_copy_is_bounded_to_200_variables_and_the_long_values_are_cut(procs, datadir, session_id):
    runner = FlowRunner(procs, datadir, session_id)
    try:
        steps = [{"op": "set", "name": "v%03d" % i, "value": ("a" * 1500) if i == 0 else i} for i in range(250)]
        flow_id = runner.add(failing_flow("bounded", steps))
        runner.begin(flow_id)
        notice = first_notice(runner, flow_id)
        entry = get_error(runner, flow_id, notice["errorId"])["entry"]
        thread_count = sum(1 for v in entry["vars"] if v["scope"] == "thread")
        assert len(entry["vars"]) == 200, len(entry["vars"])
        assert entry["omitted"] + len(entry["vars"]) == 250 + thread_count, (entry["omitted"], thread_count)
        by_name = {v["name"]: v for v in entry["vars"]}
        assert by_name["v000"]["value"] == "a" * 1000 + "...", "a long value is cut and marked"
        assert by_name["v001"]["value"] == "1"
    finally:
        runner.close()


def test_a_deleted_flow_keeps_no_error_and_an_unknown_error_is_not_found(procs, datadir, session_id):
    runner = FlowRunner(procs, datadir, session_id)
    try:
        flow_id = runner.add(failing_flow("deleted", [{"op": "set", "name": "x", "value": 1}]))
        runner.begin(flow_id)
        notice = first_notice(runner, flow_id)
        assert get_error(runner, flow_id, notice["errorId"])["ok"]
        unknown = get_error(runner, flow_id, "err-999999999")
        assert unknown["ok"] is False and unknown["error"]["code"] == "not_found", unknown
        runner.request_ok("engine", "cmd.flow.delete", {"flowId": flow_id})
        gone = get_error(runner, flow_id, notice["errorId"])
        assert gone["ok"] is False and gone["error"]["code"] == "not_found", gone
    finally:
        runner.close()


def test_the_manager_asks_for_the_variables_of_a_notice_and_follows_a_new_error(procs, datadir, session_id):
    """The button "Show variables" (the model's OpenError) gets the copy; while the window is open, a new unhandled error
    of another flow replaces its content (the model asks for it as well)."""
    runner = FlowRunner(procs, datadir, session_id, roles=MANAGER_ROLES)
    try:
        first = runner.add(failing_flow("manager-first", [{"op": "set", "name": "x", "value": "one"}]))
        second = runner.add(failing_flow("manager-second", [{"op": "set", "name": "y", "value": "two"}]))
        third = runner.add(failing_flow("manager-third", [{"op": "set", "name": "z", "value": "three"}]))
        fourth = runner.add(failing_flow("manager-fourth", [{"op": "set", "name": "w", "value": "four"}]))
        start_shown(runner)
        for flow_id in (first, second, third):       # one error per flow: each is the first notice of its throttle key
            runner.begin(flow_id)
            first_notice(runner, flow_id)

        listed = runner.request_ok("manager", "cmd.test.op", {"op": "notices"})["notices"]
        n_of = {e["flowId"]: e for e in listed if e["kind"] == "exception"}
        assert n_of[first]["errorId"] and n_of[second]["errorId"], listed

        answer = runner.request_ok("manager", "cmd.test.op", {"op": "openError", "n": n_of[first]["n"]})
        assert answer["sent"] and answer["answerOk"] and answer["vars"] >= 1, answer
        state = runner.request_ok("manager", "cmd.test.op", {"op": "errorState"})
        assert state["follow"] is True and state["shown"]["entry"]["flowName"] == "manager-first", state

        # A new unhandled error of a fourth flow replaces the content while the window is open. (The same flow again
        # would be held back by the throttle for 10 s, and its notice would come with the count, not at once.)
        runner.begin(fourth)
        deadline = time.monotonic() + WAIT_S
        while True:
            state = runner.request_ok("manager", "cmd.test.op", {"op": "errorState"})
            shown = state["shown"]
            if shown and shown["entry"]["flowName"] == "manager-fourth":
                break
            assert time.monotonic() < deadline, "the window did not follow the new error: %s" % state
            time.sleep(0.05)
        assert any(v["name"] == "w" for v in shown["entry"]["vars"]), shown
    finally:
        runner.close()
