"""WI-0015 helper check: the chain starts, answers, and ends without leftovers.

If this fails, the fault tests above it cannot be trusted: it checks the helpers themselves
(ready detection, pid lookup, freeze/thaw, leftover detection), not the system under test.
"""

import time

import psutil
import pytest

from faultkit import FULL_CHAIN, STUB_OPTS, alive, freeze, session_processes, thaw, wait_until

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault


def test_full_chain_starts_answers_and_ends_without_leftovers(chains):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    pids = chain.wait_ready(["storage", "engine", "manager"])
    assert len(set(pids.values())) == 3
    assert all(alive(pid) for pid in pids.values())
    # every child is a process below the supervisor's interpreter
    below = {c.pid for c in psutil.Process(chain.sup.ahk_pid()).children(recursive=True)}
    assert set(pids.values()) <= below
    snap = chain.snapshot_ok()
    assert "flows" in snap, snap
    answer = chain.request_exit()
    assert answer["payload"]["ok"], answer
    assert chain.sup.wait_exit(timeout=20) == 0, chain.sup.text()
    assert wait_until(lambda: not session_processes(chain.session), 5.0)


def test_freeze_and_thaw_are_seen_by_psutil_and_leave_no_process_behind(chains):
    chain = chains("storage")
    pid = chain.wait_ready(["storage"])["storage"]
    freeze(pid)
    # psutil reports the status with a delay of a few ms (HOW-TO, psutil-Status hinkt): poll it
    assert wait_until(lambda: psutil.Process(pid).status() == psutil.STATUS_STOPPED, 2.0, step=0.01)
    thaw(pid)
    assert wait_until(lambda: psutil.Process(pid).status() != psutil.STATUS_STOPPED, 2.0, step=0.01)
    time.sleep(0.05)
    assert alive(pid)
