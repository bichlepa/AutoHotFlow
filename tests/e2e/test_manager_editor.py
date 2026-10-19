"""WI-0087: the manager opens the editor of a flow (Edit button, double click) and the supervisor starts it (PROTOCOL 4.1
cmd.editor.open, 4.8 Editor), headless.

The supervisor starts the real manager (--headless) with storage and engine. The test runs the operation "edit" of the test
driver (cmd.test.op, the same call as the Edit button; "flowIds" sends several requests one after the other from the
manager) and reads the process table and the supervisor's log.

The editor is a real process that stays up (WI-0088, tests/e2e/test_editor.py), so a second request for a running editor
is answered as running whenever it comes. The "running" cases still send their requests in one cmd.test.op (back to back).

The test roles of the supervisor (--test-roles) lower the editor limit (--editor-limit), so the limit needs no 21 processes.
"""

import psutil
import pytest

from test_manager import FLOW, Sup, connect_obs, flow_data, process_states, wait_flow_loaded, wait_ready, wait_until
from support.timing import scaled

EDITOR = "editor:" + FLOW
SPACED_FLOW = "Flow 1010290492"


def op(obs, name, **args):
    ans = obs.request("manager", "cmd.test.op", dict(op=name, **args), timeout=scaled(10))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def state(obs):
    return obs.request("manager", "cmd.test.state", {}, timeout=5)["payload"]["state"]


def edit_results(obs, **args):
    """Runs the edit operation and returns the results: one per flow, each (sent, ok, code, started)."""
    out = []
    for res in op(obs, "edit", **args)["results"]:
        answer = res.get("answer") or {}
        started = (answer.get("payload") or {}).get("started")
        out.append((res["sent"], answer.get("ok"), answer.get("code"), started))
    return out


def start_manager(procs, datadir, session_id, extra=(), prepare=None):
    flow_data(datadir)
    if prepare is not None:
        prepare(datadir)           # the test's own flow files (after the skeleton flow, which it may replace)
    sup = Sup(procs, datadir, session_id, ["--start=storage,engine,manager", "--headless", *extra])
    obs = connect_obs(sup.pipe)
    wait_ready(obs, ["storage", "engine", "manager"])
    wait_flow_loaded(obs)
    assert wait_until(lambda: any(f["flowId"] == FLOW for f in state(obs)["flows"]), scaled(10)), "no snapshot"
    return sup, obs


def supervisor_log(obs):
    tail = obs.request("storage", "cmd.storage.log.tail", {"limit": 2000, "source": "supervisor"},
                       timeout=scaled(10))["payload"]
    assert tail["ok"], tail
    return [e["text"] for e in tail["entries"]]


def finish(sup, obs):
    obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
    assert sup.wait_exit(20) == 0


def test_edit_button_is_enabled_for_exactly_one_selected_flow(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        assert state(obs)["buttons"]["Edit"] is False                 # no flow selected
        op(obs, "select", flowId=FLOW)
        assert state(obs)["buttons"]["Edit"] is True                  # one flow
        op(obs, "select", flowId="")
        assert state(obs)["buttons"]["Edit"] is False
    finally:
        finish(sup, obs)


def test_edit_starts_the_editor_process_of_the_flow(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        assert edit_results(obs) == [(True, True, "", True)], state(obs)["lastAnswer"]
        assert wait_until(lambda: EDITOR in process_states(obs), scaled(10)), "no process %s" % EDITOR
        assert wait_until(lambda: any(("editor of '%s' started" % FLOW) in t for t in supervisor_log(obs)),
                          scaled(10)), supervisor_log(obs)
    finally:
        finish(sup, obs)


def test_a_flow_id_with_a_space_reaches_the_editor_whole(procs, datadir, session_id):
    """The command line quotes --flow: the editor of "Flow 1010290492" is one process with that flow ID (the round trip
    of the role's own command line is tested in tests/integration/test_supervisor.py)."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        assert edit_results(obs, flowId=SPACED_FLOW) == [(True, True, "", True)], state(obs)["lastAnswer"]
        assert wait_until(lambda: ("editor:" + SPACED_FLOW) in process_states(obs), scaled(10))
    finally:
        finish(sup, obs)


def test_edit_without_a_flow_is_refused_as_bad_payload_and_becomes_a_notice(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        sent, ok, code, _ = edit_results(obs, flowId="")[0]
        assert (sent, ok, code) == (True, False, "bad_payload"), state(obs)["lastAnswer"]
        notices = state(obs)["notices"]
        assert any(n["key"] == "Editor_open_failed" and n["level"] == "error" for n in notices), notices
    finally:
        finish(sup, obs)


def test_a_sender_other_than_the_manager_is_denied(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        ans = obs.request("supervisor", "cmd.editor.open", {"flowId": FLOW}, timeout=scaled(5))
        assert ans["payload"]["ok"] is False, ans
        assert ans["payload"]["error"]["code"] == "denied", ans
        assert EDITOR not in process_states(obs)
    finally:
        finish(sup, obs)


def test_a_second_edit_of_a_running_flow_starts_no_second_process(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        first, second = edit_results(obs, flowIds=[FLOW, FLOW])
        assert first[3] is True, first
        assert second[3] is False, second                 # shown, not started again
        starts = [t for t in supervisor_log(obs) if ("editor of '%s' started" % FLOW) in t]
        assert len(starts) == 1, starts                   # one start in the supervisor's log, not two
    finally:
        finish(sup, obs)


def test_the_editor_limit_refuses_a_new_editor_with_busy(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, extra=("--test-roles", "--editor-limit=1"))
    try:
        first, other = edit_results(obs, flowIds=[FLOW, "other"])
        assert first[3] is True, first
        assert other[2] == "busy", other
        assert "editor:other" not in process_states(obs)
    finally:
        finish(sup, obs)


# --- WI-0088: the follow-ups of WI-0087 (F-0149) -------------------------------------------------------------------

@pytest.mark.parametrize("bad", ['Flow "quoted', "control\x01char", "tab\tchar", "backslash\\"],
                         ids=["double-quote", "control-character", "tab", "trailing-backslash"])
def test_a_flow_id_that_a_command_line_cannot_carry_is_bad_payload(procs, datadir, session_id, bad):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        sent, ok, code, _ = edit_results(obs, flowId=bad)[0]
        assert (sent, ok, code) == (True, False, "bad_payload"), state(obs)["lastAnswer"]
        assert not any(name.startswith("editor:") and name != EDITOR for name in process_states(obs))
    finally:
        finish(sup, obs)


def test_the_editor_of_a_flow_that_just_died_is_started_again_and_its_slot_is_free(procs, datadir, session_id):
    """A killed editor is not restarted. A request for its flow, sent at once, is answered as started (the death was
    judged) or as busy (the end is not judged yet); the next request then starts it. The slot of the dead editor counts
    for nothing: with a limit of one, the other flow gets its editor once the first is judged."""
    sup, obs = start_manager(procs, datadir, session_id, extra=("--test-roles", "--editor-limit=1"))
    try:
        assert edit_results(obs, flowId=FLOW)[0][3] is True
        assert wait_until(lambda: process_states(obs).get(EDITOR, {}).get("state") == "ready", scaled(15))
        psutil.Process(process_states(obs)[EDITOR]["pid"]).kill()
        first = edit_results(obs, flowId=FLOW)[0]
        assert first[1] is True or first[2] == "busy", first
        assert wait_until(lambda: edit_results(obs, flowId=FLOW)[0][3] is True, scaled(15)), state(obs)["lastAnswer"]
        assert wait_until(lambda: process_states(obs)[EDITOR]["state"] == "ready", scaled(15)), process_states(obs)[EDITOR]
        assert process_states(obs)[EDITOR]["restarts"] == 0
    finally:
        finish(sup, obs)


def test_a_dead_editor_frees_its_slot_for_another_flow(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, extra=("--test-roles", "--editor-limit=1"))
    try:
        assert edit_results(obs, flowId=FLOW)[0][3] is True
        assert wait_until(lambda: process_states(obs).get(EDITOR, {}).get("state") == "ready", scaled(15))
        psutil.Process(process_states(obs)[EDITOR]["pid"]).kill()
        assert wait_until(lambda: edit_results(obs, flowId="other")[0][3] is True, scaled(15)), state(obs)["lastAnswer"]
        assert wait_until(lambda: process_states(obs)["editor:other"]["state"] == "ready", scaled(15)), process_states(obs)
    finally:
        finish(sup, obs)
