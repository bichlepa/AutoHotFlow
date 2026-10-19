"""WI-0088, REQ-EDT-010, REQ-EDT-020, REQ-ROB-040, REQ-EXE-140 (editor part), REQ-MIG-070 (editor display): the editor role
(src/editor/, PROTOCOL 4.11) under the real supervisor, headless. The editor is started the way the user does it: the
manager's operation "edit" (cmd.test.op), so the supervisor starts `editor:<flowId>` with --headless. The test reads the
editor with cmd.test.state and cmd.test.render, and changes the flow with the manager's operations.

Deterministic: an editor stays up until it is ended, so a test waits for a condition of the editor (wait_until), never
for a timing of a short-lived process.
"""

import json
from pathlib import Path

import psutil

from support.timing import scaled
from test_manager import FLOW, SKELETON_SRC, process_states, wait_until
from test_manager_editor import edit_results, finish, op, start_manager, state as manager_state, supervisor_log

EDITOR = "editor:" + FLOW
SECOND = "second"
TRIGGER = "element0000000001"
ACTION = "element0000000002"
BACKGROUND = "FFEEF2F5"              # EditorStyle.Background (0xFFEEF2F5), the colour of an empty part of the canvas


def editor_state(obs, name=EDITOR):
    """The state of the editor, or None while it does not answer."""
    ans = obs.request(name, "cmd.test.state", {}, timeout=scaled(5))
    if not ans["payload"].get("ok"):
        return None
    return ans["payload"]["state"]


def render(obs, name=EDITOR, probes=()):
    ans = obs.request(name, "cmd.test.render", {"w": 800, "h": 600, "probes": [list(p) for p in probes]},
                      timeout=scaled(10))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def open_editor(obs, flow=FLOW):
    """The manager's Edit operation for one flow; the editor answers its state."""
    sent, ok, code, started = edit_results(obs, flowId=flow)[0]
    assert (sent, ok) == (True, True), (sent, ok, code)
    loaded = lambda: (editor_state(obs, "editor:" + flow) or {}).get("rev", -1) >= 1    # the definition arrived
    assert wait_until(loaded, scaled(20)), "editor did not load the flow: %s" % editor_state(obs, "editor:" + flow)
    return editor_state(obs, "editor:" + flow)


def editor_process(obs, flow=FLOW):
    return process_states(obs).get("editor:" + flow, {})


def write_flow(datadir, flow, duration=None):
    """A copy of the skeleton flow under another ID (the file name is the ID); a Duration makes the action run long."""
    data = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    if duration is not None:
        data["allElements"][ACTION]["pars"]["Duration"] = str(duration)
    path = Path(datadir) / "Flows" / (flow + ".json")
    path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(data), encoding="utf-8")


def start_running_flow(obs, flow=FLOW):
    ans = obs.request("manager", "cmd.test.command", {"type": "cmd.flow.start", "payload": {"flowId": flow}}, timeout=8)
    assert ans["payload"]["ok"] and ans["payload"]["answer"]["ok"], ans


def test_edit_starts_an_editor_that_loads_its_flow(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        assert st["flowId"] == FLOW
        assert st["rev"] == 1, st
        assert st["elements"] == 3 and st["connections"] == 2, st
        assert st["engine"] == "ready", st
        assert TRIGGER in st["triggers"], st
        assert st["ended"] == "", st
        assert st["lastResync"]["reason"] == "start", st
        assert editor_process(obs)["state"] == "ready", editor_process(obs)
    finally:
        finish(sup, obs)


def test_the_editor_draws_the_flow_and_the_probes_match_the_elements(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        # the trigger is 140 x 105 at (0, 0); its centre is inside it, the far corner is empty
        out = render(obs, probes=[(70, 52), (400, 500), (70, 262)])
        colors = out["colors"]
        assert len(colors) == 3, out
        assert colors[1] == BACKGROUND, colors
        assert colors[0] != BACKGROUND and colors[2] != BACKGROUND, colors
        assert out["ms"] >= 0, out
        st = editor_state(obs)
        assert st["frames"] >= 1, st
        assert st["view"]["width"] == 800 and st["view"]["height"] == 600, st
    finally:
        finish(sup, obs)


def test_an_editor_opened_while_the_flow_runs_shows_the_running_element(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=prepare_running)
    try:
        start_running_flow(obs)
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        assert wait_until(lambda: (editor_state(obs) or {}).get("states", {}).get(ACTION) == "running",
                          scaled(10)), editor_state(obs)
        st = editor_state(obs)
        assert st["states"][ACTION] == "running", st
        out = render(obs, probes=[(70, 262)])
        assert out["colors"][0] != BACKGROUND, out
    finally:
        finish(sup, obs)


def prepare_running(datadir):
    """Replaces the skeleton flow by one whose action runs 8 s (start_manager writes the skeleton first)."""
    write_flow(datadir, FLOW, duration=8000)


def test_a_rename_in_the_manager_changes_the_title_of_the_editor(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request("manager", "cmd.test.op", {"op": "rename", "flowId": FLOW, "name": "Renamed flow"},
                          timeout=scaled(10))
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: (editor_state(obs) or {}).get("name") == "Renamed flow", scaled(10)), editor_state(obs)
        assert editor_state(obs)["rev"] >= 2, editor_state(obs)
    finally:
        finish(sup, obs)


def test_a_deleted_flow_closes_its_editor_as_a_planned_end(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        op(obs, "answers", answers={"delete": "yes"})
        op(obs, "delete", flowIds=[FLOW])
        assert wait_until(lambda: editor_process(obs).get("state") == "exited", scaled(15)), editor_process(obs)
        assert editor_process(obs).get("state") != "crashed", editor_process(obs)
        assert not any("unexpectedly" in t and FLOW in t for t in supervisor_log(obs)), supervisor_log(obs)
    finally:
        finish(sup, obs)


def test_a_flow_that_does_not_exist_ends_its_editor_cleanly_with_a_notice(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        sent, ok, code, started = edit_results(obs, flowId="Flow 1010290492")[0]
        assert (sent, ok, started) == (True, True, True), (sent, ok, code)
        assert wait_until(lambda: process_states(obs).get("editor:Flow 1010290492", {}).get("state") == "exited",
                          scaled(15)), process_states(obs)
        notices = manager_state(obs)["notices"]
        assert any(n["key"] == "Editor_flow_missing" for n in notices), notices
    finally:
        finish(sup, obs)


def test_the_close_box_is_a_planned_end_and_the_editor_is_not_restarted(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request("editor:" + FLOW, "cmd.test.close", {}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: editor_process(obs).get("state") == "exited", scaled(15)), editor_process(obs)
        assert editor_process(obs).get("clean") in (True, None), editor_process(obs)
        assert not any("unexpectedly" in t for t in supervisor_log(obs)), supervisor_log(obs)
    finally:
        finish(sup, obs)


def test_killed_engine_restarts_and_the_editor_shows_the_state_again(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=prepare_running)
    try:
        start_running_flow(obs)
        op(obs, "select", flowId=FLOW)
        before = open_editor(obs)
        engine_pid = process_states(obs)["engine"]["pid"]
        psutil.Process(engine_pid).kill()
        assert wait_until(lambda: process_states(obs).get("engine", {}).get("pid") not in (None, engine_pid)
                          and process_states(obs)["engine"].get("state") == "ready", scaled(30)), process_states(obs)
        assert wait_until(lambda: (editor_state(obs) or {}).get("epoch") not in (None, before["epoch"])
                          and (editor_state(obs) or {}).get("engine") == "ready", scaled(30)), editor_state(obs)
        st = editor_state(obs)
        assert st["lastResync"]["reason"] in ("epoch", "evt.process.restarted", "evt.process.ready",
                                              "evt.engine.restarted", "evt.engine.ready"), st
        assert st["flowId"] == FLOW and st["elements"] == 3, st
    finally:
        finish(sup, obs)


def test_killed_editor_is_not_restarted_and_the_flow_and_the_other_editor_go_on(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=prepare_running_and_second)
    try:
        start_running_flow(obs)
        assert edit_results(obs, flowIds=[FLOW, SECOND])[1][3] is True
        open_editor(obs, SECOND)
        pid = editor_process(obs)["pid"]
        psutil.Process(pid).kill()
        assert wait_until(lambda: editor_process(obs).get("state") == "crashed", scaled(15)), editor_process(obs)
        assert editor_process(obs).get("pid") == pid
        assert editor_process(obs).get("restarts", 0) == 0, editor_process(obs)
        assert wait_until(lambda: editor_state(obs, "editor:" + SECOND) is not None, scaled(5))
        assert editor_process(obs, SECOND).get("state") == "ready", editor_process(obs, SECOND)
        st = editor_state(obs)
        assert st is None or st["flowId"] == FLOW
        # the flow runs on
        assert any(f["flowId"] == FLOW and f["executing"] for f in manager_state(obs)["flows"]), manager_state(obs)["flows"]
    finally:
        finish(sup, obs)


def prepare_running_and_second(datadir):
    prepare_running(datadir)
    write_flow(datadir, SECOND)


def test_two_editors_of_two_flows_run_at_once(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=lambda d: write_flow(d, SECOND))
    try:
        results = edit_results(obs, flowIds=[FLOW, SECOND])
        assert [r[3] for r in results] == [True, True], results
        assert wait_until(lambda: editor_state(obs, "editor:" + SECOND) is not None
                          and editor_state(obs) is not None, scaled(20))
        assert editor_state(obs)["flowId"] == FLOW
        assert editor_state(obs, "editor:" + SECOND)["flowId"] == SECOND
    finally:
        finish(sup, obs)
