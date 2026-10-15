"""WI-0015: a role process is frozen (psutil suspend). UI stub, engine and storage.

Expected (ARCHITECTURE 6.2, PROTOCOL 4.1a): the supervisor misses three pongs (pings every 2 s, pong timeout
6 s), reports evt.process.hung within HANG_BUDGET_S of the freeze, sends sys.shutdown, terminates the
process after KILL_AFTER_MS, and reports evt.process.crashed with reason "hung". From there it is handled
like a crash: engine and storage restart by policy, the UI does not. The rest of the system keeps working.

The frozen process is thawed at teardown only if it still exists (the chain closes it).
"""

import time

import pytest

from support.timing import scaled

from faultkit import HANG_BUDGET_S, FULL_CHAIN, STUB_OPTS, alive, death_watch, event, repeat_ids, wait_until

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

CRASH_AFTER_HANG_S = scaled(4.0)      # hung -> terminated (KILL_AFTER_MS 2 s) -> reported, with slack
RECOVERY_BUDGET_S = 15.0      # frozen -> hung -> terminated -> restarted and ready (test value)


def freeze_and_expect_hung(chain, name):
    """Freezes a role and waits for evt.process.hung. Returns (pid, t_frozen, t_hung)."""
    pid = chain.pid(name)
    t_frozen = time.perf_counter()
    chain.freeze(pid)
    hung = chain.rec.wait(event("evt.process.hung", name=name), timeout=HANG_BUDGET_S + 4)
    assert hung is not None, "frozen %s was not reported as hung:\n%s" % (name, chain.sup.text())
    lag = hung[0] - t_frozen
    print("\nMEASURE %s frozen, reported hung after %.2f s" % (name, lag))
    assert lag <= HANG_BUDGET_S, "%s hung after %.2f s (budget %.1f s)" % (name, lag, HANG_BUDGET_S)
    return pid, t_frozen, hung[0]


def expect_terminated(chain, name, pid, t_hung, restart):
    """After the hang: the frozen process is ended by the supervisor, reported as a crash with reason hung."""
    death = {}
    # the process is still in the table until it is terminated: watch its end from now on
    death_watch(pid, death)
    crashed = chain.rec.wait(event("evt.process.crashed", name=name), timeout=CRASH_AFTER_HANG_S + 6)
    assert crashed is not None, "frozen %s was not ended:\n%s" % (name, chain.sup.text())
    assert crashed[1]["payload"]["reason"] == "hung", crashed[1]
    assert crashed[1]["payload"]["pid"] == pid, crashed[1]
    assert bool(crashed[1]["payload"]["restart"]) == restart, crashed[1]
    assert crashed[0] - t_hung <= CRASH_AFTER_HANG_S, "ended %.2f s after the hang" % (crashed[0] - t_hung)
    assert wait_until(lambda: pid in death, 3.0), "frozen %s still alive" % name
    assert not alive(pid), "frozen %s left behind" % name
    return crashed


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_frozen_engine_is_hung_ended_and_restarted_while_the_others_work(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager"])
    pid, t_frozen, t_hung = freeze_and_expect_hung(chain, "engine")
    expect_terminated(chain, "engine", pid, t_hung, restart=True)
    print("\nMEASURE frozen engine: ended %.2f s after the freeze" % (time.perf_counter() - t_frozen))
    new_pid, t_ready = chain.wait_restarted_ready("engine", pid, timeout=RECOVERY_BUDGET_S)
    print("\nMEASURE frozen engine: ready again %.2f s after the freeze" % (t_ready - t_frozen))
    assert new_pid != pid
    assert chain.rec.wait(lambda m: m.get("type") == "evt.engine.restarted", timeout=15) is not None
    after = chain.states()
    for other in ("storage", "manager"):
        assert after[other]["pid"] == before[other] and after[other]["state"] == "ready", (other, after[other])
    assert "flows" in chain.snapshot_ok()


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_frozen_storage_is_hung_ended_and_restarted_and_answers_again(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager"])
    pid, t_frozen, t_hung = freeze_and_expect_hung(chain, "storage")
    expect_terminated(chain, "storage", pid, t_hung, restart=True)
    new_pid, t_ready = chain.wait_restarted_ready("storage", pid, timeout=RECOVERY_BUDGET_S)
    print("\nMEASURE frozen storage: ready again %.2f s after the freeze" % (t_ready - t_frozen))
    answer = chain.obs.request("storage", "cmd.storage.flows.list", {}, timeout=5)
    assert answer["payload"]["ok"], answer
    after = chain.states()
    assert after["engine"]["pid"] == before["engine"] and after["engine"]["state"] == "ready"
    assert after["manager"]["pid"] == before["manager"] and after["manager"]["state"] == "ready"


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_frozen_ui_stub_is_hung_ended_and_not_restarted(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager"])
    pid, t_frozen, t_hung = freeze_and_expect_hung(chain, "manager")
    expect_terminated(chain, "manager", pid, t_hung, restart=False)
    time.sleep(0.5)
    assert not chain.rec.find(event("evt.process.restarted", name="manager"))
    after = chain.states()
    assert after["manager"]["state"] == "crashed" and after["manager"]["restarts"] == 0, after["manager"]
    assert after["engine"]["pid"] == before["engine"] and after["storage"]["pid"] == before["storage"]
    assert "flows" in chain.snapshot_ok()
