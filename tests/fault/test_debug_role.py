"""WI-0028 step e: the role debug (src/debugview/), headless for the tests, and a smoke test of the window.
doc/PROTOCOL.md 4.9. The model is tested through cmd.test.debug (headless only); what the window looks like and how it
reacts to the mouse is for the project owner (WI-0028 result, "Handpruefung").

--command=debug is the second instance of the entry point: it hands the command to the running supervisor (exit 0) and
the supervisor starts the role if it is not running (PROTOCOL 4.1, cmd.app.command).
"""

import ctypes
import subprocess
import sys
import time

import psutil
import pytest

from faultkit import AHKRUN, ENTRY, ROOT, STUB_OPTS, event, request_ok, wait_until

from faultfixtures import chains  # noqa: F401  (fixture)
from support import snapshotschema

pytestmark = pytest.mark.fault

READY_S = 20.0
WINDOW_TITLE = "AutoHotFlow - debug"


def full_chain(chains, datadir, start="storage,engine,manager,debug", extra=()):
    chain = chains(start, [*STUB_OPTS, *extra])
    names = [n for n in start.split(",")]
    chain.wait_ready(names + ["worker:1"], timeout=READY_S)
    chain.wait_flows(timeout=READY_S)
    return chain


def dbg(chain, action, timeout=15.0, **payload):
    return request_ok(chain.obs, "debug", "cmd.test.debug", {"action": action, **payload}, timeout=timeout)


def second_instance(chain, datadir):
    """The real command line of a second instance: --command=debug. Returns its exit code."""
    cmd = [sys.executable, str(AHKRUN), "--timeout", "60", str(ENTRY), "--session=" + chain.session,
           "--data=" + str(datadir), "--command=debug"]
    return subprocess.run(cmd, cwd=str(ROOT), capture_output=True, timeout=90).returncode


def command(chain, text):
    return chain.obs.request("supervisor", "cmd.app.command", {"argv": [text]}, timeout=10)["payload"]


# --- the model, headless --------------------------------------------------------------------------------

def test_the_role_starts_with_start_debug_and_shows_the_process_table(chains, datadir):
    chain = full_chain(chains, datadir)
    state = wait_until(lambda: (lambda s: s if {"storage", "engine", "manager", "debug"} <= set(s["processes"]) else None)
                       (dbg(chain, "state")), 10.0)
    assert state, dbg(chain, "state")
    assert {"process", "log", "engine", "debug"} <= set(state["topics"])
    assert wait_until(lambda: "flow:skeleton" in dbg(chain, "state")["topics"], 10.0), dbg(chain, "state")
    snap = request_ok(chain.obs, "debug", "cmd.diag.snapshot", {})["snapshot"]
    snapshotschema.check_snapshot(snap, "debug")
    assert snap["info"]["paused"] is False


@pytest.mark.slow
def test_refresh_stores_the_snapshot_of_every_role_and_the_supervisor(chains, datadir):
    chain = full_chain(chains, datadir)
    # The window asks only processes that are ready (as it sees them). Wait until its table shows every role as
    # ready, not merely listed: in the state "starting" it gets the entry "not ready" instead of a snapshot (F-0034).
    # Waiting for worker:1 alone was not enough: a loaded run (--all) refreshed 4 of 6 now and then.
    roles = ("storage", "engine", "manager", "debug", "worker:1")
    assert wait_until(lambda: all(dbg(chain, "state")["states"].get(r) == "ready" for r in roles), 15.0),         dbg(chain, "state")["states"]
    answer = dbg(chain, "refresh")
    assert answer["refreshed"] >= 6, (answer, dbg(chain, "state")["states"])   # supervisor + the five roles
    assert {"supervisor", "storage", "engine", "manager", "debug", "worker:1"} <= set(answer["snapshots"]), answer
    text = dbg(chain, "snapshot", name="engine")["text"]
    assert '"role": "engine"' in text and '"flows"' in text and "\n" in text      # formatted JSON
    missing = chain.obs.request("debug", "cmd.test.debug", {"action": "snapshot", "name": "nobody"}, timeout=5)["payload"]
    assert missing["ok"] is False and missing["error"]["code"] == "not_found"


@pytest.mark.slow
def test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out(chains, datadir):
    # F-0034 (WI-0034): RefreshSnapshots asked only the ready processes and left the others out without a trace. The
    # window is meant to show such states. echo:slowhello says hello 4 s after its start, so it is "starting" here.
    late = "echo:slowhello4000"
    chain = chains("storage,debug," + late, ["--test-roles", *STUB_OPTS])
    chain.wait_ready(["storage", "debug"], timeout=READY_S)
    assert wait_until(lambda: late in dbg(chain, "state")["processes"], 10.0), dbg(chain, "state")
    # chain.wait_ready looks at the supervisor's events; the window's own table may still lag behind (a loaded run
    # refreshed 2 of 3 now and then, report showed every role ready).
    assert wait_until(lambda: all(dbg(chain, "state")["states"].get(r) == "ready" for r in ("storage", "debug")),
                      10.0), dbg(chain, "state")["states"]
    if dbg(chain, "state")["states"].get(late) != "starting":
        pytest.skip("the late child was already ready (machine too slow for the scenario)")
    answer = dbg(chain, "refresh")
    if answer["states"].get(late) != "starting":
        pytest.skip("the late child became ready during the refresh (machine too slow for the scenario)")
    assert late in answer["snapshots"], answer
    assert dbg(chain, "snapshot", name=late)["text"] == "not ready (state: starting)"
    assert answer["refreshed"] == 3, answer          # supervisor, storage, debug: the answers; the late child is not asked
    assert {"supervisor", "storage", "debug"} <= set(answer["snapshots"]), answer


def test_the_live_log_has_a_level_and_a_source_filter(chains, datadir):
    chain = chains("storage,echo:a,debug", ["--test-roles", *STUB_OPTS])
    chain.wait_ready(["storage", "echo:a", "debug"], timeout=READY_S)
    request_ok(chain.obs, "echo:a", "cmd.test.setlogtarget", {"to": "storage"})
    before = dbg(chain, "state")["logEntries"]
    for level in ("a0", "a1", "a2"):
        request_ok(chain.obs, "echo:a", "cmd.test.log", {"count": 3, "level": level, "text": "live-" + level})
    state = wait_until(lambda: (lambda s: s if s["logEntries"] >= before + 9 else None)(dbg(chain, "state")), 15.0)
    assert state, dbg(chain, "state")
    base = dbg(chain, "filter", level=3, source="")["logVisible"]
    only_errors = dbg(chain, "filter", level=0, source="")["logVisible"]
    assert 0 < only_errors < base, (only_errors, base)
    echo_only = dbg(chain, "filter", level=3, source="echo")["logVisible"]
    assert 9 <= echo_only < base, (echo_only, base)
    assert dbg(chain, "filter", level=3, source="no-such-source")["logVisible"] == 0
    assert dbg(chain, "filter", level=3, source="")["logVisible"] == base


@pytest.mark.slow
def test_the_event_stream_can_be_paused_and_resumed(chains, datadir):
    chain = full_chain(chains, datadir)
    assert wait_until(lambda: "flow:skeleton" in dbg(chain, "state")["topics"], 10.0)
    request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "flow:skeleton"})   # the observer needs the end events

    def run_flow():
        answer = request_ok(chain.obs, "engine", "cmd.flow.start", {"flowId": "skeleton"})
        assert chain.rec.wait(lambda m: m.get("type") == "evt.instance.ended"
                              and m["payload"].get("instanceId") == answer["instanceId"], timeout=15) is not None

    run_flow()
    assert wait_until(lambda: dbg(chain, "state")["engineEvents"] >= 6, 10.0), dbg(chain, "state")
    paused = dbg(chain, "pause")
    assert paused["paused"] is True
    shown = paused["eventsVisible"]
    run_flow()
    assert wait_until(lambda: dbg(chain, "state")["engineEvents"] > paused["engineEvents"] + 5, 10.0)
    still = dbg(chain, "state")
    assert still["paused"] is True and still["eventsVisible"] == shown, (shown, still)
    resumed = dbg(chain, "resume")
    assert resumed["paused"] is False and resumed["eventsVisible"] == resumed["engineEvents"] > shown


def test_dump_values_arrive_in_the_window(chains, datadir):
    chain = chains("storage,echo:a,debug", ["--test-roles", *STUB_OPTS])
    chain.wait_ready(["storage", "echo:a", "debug"], timeout=READY_S)
    request_ok(chain.obs, "echo:a", "cmd.test.dump", {"title": "loop state", "value": {"i": 3}})
    state = wait_until(lambda: (lambda s: s if "loop state" in s["dumps"] else None)(dbg(chain, "state")), 10.0)
    assert state, dbg(chain, "state")


@pytest.mark.slow
def test_the_export_button_writes_a_report_and_shows_the_path(chains, datadir):
    chain = full_chain(chains, datadir)
    answer = dbg(chain, "export", timeout=25.0)
    export = answer["export"]
    assert export["ok"] is True and export["path"].startswith("Reports/"), answer
    assert (datadir / export["path"] / "report.json").exists()
    assert answer["lastExport"].startswith("report written: "), answer["lastExport"]
    assert export["roles"] >= 5 and export["missing"] == [], export          # debug is in the report too


# --- starting and closing ----------------------------------------------------------------------------------

@pytest.mark.slow
def test_command_debug_starts_the_role_once_and_a_second_call_starts_no_second(chains, datadir):
    chain = full_chain(chains, datadir, start="storage,engine,manager")
    assert "debug" not in chain.states()
    first = command(chain, "debug")
    assert first["ok"] and first["command"] == "debug" and first["started"] is True, first
    pid = chain.wait_ready(["debug"], timeout=READY_S)["debug"]
    second = command(chain, "debug")
    assert second["ok"] and second["started"] is False, second
    # and the real second instance, the command line the user types
    assert second_instance(chain, datadir) == 0
    assert chain.pid("debug") == pid
    debug_processes = [n for n in chain.states() if n.startswith("debug")]
    assert debug_processes == ["debug"], debug_processes
    # an unknown command is logged and answered ok, nothing starts
    other = command(chain, "frobnicate")
    assert other["ok"] and "command" not in other


@pytest.mark.slow
def test_closing_the_window_ends_only_that_role_without_a_crash_and_it_can_be_opened_again(chains, datadir):
    chain = full_chain(chains, datadir)
    old = chain.pid("debug")
    dbg(chain, "close")
    exited = chain.rec.wait(event("evt.process.exited", name="debug"), timeout=10)
    assert exited is not None, chain.sup.text()
    assert exited[1]["payload"]["clean"] is True and exited[1]["payload"]["exitCode"] == 0, exited
    assert chain.rec.find(event("evt.process.crashed", name="debug")) == []
    assert chain.states()["debug"]["state"] == "exited"
    # a crash would write an automatic report within moments; give it that moment, then there must be none
    time.sleep(1.0)
    assert not (datadir / "Reports").exists() or not list((datadir / "Reports").glob("*")), "a normal exit wrote a report"
    # the others run on, and the command opens it again with a new process
    assert chain.states()["engine"]["state"] == "ready"
    again = command(chain, "debug")
    assert again["started"] is True, again
    new, _ = chain.wait_restarted_ready("debug", old, timeout=READY_S)
    assert new != old
    assert dbg(chain, "state")["processes"]


@pytest.mark.slow
def test_the_debug_role_is_not_restarted_when_it_crashes(chains, datadir):
    chain = full_chain(chains, datadir)
    psutil.Process(chain.pid("debug")).kill()
    crashed = chain.rec.wait(event("evt.process.crashed", name="debug"), timeout=10)
    assert crashed is not None and crashed[1]["payload"]["restart"] is False, crashed


def test_a_debug_role_in_the_session_ends_with_it(chains, datadir):
    chain = full_chain(chains, datadir)
    chain.request_exit()
    assert chain.sup.wait_exit(timeout=20) == 0, chain.sup.text()


# --- the window (smoke test, no eyes) ------------------------------------------------------------------------

def window_of(pid):
    """Handles of the top-level windows of a process whose title is WINDOW_TITLE."""
    found = []
    user32 = ctypes.WinDLL("user32")      # not windll.user32: other test modules set argtypes on that shared object
    proc_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def visit(hwnd, _):
        owner = ctypes.c_ulong(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid:
            length = user32.GetWindowTextLengthW(hwnd)
            buf = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buf, length + 1)
            if buf.value == WINDOW_TITLE:
                found.append(hwnd)
        return True

    user32.EnumWindows(proc_type(visit), 0)
    return found


@pytest.mark.gui
def test_the_window_opens_takes_events_and_closes_like_a_user_would(chains, datadir):
    """No --headless: the role builds its window. The test checks that it opens, that events, log lines and dumps
    do not break the drawing (the role stays alive and answers), and that WM_CLOSE (the X button) ends only that role
    with a clean exit."""
    chain = chains("storage,engine,echo:a,debug", ["--test-roles"])
    chain.wait_ready(["storage", "engine", "echo:a", "debug"], timeout=READY_S)
    chain.wait_flows(timeout=READY_S)
    pid = chain.pid("debug")
    hwnds = wait_until(lambda: window_of(pid), 10.0)
    assert hwnds, "no window '%s' for pid %d" % (WINDOW_TITLE, pid)
    request_ok(chain.obs, "echo:a", "cmd.test.setlogtarget", {"to": "storage"})
    request_ok(chain.obs, "echo:a", "cmd.test.log", {"count": 20, "level": "a1", "text": "line for the window"})
    request_ok(chain.obs, "echo:a", "cmd.test.dump", {"title": "window dump", "value": {"a": [1, 2, 3]}})
    request_ok(chain.obs, "engine", "cmd.flow.start", {"flowId": "skeleton"})
    def arrived():
        info = request_ok(chain.obs, "debug", "cmd.diag.snapshot", {})["snapshot"]["info"]
        return "window dump" in info["dumps"] and info["logEntries"] >= 20
    assert wait_until(arrived, 15.0)
    time.sleep(0.5)       # a few render ticks (every 100 ms) with the new data: not an assertion, the window must survive them
    snap = request_ok(chain.obs, "debug", "cmd.diag.snapshot", {})["snapshot"]
    snapshotschema.check_snapshot(snap, "debug")
    assert snap["errors"]["count"] == 0, snap["errors"]            # drawing raised no error
    # the user closes the window (WM_CLOSE = 0x10)
    ctypes.WinDLL("user32").PostMessageW(ctypes.c_void_p(hwnds[0]), 0x10, 0, 0)
    exited = chain.rec.wait(event("evt.process.exited", name="debug"), timeout=10)
    assert exited is not None, chain.sup.text()
    assert exited[1]["payload"]["clean"] is True, exited
    assert chain.rec.find(event("evt.process.crashed", name="debug")) == []
