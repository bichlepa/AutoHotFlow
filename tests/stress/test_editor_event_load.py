"""WI-0089 task 5 and REQ-PRF-060 (doc/TEST-STRATEGY.md 3): a flow at the limit of the runaway guard, with its editor open.

A loop of inline elements (about two element starts per pass, two events each) runs with the default guard of 50,000 element
executions per minute. While it runs the editor is asked every half second:
 - it answers the pings (cmd.test.state) at once,
 - it draws at most about 30 frames per second,
 - its queue in the hub does not grow without bound,
and after the stop the counts and the states agree with the engine: no instance runs, no element is still drawn running.
The frame latency of the run (the time from the change to the end of its frame, EditorModel.Latency) is printed and
recorded in doc/MEASUREMENTS.md (MS-0047); the test asserts only a generous bound.

Run: python -m pytest tests/stress/test_editor_event_load.py -m stress -q -n 0
"""

import sys
import time
from pathlib import Path

import pytest

from support.flowbuilder import FlowBuilder
from support.timing import scaled

TESTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TESTS_DIR / "e2e"))

from test_manager import FLOW, process_states  # noqa: E402
from test_manager_editor import edit_results, finish, op, start_manager  # noqa: E402

EDITOR = "editor:" + FLOW
RUN_S = 60.0                  # how long the editor is watched while the flow runs (or until the guard stops it)
PING_EVERY_S = 0.5
MAX_PING_S = 1.0              # an answer to cmd.test.state within this (scaled by the load of the run)
MAX_FPS = 31.0                # EditorWindow.FRAME_MS is 33 ms: about 30 frames per second
MAX_QUEUE = 1000              # the hub's limit of frames per client (PROTOCOL 5, item 5)
MAX_LATENCY_P95_MS = 250      # generous: a frame under this load takes a few ms, the cadence is 33 ms


def write_loop(datadir):
    """A loop of 1,000,000 passes whose body is Action_Do_nothing; the default guard stops it at 50,000 per minute."""
    fb = FlowBuilder("editor load", flow_settings={})
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=1000000)
    body = fb.action("Action_Do_nothing")
    fb.connect(fb.trigger(), loop)
    fb.connect(loop, body, "head")
    fb.connect(body, loop, into="tail")
    fb.write(datadir, FLOW)


def editor_state(obs):
    ans = obs.request(EDITOR, "cmd.test.state", {}, timeout=scaled(5))
    return ans["payload"]["state"] if ans["payload"].get("ok") else None


def wait_until(predicate, timeout, step=0.05):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if predicate():
            return True
        time.sleep(step)
    return False


def hub_queue(obs):
    snap = obs.request("supervisor", "cmd.diag.snapshot", {}, timeout=scaled(5))["payload"]["snapshot"]
    for link in snap["hub"]["links"]:
        if link["name"] == EDITOR:
            return link["queuedFrames"]
    return None


@pytest.mark.stress
@pytest.mark.timeout(400)
def test_the_editor_answers_and_draws_at_a_steady_rate_while_the_guard_stops_a_loop(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=write_loop)
    try:
        op(obs, "select", flowId=FLOW)
        assert edit_results(obs, flowId=FLOW)[0][3] is True
        assert wait_until(lambda: (editor_state(obs) or {}).get("rev", -1) >= 1, scaled(20)), "the editor did not load"
        assert obs.request(EDITOR, "cmd.test.render", {"w": 800, "h": 600}, timeout=scaled(10))["payload"]["ok"] is True
        ans = obs.request("manager", "cmd.test.command", {"type": "cmd.flow.start", "payload": {"flowId": FLOW}},
                          timeout=8)
        assert ans["payload"]["ok"], ans
        t0 = time.monotonic()
        first = editor_state(obs)
        worst_ping = 0.0
        max_queue = 0
        last = first
        while time.monotonic() - t0 < RUN_S:
            p0 = time.monotonic()
            ans = obs.request(EDITOR, "cmd.test.state", {}, timeout=scaled(5))
            worst_ping = max(worst_ping, time.monotonic() - p0)
            assert ans["payload"].get("ok"), "the editor did not answer the ping: %r" % (ans["payload"],)
            st = ans["payload"]["state"]
            queued = hub_queue(obs)
            if queued is not None:
                max_queue = max(max_queue, queued)
            last = st
            if st["ended"] or st["flowState"]["executing"] is False:
                break            # the guard stopped the flow
            time.sleep(PING_EVERY_S)
        elapsed = time.monotonic() - t0
        fps = (last["frames"] - first["frames"]) / elapsed
        latency = last["latency"]
        print("\nREQ-PRF-060 under event load: frames %d in %.1f s (%.1f per s), latency n=%d median %.1f ms p95 %.1f ms, "
              "worst ping %.0f ms, hub queue max %d"
              % (last["frames"] - first["frames"], elapsed, fps, latency["n"], latency["medianUs"] / 1000,
                 latency["p95Us"] / 1000, worst_ping * 1000, max_queue))
        assert worst_ping < scaled(MAX_PING_S), "a ping took %.2f s" % worst_ping
        assert fps <= MAX_FPS + 1, "%.1f frames per second" % fps
        assert max_queue < MAX_QUEUE, "the hub queue of the editor reached %d frames" % max_queue
        assert latency["n"] > 0 and latency["p95Us"] < MAX_LATENCY_P95_MS * 1000, latency
        # the flow stops: by the guard, or by us when the time is up (the guard limit is not reached on a slow machine)
        if last["flowState"]["executing"] is not False:
            ans = obs.request("engine", "cmd.flow.stop", {"flowId": FLOW}, timeout=scaled(10))
            assert ans["payload"]["ok"], ans
        assert_stopped_and_consistent(obs)
        assert process_states(obs).get(EDITOR, {}).get("state") == "ready", process_states(obs).get(EDITOR)
    finally:
        finish(sup, obs)


def assert_stopped_and_consistent(obs):
    """After the stop: no instance runs, no element is drawn running, the editor agrees with the engine's run state."""
    deadline = time.monotonic() + scaled(20)
    st = editor_state(obs)
    while time.monotonic() < deadline and (st["flowState"]["executing"] is not False or st["fading"] > 0):
        time.sleep(0.2)
        st = editor_state(obs)
    assert st["flowState"]["executing"] is False and st["flowState"]["instances"] == 0, st["flowState"]
    assert "running" not in st["states"].values(), st["states"]
    snap = obs.request("engine", "cmd.flow.runstate", {"flowId": FLOW}, timeout=scaled(10))["payload"]
    assert snap["flow"]["executing"] is False and snap["flow"]["instances"] == 0, snap["flow"]
    assert st["elements"] == 3 and st["connections"] == 3, st   # trigger, loop, body; entry, head, tail
    assert st["ended"] == "", st
