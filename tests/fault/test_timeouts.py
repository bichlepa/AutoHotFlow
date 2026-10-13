"""WI-15: unanswered requests end at their limit, exactly once; a late answer is dropped.

Two levels are covered:
  1. Hub.Request (the supervisor asks a UI for cmd.app.prepareExit, PROTOCOL 4.1). The UI is frozen, so
     no answer comes. The limit (--prepare-limit=500, test option) must end the request once with a
     timeout, the exit must go on, and the answer that comes after the thaw must be dropped. The stub
     answers cancel=1 (--stub-cancel-exit): if the late answer were counted, the exit would be cancelled.
  2. A client request to a frozen engine: the caller's own limit ends it (AhfTimeout), and the frozen
     engine is then ended and restarted by the supervisor, so no request waits forever.
"""

import time

import pytest

from faultkit import (EXIT_OK, FULL_CHAIN, REQUEST_BUDGET_S, STUB_OPTS, alive, event, repeat_ids, wait_until)
from support.ahfclient import AhfTimeout
from support.timing import scaled

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

PREPARE_LIMIT_MS = 500
THAW_AFTER_S = 1.2            # after the limit, before the exit would otherwise be over
CALLER_LIMIT_S = 1.0


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_hub_request_to_a_frozen_ui_times_out_once_and_the_late_answer_is_dropped(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS + ["--test-roles", "--prepare-limit=%d" % PREPARE_LIMIT_MS,
                                             "--stub-cancel-exit"])
    chain.wait_ready(["storage", "engine", "manager"])
    manager = chain.pid("manager")
    chain.freeze(manager)
    t0 = time.perf_counter()
    started = chain.request_exit()
    assert started["payload"]["started"], started
    time.sleep(THAW_AFTER_S)                 # the limit has passed; the UI answers now, too late
    chain.thaw(manager)
    code = chain.sup.wait_exit(timeout=30)
    elapsed = time.perf_counter() - t0
    print("\nMEASURE exit with a frozen UI at prepareExit (limit %d ms): %.2f s, exit %s"
          % (PREPARE_LIMIT_MS, elapsed, code))
    text = chain.sup.text()
    assert code == EXIT_OK, "the exit did not go on after the timeout:\n" + text
    assert chain.rec.find(event("evt.app.exitCancelled")) == [], "the late cancel was counted:\n" + text
    assert text.count("timed out") == 1, "the request must time out exactly once:\n" + text
    assert "late or unknown answer" in text, "the late answer was not dropped visibly:\n" + text
    assert elapsed < THAW_AFTER_S + scaled(5.0), elapsed


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_request_to_a_frozen_engine_ends_at_the_callers_limit_and_the_engine_is_then_restarted(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    chain.wait_ready(["storage", "engine", "manager"])
    engine = chain.pid("engine")
    chain.freeze(engine)
    t0 = time.perf_counter()
    with pytest.raises(AhfTimeout):
        chain.obs.request("engine", "cmd.engine.snapshot", {}, timeout=CALLER_LIMIT_S)
    waited = time.perf_counter() - t0
    print("\nMEASURE request to a frozen engine ended after %.3f s (limit %.1f s)" % (waited, CALLER_LIMIT_S))
    assert CALLER_LIMIT_S <= waited < CALLER_LIMIT_S + REQUEST_BUDGET_S, waited
    # the frozen engine is hung, ended and restarted; the next request is answered by the new one
    restarted = chain.rec.wait(event("evt.process.restarted", name="engine"), timeout=20)
    assert restarted is not None, "the frozen engine was not restarted:\n" + chain.sup.text()
    assert not alive(engine)
    new_pid, _ = chain.wait_restarted_ready("engine", engine, timeout=15)
    assert new_pid != engine
    assert "flows" in chain.snapshot_ok()
    assert wait_until(lambda: chain.states()["engine"]["restarts"] == 1, 2.0)
