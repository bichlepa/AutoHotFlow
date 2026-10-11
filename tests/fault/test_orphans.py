"""WI-15: the supervisor is killed hard. Its children must not survive it (orphan guard, ARCHITEKTUR 6.3).

Each role keeps trying to reach the hub for ORPHAN_MS (3 s) and then ends with exit 4 (Role.EXIT_HUB_LOST).
The budget of the test is ORPHAN_BUDGET_S (3 s plus 2 s of slack, WI-15). Nothing may be left behind.
"""

import time

import psutil
import pytest

from faultkit import (EXIT_HUB_LOST, FULL_CHAIN, ORPHAN_BUDGET_S, STUB_OPTS, death_watch, repeat_ids,
                      session_processes, wait_until)

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault


@pytest.mark.parametrize("round_no", repeat_ids())
def test_children_end_within_the_orphan_budget_when_the_supervisor_is_killed(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    pids = chain.wait_ready(["storage", "engine", "manager"])
    ahk = chain.sup.ahk_pid()
    deaths, codes = {}, {}
    for pid in pids.values():
        death_watch(pid, deaths, codes)
    t_kill = time.perf_counter()
    psutil.Process(ahk).kill()
    assert wait_until(lambda: all(pid in deaths for pid in pids.values()), ORPHAN_BUDGET_S + 2.0, step=0.02), \
        "children still alive %.1f s after the supervisor was killed: %s" % (
            ORPHAN_BUDGET_S + 2.0, [n for n, p in pids.items() if p not in deaths])
    for name, pid in pids.items():
        lag = deaths[pid] - t_kill
        print("\nMEASURE orphan %s ended %.2f s after the supervisor was killed" % (name, lag))
        assert lag <= ORPHAN_BUDGET_S, "%s ended %.2f s after the kill (budget %.1f s)" % (name, lag, ORPHAN_BUDGET_S)
        code = codes.get(pid)
        assert code == EXIT_HUB_LOST, "%s exited with %s, expected %d (hub lost)" % (name, code, EXIT_HUB_LOST)
    # the entry point (ahkrun) ends too, and nothing of the session is left
    assert chain.sup.wait_exit(timeout=10) is not None
    assert wait_until(lambda: not session_processes(chain.session), 5.0), session_processes(chain.session)
