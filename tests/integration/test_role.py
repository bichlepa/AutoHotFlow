"""WI-06: entry point and role base (src/AutoHotFlow.ahk, src/core/Role.ahk, src/core/RoleRegistry.ahk).

The role under test is the echo role (tests/integration/helpers/EchoRole.ahk). It is started the way
the protocol describes, through the entry point and tools/ahkrun.py (never the interpreter directly).
The hub is the Python stand-in tests/support/pyhub.py, with the wake-up of WakingHub (test_peer.py).
Exit codes: 0 normal end, 1 start failure, 2 bad arguments or unknown role, 3 not implemented,
4 hub lost (orphan guard) or peer closed.
"""

import subprocess
import sys
import time
from pathlib import Path

import psutil
import pytest

from support.ahfclient import AhfClient, make_envelope
from test_peer import WakingHub

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / "src" / "AutoHotFlow.ahk"
AHKRUN = ROOT / "tools" / "ahkrun.py"

EXIT_OK = 0
EXIT_BAD_ARGS = 2
EXIT_NOT_IMPLEMENTED = 3
EXIT_HUB_LOST = 4
ORPHAN_BUDGET_S = 3.0      # Role.ORPHAN_MS
ORPHAN_SLACK_S = 3.0       # reconnect and scheduling slack on top of the budget
SHUTDOWN_LIMIT_S = 1.0     # acceptance: sys.shutdown -> sys.bye and exit 0 within 1 s


class RoleHub(WakingHub):
    """WakingHub with a way for the test to send a message to a connected peer."""

    def send_to(self, name, type_, payload):
        with self._lock:
            link = next((l for l in self._links if l.name == name), None)
        assert link is not None, "no peer %r connected to the hub" % name
        assert link.send(make_envelope("supervisor", "supervisor#900", name, type_, None, None, payload))


class RoleRun:
    """One entry point process (ahkrun.py -> AutoHotkey). Output goes to files, not to pipes."""

    def __init__(self, procs, datadir, label, args):
        self.stdout_path = Path(datadir) / ("%s.stdout" % label)
        self.stderr_path = Path(datadir) / ("%s.stderr" % label)
        self._out = open(self.stdout_path, "wb")
        self._err = open(self.stderr_path, "wb")
        cmd = [sys.executable, str(AHKRUN), "--timeout", "60", str(ENTRY), *args]
        self.proc = procs.start(cmd, stdout=self._out, stderr=self._err, cwd=str(ROOT))
        self.ahk_process = None   # psutil.Process of AutoHotkey, set by ahk_for()

    def wait_exit(self, timeout):
        """Exit code of ahkrun (= the script's exit code), or None if it did not end in time."""
        try:
            return self.proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            return None

    def stderr_text(self):
        self._err.flush()
        return self.stderr_path.read_bytes().decode("utf-8", "replace")

    def stdout_text(self):
        self._out.flush()
        return self.stdout_path.read_bytes().decode("utf-8", "replace")

    def close_files(self):
        self._out.close()
        self._err.close()


def start_role(procs, datadir, pipe, session, role, *extra):
    # --test-roles: the echo role is a test role and is registered only with the flag (WI-07)
    args = ["--role=" + role, "--session=" + session, "--hub=" + pipe, "--data=" + str(datadir), "--test-roles", *extra]
    return RoleRun(procs, datadir, role.replace(":", "_"), args)


def wait_hello(hub, name, timeout=15.0):
    """Waits for the sys.hello of a role. Returns its process id (from the hello payload)."""
    msg = hub.wait_received(lambda m: m.get("type") == "sys.hello" and m.get("from") == name, timeout=timeout)
    assert msg is not None, "role %r never said hello; hub saw %s" % (name, [m.get("type") for m in hub.received])
    return msg["payload"]["pid"]


def ahk_process(pid):
    """psutil handle of the AutoHotkey process. Created while it is alive, so its exit can be waited for."""
    return psutil.Process(pid)


def request_ok(py, to, type_, payload, timeout=5.0):
    answer = py.request(to, type_, payload, timeout=timeout)
    assert answer["type"] == "res." + type_[4:], answer
    assert answer["payload"]["ok"], answer
    return answer["payload"]


@pytest.fixture
def pipe(session_id):
    return "ahf.role.%s" % session_id


@pytest.fixture
def runs(procs):
    """Closes the output files of every run at teardown (the processes are killed by procs)."""
    started = []
    yield started
    for run in started:
        run.close_files()


def launch(procs, datadir, runs, pipe, session, role, *extra):
    run = start_role(procs, datadir, pipe, session, role, *extra)
    runs.append(run)
    return run


# --- entry point ----------------------------------------------------------------------------------

def test_unknown_role_exits_2_with_message_and_no_dialog(procs, datadir, runs, session_id, pipe):
    run = launch(procs, datadir, runs, pipe, session_id, "nonexistent")
    code = run.wait_exit(timeout=30)
    assert code == EXIT_BAD_ARGS, "exit %s, stderr: %s" % (code, run.stderr_text())   # 97 would mean a dialog
    assert "unknown role 'nonexistent'" in run.stderr_text()


def test_missing_connection_arguments_exit_2(procs, datadir, runs, session_id):
    run = RoleRun(procs, datadir, "noargs", ["--role=echo", "--test-roles", "--session=" + session_id])
    runs.append(run)
    code = run.wait_exit(timeout=30)
    assert code == EXIT_BAD_ARGS, run.stderr_text()
    assert "--hub" in run.stderr_text() and "--data" in run.stderr_text()


def test_role_without_implementation_reports_not_implemented(procs, datadir, runs, session_id, pipe):
    # "engine" (WI-10), "worker" (WI-11) and "storage" (WI-12) are implemented; "triggerhost" is still a placeholder (WI-14).
    run = launch(procs, datadir, runs, pipe, session_id, "triggerhost")
    code = run.wait_exit(timeout=30)
    assert code == EXIT_NOT_IMPLEMENTED, "exit %s, stderr: %s" % (code, run.stderr_text())
    assert "role 'triggerhost' is not implemented yet" in run.stderr_text()


# --- echo role against the Python hub -------------------------------------------------------------

def test_echo_role_says_hello_and_answers_a_command(procs, datadir, runs, session_id, pipe):
    with RoleHub(pipe) as hub:
        run = launch(procs, datadir, runs, pipe, session_id, "echo")
        pid = wait_hello(hub, "echo")
        hello = next(m for m in hub.received if m.get("type") == "sys.hello" and m.get("from") == "echo")
        assert hello["to"] == "supervisor" and hello["corr"] is None
        assert hello["payload"]["name"] == "echo" and hello["payload"]["protocol"] == 1
        assert psutil.Process(pid).ppid() == run.proc.pid, "AutoHotkey is not the child of ahkrun"
        with AhfClient(pipe, "py") as py:
            payload = request_ok(py, "echo", "cmd.test.echo", {"x": 1, "text": "hallo"})
            assert payload["echo"]["x"] == 1 and payload["echo"]["text"] == "hallo"
        ahk = ahk_process(pid)
        hub.send_to("echo", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
        assert ahk.wait(timeout=10) == EXIT_OK
        assert run.wait_exit(timeout=10) == EXIT_OK, run.stderr_text()


def test_ping_is_answered_by_the_peer(procs, datadir, runs, session_id, pipe):
    with RoleHub(pipe) as hub:
        launch(procs, datadir, runs, pipe, session_id, "echo")
        pid = wait_hello(hub, "echo")
        hub.send_to("echo", "sys.ping", {"n": 7})
        pong = hub.wait_received(lambda m: m.get("type") == "sys.pong" and m.get("from") == "echo", timeout=5)
        assert pong is not None and pong["payload"]["n"] == 7
        hub.send_to("echo", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
        assert ahk_process(pid).wait(timeout=10) == EXIT_OK


def test_shutdown_sends_bye_and_exits_0_within_one_second(procs, datadir, runs, session_id, pipe):
    with RoleHub(pipe) as hub:
        run = launch(procs, datadir, runs, pipe, session_id, "echo")
        pid = wait_hello(hub, "echo")
        ahk = ahk_process(pid)
        with AhfClient(pipe, "py") as py:
            request_ok(py, "echo", "cmd.test.echo", {})     # the role is ready and serving
        started = time.perf_counter()
        hub.send_to("echo", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
        code = ahk.wait(timeout=SHUTDOWN_LIMIT_S + 4.0)
        elapsed = time.perf_counter() - started
        bye = hub.wait_received(lambda m: m.get("type") == "sys.bye" and m.get("from") == "echo", timeout=2)
        assert code == EXIT_OK, run.stderr_text()
        assert elapsed <= SHUTDOWN_LIMIT_S, "shutdown took %.3f s" % elapsed
        assert bye is not None and bye["to"] == "supervisor" and bye["payload"]["clean"]
        assert not psutil.pid_exists(pid)
        assert run.wait_exit(timeout=10) == EXIT_OK
        print("\nsys.shutdown -> exit 0 in %.1f ms" % (elapsed * 1000))


def test_hub_gone_role_ends_within_orphan_budget_and_leaves_no_process(procs, datadir, runs, session_id, pipe):
    hub = RoleHub(pipe).start()
    try:
        run = launch(procs, datadir, runs, pipe, session_id, "echo")
        pid = wait_hello(hub, "echo")
        ahk = ahk_process(pid)
        started = time.perf_counter()
        hub.stop()
        code = ahk.wait(timeout=ORPHAN_BUDGET_S + ORPHAN_SLACK_S + 5.0)
        elapsed = time.perf_counter() - started
    finally:
        hub.stop()
    assert code == EXIT_HUB_LOST, run.stderr_text()
    assert elapsed <= ORPHAN_BUDGET_S + ORPHAN_SLACK_S, "role ended after %.2f s" % elapsed
    # ahkrun copies the role's stderr only when it ends itself, so wait for it before reading stderr
    assert run.wait_exit(timeout=10) == EXIT_HUB_LOST
    assert "hub not reachable" in run.stderr_text()
    assert not psutil.pid_exists(pid)
    assert not psutil.pid_exists(run.proc.pid), "ahkrun left behind"
    print("\nhub stopped -> role ended with exit 4 after %.2f s" % elapsed)


# --- base class behavior -------------------------------------------------------------------------

def test_error_in_a_timer_is_logged_and_the_role_keeps_running(procs, datadir, runs, session_id, pipe):
    with RoleHub(pipe) as hub:
        run = launch(procs, datadir, runs, pipe, session_id, "echo")
        pid = wait_hello(hub, "echo")
        ahk = ahk_process(pid)
        with AhfClient(pipe, "py") as py:
            request_ok(py, "echo", "cmd.test.throwlater", {})
            time.sleep(0.5)                                  # the error happens in the timer
            assert ahk.is_running() and ahk.status() != psutil.STATUS_ZOMBIE
            request_ok(py, "echo", "cmd.test.echo", {"after": "error"})  # still serving
            state = request_ok(py, "echo", "cmd.test.logstate", {})
            assert "ValueError" in state["last"] and "deliberate error from a timer" in state["last"], state
        hub.send_to("echo", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
        assert ahk.wait(timeout=10) == EXIT_OK, run.stderr_text()


def test_log_queue_keeps_500_and_sends_them_when_storage_is_the_target(procs, datadir, runs, session_id, pipe):
    with RoleHub(pipe) as hub, AhfClient(pipe, "storage") as storage:
        run = launch(procs, datadir, runs, pipe, session_id, "echo")
        pid = wait_hello(hub, "echo")
        ahk = ahk_process(pid)
        with AhfClient(pipe, "py") as py:
            request_ok(py, "echo", "cmd.test.echo", {})
            request_ok(py, "echo", "cmd.test.log", {"count": 600})
            state = request_ok(py, "echo", "cmd.test.logstate", {})
            assert state["queued"] == 500 and state["dropped"] == 100, state
            assert state["last"] == "entry 600", state
            request_ok(py, "echo", "cmd.test.setlogtarget", {"to": "storage"})
            # the storage stand-in receives the 500 queued entries, oldest first, and nothing else
            entries = [m for m in storage.events(timeout=3.0) if m.get("type") == "evt.log.append"]
            assert len(entries) == 500, len(entries)
            assert entries[0]["payload"]["text"] == "entry 101" and entries[-1]["payload"]["text"] == "entry 600"
            assert entries[0]["from"] == "echo" and entries[0]["payload"]["source"] == "echo"
            assert entries[0]["payload"]["level"] == "a1" and "ts" in entries[0]["payload"]
            # with the target set, a new entry goes out at once
            request_ok(py, "echo", "cmd.test.log", {"count": 1})
            direct = storage.wait_event("evt.log.append", timeout=5.0)
            assert direct["payload"]["text"] == "entry 1"
        hub.send_to("echo", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
        assert ahk.wait(timeout=10) == EXIT_OK, run.stderr_text()
