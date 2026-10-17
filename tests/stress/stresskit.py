"""Shared helpers of the stress tests (WI-0016, doc/TEST-STRATEGY.md 3).

Built on the chain of the fault injection tests (tests/fault/faultkit.py): a real supervisor with storage,
engine and the manager stub, started through tools/ahkrun.py. Every process carries the session id in its
command line, so a test finds its own leftovers and never touches anything else.

Python clients do not own a window, so the hub only sees their writes on its 250 ms fallback timer
(HOW-TO "Stand-in-Hub ohne Weckruf"). Real clients (AHK roles) wake the hub with PostMessage after every
write. StressClient does the same with the hub window, so latencies measure the system and not the timer.
Pass wake=False to see the unwoken behaviour.
"""

import ctypes
import json
import sys
import time
from ctypes import wintypes
from pathlib import Path

import pytest

TESTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TESTS_DIR / "fault"))

from faultkit import (FULL_CHAIN, SKELETON_SRC, HEADLESS_OPTS, Chain, session_processes, wait_until)  # noqa: E402
from support.ahfclient import AhfClient, wake  # noqa: E402

SLEEP_ELEMENT = "element0000000002"
RUN_TIMEOUT_S = 400            # ahkrun limit of the supervisor; the pytest timeout of each test is shorter


def _find_windows(pid, class_name="AutoHotkey"):
    user32 = ctypes.windll.user32
    user32.EnumWindows.argtypes = [ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM), wintypes.LPARAM]
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    found = []

    def visit(hwnd, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid:
            buf = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(hwnd, buf, 256)
            if buf.value == class_name:
                found.append(hwnd)
        return True

    user32.EnumWindows(ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)(visit), 0)
    return found


def hwnd_of(pid, timeout=5.0):
    """The hidden script window of an AutoHotkey process (the wake target of the hub)."""
    found = wait_until(lambda: _find_windows(pid), timeout)
    if not found:
        raise AssertionError("no AutoHotkey window for pid %d" % pid)
    return found[0]


class StressClient(AhfClient):
    """AhfClient that wakes the hub window after every write (what an AHK role does)."""

    hub_hwnd = 0

    def _write(self, text):
        super()._write(text)
        if self.hub_hwnd:
            wake(self.hub_hwnd)

    def send_many(self, to, type_, payloads, timeout_ms=None):
        """Sends many requests back to back and returns their ids (answers are collected with answer())."""
        return [self.send(to, type_, p, timeout_ms=timeout_ms) for p in payloads]

    def answer(self, msg_id, timeout=10.0):
        return self._wait_answer(msg_id, timeout)


def thread_stacks(threads):
    """Text with the current stack of each live thread (for the message of a test that has to give up)."""
    import traceback
    frames = sys._current_frames()
    out = []
    for t in threads:
        if t.is_alive() and t.ident in frames:
            out.append("--- " + t.name + chr(10) + "".join(traceback.format_stack(frames[t.ident])))
    return chr(10).join(out)


def write_flow(datadir, name, sleep_ms=200, policy="default"):
    """Flows/<name>.json: the skeleton flow with another sleep time and execution policy."""
    flow = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    flow["name"] = name
    flow["flowSettings"]["ExecutionPolicy"] = policy
    # The stress tests measure the engine itself: the runaway guard (WI-0066) limits the running instances by default.
    flow["flowSettings"]["maxParallelInstances"] = 0
    flow["allElements"][SLEEP_ELEMENT]["pars"] = {"Duration": str(sleep_ms), "Unit": "Milliseconds"}
    path = Path(datadir) / "Flows" / (name + ".json")
    path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(flow, ensure_ascii=False, indent=2), encoding="utf-8")


class StressChain:
    """A started chain (storage, engine, manager stub) with a hub window and a client factory."""

    def __init__(self, chain, wake_hub=True):
        self.chain = chain
        self.wake_hub = wake_hub
        self.session = chain.session
        self.clients = []
        self.sup_pid = chain.sup.ahk_pid()
        self.hub_hwnd = hwnd_of(self.sup_pid) if wake_hub else 0
        self.pids = {}

    def new_client(self, name):
        """A connected StressClient that the caller closes (thread safe)."""
        return _connect(self.chain.sup.pipe, name, self.hub_hwnd)

    def client(self, name, topics=()):
        """A connected StressClient, subscribed to the topics. Closed at teardown."""
        client = self.new_client(name)
        self.clients.append(client)
        for topic in topics:
            answer = client.request("supervisor", "cmd.topic.subscribe", {"topic": topic}, timeout=5)
            assert answer["payload"]["ok"], answer
        return client

    def close_clients(self):
        for c in self.clients:
            try:
                c.close()
            except Exception:
                pass
        self.clients = []

    def process_list(self):
        return self.chain.states()

    def wait_flows(self, names, timeout=10.0):
        """Waits until the engine has loaded the flows (process `ready` only says the engine said hello)."""
        def loaded():
            snap = self.chain.snapshot_ok()
            return set(names) <= {f["flowId"] for f in snap["flows"]}
        if not wait_until(loaded, timeout, step=0.1):
            raise AssertionError("engine did not load %s within %.1f s" % (names, timeout))


def _connect(pipe, name, hub_hwnd, timeout=15.0):
    cls = type("BoundStressClient", (StressClient,), {"hub_hwnd": hub_hwnd})
    deadline = time.monotonic() + timeout
    while True:
        try:
            return cls(pipe, name, connect_timeout=2.0)
        except Exception:
            if time.monotonic() > deadline:
                raise
            time.sleep(0.005)


@pytest.fixture
def stress_chain(procs, datadir, session_id):
    """Factory: stress_chain(flows={"name": (sleep_ms, policy)}, wake_hub=True) -> StressChain, started and ready."""
    made = []

    def make(flows=None, wake_hub=True, extra=HEADLESS_OPTS, start=FULL_CHAIN, wait=True,
             run_timeout=RUN_TIMEOUT_S):
        for name, (sleep_ms, policy) in (flows or {}).items():
            (Path(datadir) / "Flows").mkdir(exist_ok=True)
            write_flow(datadir, name, sleep_ms, policy)
        chain = Chain(procs, datadir, session_id, start, extra, run_timeout=run_timeout)
        sc = StressChain(chain, wake_hub=wake_hub)
        made.append(sc)
        if wait:
            sc.pids = chain.wait_ready([n for n in ("storage", "engine", "manager") if n in start])
            if flows:
                sc.wait_flows(list(flows))
        return sc

    yield make
    for sc in made:
        sc.close_clients()
        sc.chain.close()
    problems = []
    for sc in made:
        if not wait_until(lambda: not session_processes(sc.session), 5.0):
            problems.append((sc.session, session_processes(sc.session)))
    assert not problems, "processes left behind: %s" % problems
