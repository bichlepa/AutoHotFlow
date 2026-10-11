"""WI-22 point 1: the supervisor itself stands still (frozen process, as in standby or after a long backlog).

Expected (ARCHITEKTUR 6.2): after the stand-still no child is judged by its old pong time. No
evt.process.hung, no evt.process.crashed, all pids unchanged, all roles ready. The children do not give
up during the freeze either (their orphan guard acts only on a broken pipe, which a frozen hub does not cause).
A child that really is frozen afterwards is still found (test_process_hang).
"""

import time

import psutil
import pytest

from faultkit import FULL_CHAIN, STUB_OPTS, alive, event, repeat_ids, wait_until

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

FREEZE_S = 8.0          # longer than the pong timeout (6 s)
SETTLE_S = 4.0          # after the thaw: ping schedule restarts, a wrong verdict would fall here


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
