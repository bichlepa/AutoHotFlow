"""WI-0087: the manager opens the editor of a flow (Edit button, double click) and the supervisor starts it (PROTOCOL 4.1
cmd.editor.open, 4.8 Editor), headless.

The supervisor starts the real manager (--headless) with storage and engine; the test runs the operation "edit" of the test
driver (cmd.test.op, the same call as the Edit button) and reads the process table. Until WI-0088 the role editor is a
placeholder that ends at once with exit 3 (src/core/PlaceholderRole.ahk). So the tests here check what the supervisor
does with the request (the start, the name, the refusals); a running editor is only seen while it lives, and a test that
needs a live editor reads the answer of the start, not the process.

The test roles of the supervisor (--test-roles) lower the editor limit (--editor-limit), so the limit needs no 21 processes.
"""

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


def edit_answer(payload):
    """The answer of cmd.editor.open in an op result: (sent, ok, code, started)."""
    answer = payload.get("answer") or {}
    started = (answer.get("payload") or {}).get("started")
    return payload["sent"], answer.get("ok"), answer.get("code"), started


def start_manager(procs, datadir, session_id, extra=()):
    flow_data(datadir)
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


def test_edit_button_is_enabled_for_exactly_one_selected_flow(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        assert state(obs)["buttons"]["Edit"] is False                 # no flow selected
        op(obs, "select", flowId=FLOW)
        assert state(obs)["buttons"]["Edit"] is True                  # one flow
        op(obs, "select", flowId="")
        assert state(obs)["buttons"]["Edit"] is False
    finally:
        obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
        assert sup.wait_exit(20) == 0


def test_edit_starts_the_editor_process_of_the_flow(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        sent, ok, code, started = edit_answer(op(obs, "edit"))
        assert (sent, ok, code, started) == (True, True, "", True), state(obs)["lastAnswer"]
        assert wait_until(lambda: EDITOR in process_states(obs), scaled(10)), "no process %s" % EDITOR
        assert wait_until(lambda: any(("editor of '%s' started" % FLOW) in t for t in supervisor_log(obs)), scaled(10)), \
            supervisor_log(obs)
    finally:
        obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
        assert sup.wait_exit(20) == 0


def test_a_flow_id_with_a_space_reaches_the_editor_whole(procs, datadir, session_id):
    """The command line quotes --flow: the editor of "Flow 1010290492" is one process with that flow ID (the
    round trip of the role's own command line is tested in tests/integration/test_supervisor.py)."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        sent, ok, code, started = edit_answer(op(obs, "edit", flowId=SPACED_FLOW))
        assert (sent, ok, started) == (True, True, True), state(obs)["lastAnswer"]
        assert wait_until(lambda: ("editor:" + SPACED_FLOW) in process_states(obs), scaled(10))
    finally:
        obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
        assert sup.wait_exit(20) == 0


def test_edit_without_a_flow_is_refused_as_bad_payload_and_becomes_a_notice(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        sent, ok, code, started = edit_answer(op(obs, "edit", flowId=""))
        assert (sent, ok, code) == (True, False, "bad_payload"), state(obs)["lastAnswer"]
        notices = state(obs)["notices"]
        assert any(n["key"] == "Editor_open_failed" and n["level"] == "error" for n in notices), notices
    finally:
        obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
        assert sup.wait_exit(20) == 0


def test_a_sender_other_than_the_manager_is_denied(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        ans = obs.request("supervisor", "cmd.editor.open", {"flowId": FLOW}, timeout=scaled(5))
        assert ans["payload"]["ok"] is False, ans
        assert ans["payload"]["error"]["code"] == "denied", ans
        assert EDITOR not in process_states(obs)
    finally:
        obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
        assert sup.wait_exit(20) == 0


def test_a_second_edit_of_a_running_flow_starts_no_second_process(procs, datadir, session_id):
    """Second Edit of the same flow: answered started false, the process of the first start is kept. The first editor is
    still counted as running only until the supervisor has judged its end (the next tick, 200 ms); the second request
    follows the first at once, so the test needs the editor to live that long (see the module doc)."""
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        first = edit_answer(op(obs, "edit", flowId=FLOW))
        assert first[3] is True, first
        pid = process_states(obs).get(EDITOR, {}).get("pid")
        second = edit_answer(op(obs, "edit", flowId=FLOW))
        assert second[3] is False, second
        assert process_states(obs).get(EDITOR, {}).get("pid") == pid
    finally:
        obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
        assert sup.wait_exit(20) == 0


def test_the_editor_limit_refuses_a_new_editor_with_busy(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, extra=("--test-roles", "--editor-limit=1"))
    try:
        first = edit_answer(op(obs, "edit", flowId=FLOW))
        assert first[3] is True, first
        other = edit_answer(op(obs, "edit", flowId="other"))
        assert other[2] == "busy", other
        assert "editor:other" not in process_states(obs)
    finally:
        obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
        assert sup.wait_exit(20) == 0

