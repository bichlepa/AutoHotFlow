"""WI-22 point 1: the supervisor itself stands still (frozen process, as in standby or after a long backlog).

Expected (ARCHITECTURE 6.2): after the stand-still no child is judged by its old pong time. No
evt.process.hung, no evt.process.crashed, all pids unchanged, all roles ready. The children do not give
up during the freeze either (their orphan guard acts only on a broken pipe, which a frozen hub does not cause).
A child that really is frozen afterwards is still found (test_process_hang).
"""

import time

import psutil
import pytest

from faultkit import FULL_CHAIN, STUB_OPTS, alive, connect, event, repeat_ids, wait_until
from support import winpipe

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

FREEZE_S = 8.0          # longer than the pong timeout (6 s)
SETTLE_S = 4.0          # after the thaw: ping schedule restarts, a wrong verdict would fall here


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_supervisor_stand_still_does_not_make_healthy_children_hung(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    # worker:1 is the warm worker the engine asks for when it is ready (WI-27). A worker that is still in its handshake
    # when the hub freezes gives up after 3 s (no welcome), which is right but not what this test is about.
    before = chain.wait_ready(["storage", "engine", "manager", "worker:1"])
    sup_pid = chain.sup.ahk_pid()
    sup = psutil.Process(sup_pid)
    sup.suspend()
    try:
        time.sleep(FREEZE_S)
        # the children did not give up on their own while the hub was frozen
        for name, pid in before.items():
            assert alive(pid), "%s ended during the stand-still of the supervisor" % name
    finally:
        sup.resume()
    time.sleep(SETTLE_S)
    hung = chain.rec.find(lambda m: m.get("type") in ("evt.process.hung", "evt.process.crashed"))
    if hung:
        chain.request_exit()
        chain.sup.wait_exit(timeout=30)
    assert not hung, "children judged after the stand-still: %s\n%s" % ([m["payload"] for _, m in hung],
                                                                        chain.sup.text())
    after = chain.states()
    for name, pid in before.items():
        assert after[name]["pid"] == pid and after[name]["state"] == "ready", (name, after[name])
    assert "flows" in chain.snapshot_ok()
    # ahkrun copies the stderr of the supervisor only when it ends: end the session, then read the log
    assert chain.request_exit()["payload"]["started"]
    assert chain.sup.wait_exit(timeout=30) == 0, chain.sup.text()
    assert "supervisor stood still" in chain.sup.text(), "stand-still not noticed: " + chain.sup.text()


# --- deadlines after a stand-still (WI-33, F-16, E12) ---------------------------------------------------------

PREPARE_LIMIT_MS = 5000
HELLO_LIMIT_S = 5.0     # Hub.HELLO_TIMEOUT_MS


def freeze_for(chain, seconds):
    """Suspends the supervisor interpreter for the given time. Returns the perf_counter time of the thaw."""
    sup = psutil.Process(chain.sup.ahk_pid())
    sup.suspend()
    try:
        time.sleep(seconds)
    finally:
        sup.resume()
    return time.perf_counter()


@pytest.mark.slow
def test_open_prepare_exit_request_keeps_its_remaining_time_after_a_stand_still(chains):
    """The answer limit of cmd.app.prepareExit (5 s) is still open when the supervisor stands still for 8 s. After the
    thaw the request has the rest of its time (a timeout means "no cancel": the session would end at once)."""
    chain = chains("storage", ["--test-roles", "--prepare-limit=%d" % PREPARE_LIMIT_MS])
    chain.wait_ready(["storage"])
    manager = connect(chain.sup.pipe, "manager")
    try:
        assert chain.request_exit()["payload"]["started"]
        request = manager.wait_event("cmd.app.prepareExit", timeout=5)
        assert request is not None
        t_thaw = freeze_for(chain, FREEZE_S)
        code = chain.sup.wait_exit(timeout=30)
        after = time.perf_counter() - t_thaw
        print("\nMEASURE prepareExit (limit 5 s) open during a stand-still of %.0f s: exit %.2f s after the thaw"
              % (FREEZE_S, after))
        assert code == 0, chain.sup.text()
        # the rest of the limit is about 4.5 s; without the fix the request ends at the first tick after the thaw
        assert after > 3.0, "the request ran out at once after the stand-still: exit %.2f s after the thaw" % after
        assert "supervisor stood still" in chain.sup.text()
    finally:
        manager.close()


@pytest.mark.slow
def test_connection_without_hello_keeps_its_remaining_time_after_a_stand_still(chains):
    """A new connection has 5 s to say sys.hello. The supervisor stands still for 8 s after 1.5 s of it: the connection
    is not closed at once after the thaw, but after the rest of its time."""
    chain = chains("storage", ["--test-roles"])
    chain.wait_ready(["storage"])
    raw = winpipe.OverlappedPipe.connect_client(chain.sup.pipe, 5.0)
    try:
        time.sleep(1.5)             # the hub has accepted the connection (every tick), the hello clock runs
        t_thaw = freeze_for(chain, FREEZE_S)
        closed_at = None
        while time.perf_counter() - t_thaw < 12.0:
            try:
                raw.read_some(0.1)
            except winpipe.PipeClosed:
                closed_at = time.perf_counter() - t_thaw
                break
        print("\nMEASURE connection without hello (limit 5 s) after a stand-still of %.0f s: closed %s s after the thaw"
              % (FREEZE_S, "%.2f" % closed_at if closed_at is not None else "never"))
        assert closed_at is not None, "the connection without hello was never closed"
        # the rest is about 3.5 s; without the fix it is closed at the first tick after the thaw
        assert closed_at > 2.0, "closed at once after the stand-still: %.2f s after the thaw" % closed_at
    finally:
        raw.close()
