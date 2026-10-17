"""WI-0061: the trigger host is killed hard (TerminateProcess) and the supervisor restarts it once (ARCHITECTURE 6.2).

Expected: the supervisor reports evt.process.crashed for triggerhost within CRASH_BUDGET_S of the death, restarts it
(attempt 1, evt.process.restarted), the restarted host answers requests with no armed triggers, and the other roles keep
their pid. Re-arming the triggers after the restart is the engine's job (WI-0062), so nothing is armed here.
"""

import psutil
import pytest

from faultkit import CRASH_BUDGET_S, HEADLESS_OPTS, event, repeat_ids, request_ok
from faultfixtures import chains  # noqa: F401  (fixture)
from support.timing import scaled

pytestmark = pytest.mark.fault
CHAIN = "storage,engine,manager,triggerhost"


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_killed_triggerhost_is_reported_restarted_and_answers_again(chains, round_no):
    chain = chains(CHAIN, HEADLESS_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager", "triggerhost"])
    pid = before["triggerhost"]
    psutil.Process(pid).kill()
    crashed = chain.rec.wait(event("evt.process.crashed", name="triggerhost"), timeout=CRASH_BUDGET_S + 5)
    assert crashed is not None, "no evt.process.crashed for triggerhost:\n" + chain.sup.text()
    assert crashed[1]["payload"]["pid"] == pid and crashed[1]["payload"]["restart"], crashed[1]
    new_pid, t_ready = chain.wait_restarted_ready("triggerhost", pid)
    restarted = chain.rec.wait(event("evt.process.restarted", name="triggerhost"), timeout=scaled(5))
    assert restarted and restarted[1]["payload"]["attempt"] == 1, restarted
    answer = request_ok(chain.obs, "triggerhost", "cmd.diag.snapshot", {}, timeout=5)
    assert answer["snapshot"]["info"]["armed"] == [], answer
    after = chain.states()
    assert after["engine"]["pid"] == before["engine"] and after["engine"]["state"] == "ready"
    assert after["storage"]["pid"] == before["storage"] and after["manager"]["pid"] == before["manager"]
