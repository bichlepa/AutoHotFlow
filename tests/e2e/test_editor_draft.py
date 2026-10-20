"""WI-0096, REQ-EDT-090, REQ-EDT-100 (editor part), REQ-EDT-030 (the view is saved): the draft, the patch client, undo and
redo, the selection and the view of the editor (src/editor/EditorDraft.ahk) under the real supervisor, headless. The changes
are made with cmd.test.edit, cmd.test.undo, cmd.test.redo and cmd.test.select of the editor; the engine's definition
(cmd.flow.get) shows what was committed.

Deterministic: a test waits for a condition of the editor or of the engine (wait_until), never for a fixed time, except the
2 s of the view (VIEW_SAVE_MS), which the test waits for with a margin.
"""

import time

import psutil
import pytest

from support.timing import scaled
from test_manager import FLOW, process_states, wait_until
from test_manager_editor import finish, op, start_manager
from test_editor import editor_state, open_editor, prepare_running, start_running_flow

EDITOR = "editor:" + FLOW
NEW = "element0000000010"        # the skeleton has ElementIDCounter 4: a new ID above it
ACTION = "element0000000002"     # Action_Sleep of the skeleton


def add_action(eid, name="Added"):
    return {"op": "element.add", "element": {"ID": eid, "type": "action", "class": "Action_Sleep", "package": "Default",
                                             "packageVersion": "1.2.0", "x": 0, "y": 900, "name": name,
                                             "StandardName": "Sleep", "pars": {}}}


def rename(eid, name):
    return {"op": "element.update", "id": eid, "fields": {"name": name}}


def edit(obs, ops, name=EDITOR):
    ans = obs.request(name, "cmd.test.edit", {"ops": ops}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def step(obs, what, name=EDITOR):
    ans = obs.request(name, "cmd.test." + what, {}, timeout=scaled(5))
    return ans["payload"]


def settled(obs, name=EDITOR):
    """The editor has no patch on its way (the state, or None while the editor does not answer)."""
    st = editor_state(obs, name)
    return st is not None and st["pending"] == 0


def engine_definition(obs):
    ans = obs.request("engine", "cmd.flow.get", {"flowId": FLOW}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]["definition"]


def test_an_edit_is_committed_and_the_engine_has_it(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        before = open_editor(obs)
        edit(obs, [add_action(NEW)])
        assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs)
        st = editor_state(obs)
        assert st["rev"] == before["rev"] + 1, st
        assert st["elements"] == before["elements"] + 1, st
        assert st["undo"] == 1 and st["redo"] == 0, st
        assert NEW in engine_definition(obs)["allElements"], "the engine's definition has the element"
    finally:
        finish(sup, obs)


def test_undo_and_redo_send_the_inverse_and_the_operations(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        edit(obs, [add_action(NEW)])
        assert wait_until(lambda: settled(obs), scaled(10))
        assert step(obs, "undo")["done"], "undo goes"
        assert wait_until(lambda: settled(obs), scaled(10))
        assert NEW not in engine_definition(obs)["allElements"], "undo is committed"
        assert editor_state(obs)["redo"] == 1, editor_state(obs)
        assert step(obs, "redo")["done"], "redo goes"
        assert wait_until(lambda: settled(obs), scaled(10))
        assert NEW in engine_definition(obs)["allElements"], "redo brings it back"
        assert editor_state(obs)["undo"] == 1 and editor_state(obs)["redo"] == 0
    finally:
        finish(sup, obs)


def test_101_steps_keep_the_last_100(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        for i in range(101):
            edit(obs, [rename(ACTION, "Step %d" % i)])
        assert wait_until(lambda: settled(obs), scaled(60)), editor_state(obs)
        st = editor_state(obs)
        assert st["undo"] == 100, st
        assert engine_definition(obs)["allElements"][ACTION]["name"] == "Step 100", "the last edit is committed"
    finally:
        finish(sup, obs)


def test_a_rename_by_the_manager_while_a_patch_is_on_its_way_is_merged(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        edit(obs, [rename(ACTION, "Edited")])
        ans = obs.request("manager", "cmd.test.op", {"op": "rename", "flowId": FLOW, "name": "Renamed flow"},
                          timeout=scaled(10))
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs)
        definition = engine_definition(obs)
        assert definition["name"] == "Renamed flow", "the rename is kept"
        assert definition["allElements"][ACTION]["name"] == "Edited", "the edit is kept"
        assert wait_until(lambda: (editor_state(obs) or {}).get("name") == "Renamed flow", scaled(10)), editor_state(obs)
    finally:
        finish(sup, obs)


def test_a_selection_is_kept_by_the_editor_and_pruned_by_a_removal(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request(EDITOR, "cmd.test.select", {"mode": "all"}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        assert len(editor_state(obs)["selection"]) == 5, editor_state(obs)     # 3 elements, 2 connections
        obs.request(EDITOR, "cmd.test.select", {"mode": "one", "ids": [ACTION]}, timeout=scaled(5))
        edit(obs, [{"op": "element.remove", "id": ACTION}])
        assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs)
        assert editor_state(obs)["selection"] == [], "the removed element leaves the selection"
    finally:
        finish(sup, obs)


def test_a_restart_of_the_engine_clears_the_stacks_and_shows_the_saved_state(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=prepare_running)
    try:
        start_running_flow(obs)
        op(obs, "select", flowId=FLOW)
        before = open_editor(obs)
        edit(obs, [rename(ACTION, "Lost")])
        assert wait_until(lambda: settled(obs), scaled(10))
        engine_pid = process_states(obs)["engine"]["pid"]
        psutil.Process(engine_pid).kill()
        assert wait_until(lambda: (editor_state(obs) or {}).get("epoch") not in (None, before["epoch"])
                          and (editor_state(obs) or {}).get("engine") == "ready", scaled(30)), editor_state(obs)
        st = editor_state(obs)
        assert st["undo"] == 0 and st["redo"] == 0 and st["pending"] == 0, st
        assert wait_until(lambda: engine_definition(obs)["allElements"][ACTION]["name"] != "Lost", scaled(10))
    finally:
        finish(sup, obs)


def test_the_view_is_saved_two_seconds_after_the_change_and_a_new_editor_uses_it(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request(EDITOR, "cmd.test.view", {"zoomAt": {"x": 100, "y": 100, "direction": 1}}, timeout=scaled(5))
        zoom = ans["payload"]["view"]["zoom"]
        assert zoom > 1.0, ans
        assert wait_until(lambda: abs(float(engine_definition(obs)["flowSettings"]["zoomFactor"]) - zoom) < 1e-5,
                          scaled(10)), engine_definition(obs)["flowSettings"]
        assert editor_state(obs)["undo"] == 0, "the view is no undo step"
        obs.request(EDITOR, "cmd.test.close", {}, timeout=scaled(5))
        assert wait_until(lambda: (editor_state(obs) or {}) == {} or editor_state(obs) is None, scaled(10))
        open_editor(obs)
        assert abs(editor_state(obs)["view"]["zoom"] - zoom) < 1e-5, editor_state(obs)["view"]
    finally:
        finish(sup, obs)


def test_a_view_change_closes_with_the_view_written(procs, datadir, session_id):
    """The editor writes the view before it says bye (a close within the 2 s is not lost)."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request(EDITOR, "cmd.test.view", {"zoomAt": {"x": 100, "y": 100, "direction": -1}}, timeout=scaled(5))
        zoom = ans["payload"]["view"]["zoom"]
        obs.request(EDITOR, "cmd.test.close", {}, timeout=scaled(5))
        assert wait_until(lambda: abs(float(engine_definition(obs)["flowSettings"]["zoomFactor"]) - zoom) < 1e-5,
                          scaled(10)), engine_definition(obs)["flowSettings"]
    finally:
        finish(sup, obs)


@pytest.mark.parametrize("running", [True, False], ids=["while-running", "idle"])
def test_a_round_trip_of_an_edit_is_measured(procs, datadir, session_id, running):
    """WI-0096, MS-0055: the time from cmd.test.edit to the settled state (the patch round trip editor, supervisor, engine
    and back), with a flow that runs and without one. The bound is generous; the numbers are in doc/MEASUREMENTS.md."""
    sup, obs = start_manager(procs, datadir, session_id, prepare=prepare_running)
    try:
        if running:
            start_running_flow(obs)
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        times = []
        for i in range(30):
            t0 = time.perf_counter()
            edit(obs, [rename(ACTION, "Round %d" % i)])
            assert wait_until(lambda: settled(obs), scaled(10), step=0), editor_state(obs)
            times.append((time.perf_counter() - t0) * 1000.0)
        times.sort()
        median = times[len(times) // 2]
        print("MEASURE patch round trip (running=%s): n=%d median=%.1f ms max=%.1f ms" % (running, len(times), median,
                                                                                    times[-1]))
        assert median < scaled(500), times
    finally:
        finish(sup, obs)
