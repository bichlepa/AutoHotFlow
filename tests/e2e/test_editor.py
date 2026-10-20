"""WI-0088, REQ-EDT-010, REQ-EDT-020, REQ-ROB-040, REQ-EXE-140 (editor part), REQ-MIG-070 (editor display): the editor role
(src/editor/, PROTOCOL 4.11) under the real supervisor, headless. The editor is started the way the user does it: the
manager's operation "edit" (cmd.test.op), so the supervisor starts `editor:<flowId>` with --headless. The test reads the
editor with cmd.test.state and cmd.test.render, and changes the flow with the manager's operations.

Deterministic: an editor stays up until it is ended, so a test waits for a condition of the editor (wait_until), never
for a timing of a short-lived process.
"""

import json
import time
from pathlib import Path

import psutil
import pytest

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


def write_flow(datadir, flow, duration=None, strict=None, migration=False):
    """A copy of the skeleton flow under another ID (the file name is the ID); a Duration makes the action run long
    (an expression such as "x + 1" makes it a type error); strict sets the type mode of the flow; migration adds a
    MIGRATION place to the action."""
    data = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    if duration is not None:
        data["allElements"][ACTION]["pars"]["Duration"] = str(duration)
    if strict is not None:
        data["flowSettings"]["strictTypes"] = strict
    if migration:
        data["allElements"][ACTION]["migration"] = [{"par": "Duration", "ids": ["M-0025"], "v1": "%a%"}]
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


def test_the_snapshot_of_the_editor_names_the_flow_the_revision_and_the_frames(procs, datadir, session_id):
    """PROTOCOL 4.9, role part of the editor (WI-0088): the flow, the revision, the counts and the last resync."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        render(obs)
        ans = obs.request(EDITOR, "cmd.diag.snapshot", {}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        info = ans["payload"]["snapshot"]["info"]
        assert info["flowId"] == FLOW and info["rev"] == 1, info
        assert info["elements"] == 3 and info["connections"] == 2, info
        assert info["frames"] >= 1 and info["meanFrameMs"] >= 0 and info["slowestFrameMs"] >= info["meanFrameMs"], info
        assert info["lastResync"]["reason"] == "start", info
        assert info["headless"] is True and info["windowVisible"] is False, info
        assert info["engine"] == "ready", info
    finally:
        finish(sup, obs)


# --- WI-0089: live states, marks and warnings -------------------------------------------------------------------------

CONNECTION = "connection0000000004"  # the trigger -> action connection of the skeleton flow
ACTION_X, ACTION_Y = 0, 210          # the position of the action element (skeleton flow); its box is 140 x 105
MIGRATION_BADGE = "FF3B82F6"         # EditorStyle.MigrationBadge, top right of the element
WARNING_BADGE = "FFF39C12"           # EditorStyle.WarningBadge, bottom right of the element (the count is drawn in it)


def states(obs, name=EDITOR):
    st = editor_state(obs, name)
    return (st or {}).get("states", {})


def test_a_running_element_and_its_connection_are_tinted_and_fade_out_after_the_end(procs, datadir, session_id):
    """Task 1 (v1 tint): the element is tinted while it runs, the connection its thread took is tinted for one second
    after the start, and the finished element fades out (state recent) before it is drawn as idle again."""
    sup, obs = start_manager(procs, datadir, session_id, prepare=lambda d: write_flow(d, FLOW, duration=3000))
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        start_running_flow(obs)
        assert wait_until(lambda: states(obs).get(ACTION) == "running", scaled(15)), editor_state(obs)
        assert wait_until(lambda: states(obs).get(CONNECTION) == "recent", scaled(5)), editor_state(obs)
        assert wait_until(lambda: states(obs).get(ACTION) == "recent", scaled(15)), editor_state(obs)
        assert wait_until(lambda: ACTION not in states(obs), scaled(5)), editor_state(obs)
        assert wait_until(lambda: CONNECTION not in states(obs), scaled(5)), editor_state(obs)
        assert editor_state(obs)["fading"] == 0, editor_state(obs)
    finally:
        finish(sup, obs)


def test_the_trigger_mark_follows_the_enabled_state_of_the_engine(procs, datadir, session_id):
    """Task 2: the switch mark of a trigger follows evt.trigger.state (the enabled state of the engine)."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request("engine", "cmd.trigger.enable", {"flowId": FLOW, "elementId": TRIGGER}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: (editor_state(obs) or {}).get("triggers", {}).get(TRIGGER, {}).get("enabled") is True,
                          scaled(10)), editor_state(obs)
        ans = obs.request("engine", "cmd.trigger.disable", {"flowId": FLOW, "elementId": TRIGGER}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: (editor_state(obs) or {}).get("triggers", {}).get(TRIGGER, {}).get("enabled") is False,
                          scaled(10)), editor_state(obs)
        assert editor_state(obs)["flowState"]["enabled"] is False, editor_state(obs)
        ans = obs.request("engine", "cmd.trigger.enable", {"flowId": FLOW, "elementId": TRIGGER}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: (editor_state(obs) or {}).get("triggers", {}).get(TRIGGER, {}).get("enabled") is True,
                          scaled(10)), editor_state(obs)
    finally:
        finish(sup, obs)


def test_an_exception_keeps_the_element_marked_and_its_message_is_kept(procs, datadir, session_id):
    """Task 3: a strict flow whose duration is a wrong expression ends the action with an exception; the element keeps
    the exception look (not faded) and the message of the exception for the tooltip."""
    sup, obs = start_manager(procs, datadir, session_id,
                             prepare=lambda d: write_flow(d, FLOW, duration="x + 1", strict=True))
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        start_running_flow(obs)
        assert wait_until(lambda: states(obs).get(ACTION) == "exception", scaled(15)), editor_state(obs)
        st = editor_state(obs)
        assert isinstance(st["messages"].get(ACTION), str) and st["messages"][ACTION] != "", st
        time.sleep(scaled(1.5))             # longer than a fade: the exception look stays
        st = editor_state(obs)
        assert st["states"].get(ACTION) == "exception" and st["fading"] == 0, st
        out = render(obs, probes=[(ACTION_X + 70, ACTION_Y + 52)])
        assert out["colors"][0] != BACKGROUND, out
    finally:
        finish(sup, obs)


def test_warnings_show_a_count_badge_and_migration_places_a_badge(procs, datadir, session_id):
    """Task 4 (REQ-EDT-150): the warnings of a compatibility-mode evaluation are counted at the element (badge with the
    count, bottom right), and the MIGRATION place of the element has its own badge (top right, from the definition)."""
    sup, obs = start_manager(procs, datadir, session_id,
                             prepare=lambda d: write_flow(d, FLOW, duration="x + 1", strict=False, migration=True))
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        start_running_flow(obs)
        assert wait_until(lambda: (editor_state(obs) or {}).get("warnings", {}).get(ACTION, {}).get("count", 0) >= 1,
                          scaled(15)), editor_state(obs)
        st = editor_state(obs)
        assert st["warnings"][ACTION]["text"] != "", st
        out = render(obs, probes=[(ACTION_X + 123, ACTION_Y + 90), (ACTION_X + 128, ACTION_Y + 12)])
        assert out["colors"] == [WARNING_BADGE, MIGRATION_BADGE], out
    finally:
        finish(sup, obs)


# --- WI-0090: the view (zoom, move, size, DPI), the status bar and the tooltip (REQ-EDT-020, REQ-EDT-030, REQ-USE-090) ---

CONNECTION_1 = "connection0000000004"


def view_command(obs, name=EDITOR, **args):
    """cmd.test.view with the given steps; returns the payload (view, status)."""
    ans = obs.request(name, "cmd.test.view", args, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def hover(obs, x, y, name=EDITOR):
    ans = obs.request(name, "cmd.test.hover", {"x": x, "y": y}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def test_the_wheel_zooms_one_step_at_the_pointer_and_keeps_the_point_under_it(procs, datadir, session_id):
    """Task 1: a wheel step is the factor 1.1 (v1), and the flow point under the pointer stays under it."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        before = editor_state(obs)["view"]
        cx, cy = 400, 300
        fx = before["offsetX"] + cx / before["zoom"]
        fy = before["offsetY"] + cy / before["zoom"]
        view = view_command(obs, zoomAt={"x": cx, "y": cy, "direction": 1}, size={"w": 800, "h": 600})["view"]
        assert view["zoom"] == pytest.approx(before["zoom"] * 1.1, rel=1e-4), view
        assert view["offsetX"] + cx / view["zoom"] == pytest.approx(fx, rel=1e-4), view
        assert view["offsetY"] + cy / view["zoom"] == pytest.approx(fy, rel=1e-4), view
        view = view_command(obs, zoomAt={"x": cx, "y": cy, "direction": -1})["view"]
        assert view["zoom"] == pytest.approx(before["zoom"], rel=1e-4), view
    finally:
        finish(sup, obs)


def test_the_zoom_stops_at_the_limits_0_1_and_3(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        for _ in range(60):
            view = view_command(obs, zoomAt={"x": 10, "y": 10, "direction": 1})["view"]
        assert view["zoom"] == pytest.approx(3, rel=1e-6), view
        for _ in range(80):
            view = view_command(obs, zoomAt={"x": 10, "y": 10, "direction": -1})["view"]
        assert view["zoom"] == pytest.approx(0.1, rel=1e-6), view
    finally:
        finish(sup, obs)


def test_a_drag_moves_the_view_by_the_movement_of_the_pointer(procs, datadir, session_id):
    """Task 2: the content follows the pointer: a movement of 50 px to the right moves the offset by 50 / zoom."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        before = open_editor(obs)["view"]
        view = view_command(obs, drag={"dx": 50, "dy": -20})["view"]
        assert view["offsetX"] == pytest.approx(before["offsetX"] - 50 / before["zoom"], rel=1e-4), view
        assert view["offsetY"] == pytest.approx(before["offsetY"] + 20 / before["zoom"], rel=1e-4), view
        assert view["zoom"] == pytest.approx(before["zoom"], rel=1e-6), view
    finally:
        finish(sup, obs)


def test_a_new_size_and_dpi_keep_the_flow_at_the_same_physical_size(procs, datadir, session_id):
    """Task 3 and 6 (REQ-USE-090): the canvas takes the size, and the scale is zoom x DPI / 96, so an element has the same
    physical size on every screen. A window on a screen with 150 % scaling draws the flow 1.5 times as large in pixels."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        zoom = open_editor(obs)["view"]["zoom"]                # the flow's own zoom (flowSettings.zoomFactor)
        view = view_command(obs, size={"w": 1000, "h": 700}, dpi=144)["view"]
        assert (view["width"], view["height"], view["dpi"]) == (1000, 700, 144), view
        assert view["zoom"] == pytest.approx(zoom, rel=1e-6), view
        assert view["zoom"] * view["dpi"] / 96 == pytest.approx(zoom * 1.5, rel=1e-6), view
        st = editor_state(obs)
        assert st["view"]["dpi"] == 144, st
    finally:
        finish(sup, obs)


def test_the_status_bar_text_shows_offset_zoom_and_the_number_of_elements(procs, datadir, session_id):
    """Task 5 (v1 texts): offset, zoom and the number of elements, separated by |."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        assert editor_state(obs)["status"] == "Offset: x 0 y 0   |   Zoom: 1.00   |   3 elements", editor_state(obs)
        view_command(obs, drag={"dx": 10, "dy": 0})
        assert editor_state(obs)["status"] == "Offset: x -10 y 0   |   Zoom: 1.00   |   3 elements", editor_state(obs)
    finally:
        finish(sup, obs)


def test_the_tooltip_names_the_element_under_the_pointer_and_nothing_on_empty_space(procs, datadir, session_id):
    """Task 4 (REQ-EDT-020): kind, class and name of an element. The skeleton flow has zoom 1 and offset 0, 0, so a
    canvas pixel is a flow point: (70, 52) lies in the trigger (0..140, 0..105)."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        out = hover(obs, 70, 52)
        assert (out["kind"], out["id"]) == ("element", TRIGGER), out
        lines = out["tooltip"].split("\n")
        assert lines[0] == "Trigger", out
        assert "Name: Manual - Skeleton" in lines, out
        assert any(line.startswith("Class: ") for line in lines), out
        empty = hover(obs, 700, 550)                   # right of the flow
        assert (empty["kind"], empty["tooltip"]) == ("", ""), empty
    finally:
        finish(sup, obs)


def test_the_tooltip_of_a_connection_gives_its_type(procs, datadir, session_id):
    """Task 4: a connection shows its type. The connection runs from the trigger (bottom at flow y 105) to the action
    (top at y 210), at x 70: the canvas pixel (70, 157) is on it (zoom 1, offset 0, 0)."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        out = hover(obs, 70, 157)
        assert (out["kind"], out["id"]) == ("connection", CONNECTION_1), out
        assert out["tooltip"] == "Connection type: normal", out
    finally:
        finish(sup, obs)


def test_the_tooltip_of_an_element_lists_its_migration_places(procs, datadir, session_id):
    """Task 4: the MIGRATION IDs of an element are in its tooltip (the action has one place, M-0025)."""
    sup, obs = start_manager(procs, datadir, session_id, prepare=lambda d: write_flow(d, FLOW, migration=True))
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        out = hover(obs, 70, 262)
        assert out["id"] == ACTION, out
        assert "MIGRATION M-0025" in out["tooltip"].split("\n"), out
    finally:
        finish(sup, obs)
