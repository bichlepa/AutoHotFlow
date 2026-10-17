"""WI-0015: the session is ended while the roles are healthy, while one role is frozen, while the UI cancels in
the prepare phase, and twice in a row (ARCHITECTURE 6.3, WI-0015 shutdown list).

Budgets: healthy roles exit within CLEAN_EXIT_BUDGET_S (2 s); with a frozen role the exit ends within the
deadline plus 1 s (the supervisor terminates the frozen process at the deadline, exit code 5).
"""

import time

import psutil
import pytest

from faultkit import (CLEAN_EXIT_BUDGET_S, EXIT_FORCED, EXIT_OK, FULL_CHAIN, HEADLESS_OPTS, alive, death_watch, describe_pid,
                      event, repeat_ids, session_processes, wait_until)

from faultfixtures import chains  # noqa: F401  (fixture)
from support.timing import scaled

pytestmark = pytest.mark.fault

DEADLINE_MS = 2000
FROZEN_EXIT_SLACK_S = scaled(1.0)
EVENT_LAG_S = scaled(1.0)             # the recorder thread of the observer may lag a few ms behind the supervisor exit


@pytest.mark.parametrize("round_no", repeat_ids())
def test_healthy_session_exits_within_2_seconds_and_every_role_says_it_is_clean(chains, round_no):
    chain = chains(FULL_CHAIN, HEADLESS_OPTS)
    pids = chain.wait_ready(["storage", "engine", "manager"])
    t0 = time.perf_counter()
    answer = chain.request_exit()
    assert answer["payload"]["started"] is True, answer
    code = chain.sup.wait_exit(timeout=30)
    elapsed = time.perf_counter() - t0
    print("\nMEASURE healthy session exit: %.3f s, exit %s" % (elapsed, code))
    assert code == EXIT_OK, chain.sup.text()
    assert elapsed <= CLEAN_EXIT_BUDGET_S, "exit took %.2f s" % elapsed
    for name in pids:
        exited = chain.rec.wait(event("evt.process.exited", name=name), timeout=EVENT_LAG_S)
        assert exited and exited[1]["payload"]["clean"] is True, (name, exited)
    assert not [p for p in pids.values() if alive(p)]
    assert wait_until(lambda: not session_processes(chain.session), 5.0), session_processes(chain.session)


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_frozen_storage_is_terminated_at_the_deadline_and_the_others_exit_clean(chains, round_no):
    chain = chains(FULL_CHAIN, HEADLESS_OPTS)
    pids = chain.wait_ready(["storage", "engine", "manager"])
    storage = pids["storage"]
    chain.freeze(storage)
    death = {}
    death_watch(storage, death)
    t0 = time.perf_counter()
    chain.request_exit({"deadlineMs": DEADLINE_MS})
    code = chain.sup.wait_exit(timeout=DEADLINE_MS / 1000 + 10)
    elapsed = time.perf_counter() - t0
    print("\nMEASURE exit with a frozen storage (deadline %d ms): %.2f s, exit %s" % (DEADLINE_MS, elapsed, code))
    assert code == EXIT_FORCED, chain.sup.text()
    assert elapsed <= DEADLINE_MS / 1000 + FROZEN_EXIT_SLACK_S, "exit took %.2f s" % elapsed
    assert wait_until(lambda: storage in death, 3.0), "frozen storage left behind"
    for name in ("engine", "manager"):
        exited = chain.rec.wait(event("evt.process.exited", name=name), timeout=EVENT_LAG_S)
        assert exited and exited[1]["payload"]["clean"] is True, (name, exited)
    assert wait_until(lambda: not session_processes(chain.session), 5.0), session_processes(chain.session)


@pytest.mark.parametrize("round_no", repeat_ids())
def test_ui_cancels_the_exit_in_phase_one_and_the_session_keeps_working(chains, procs, round_no):
    # --cancel-exit: the stub answers cmd.app.prepareExit with cancel. The stub cancels every exit, so
    # this test ends the session hard at its end (tree kill, as a last resort); the leftover check still applies.
    chain = chains(FULL_CHAIN, HEADLESS_OPTS + ["--cancel-exit"])
    pids = chain.wait_ready(["storage", "engine", "manager"])
    answer = chain.request_exit()
    assert answer["payload"]["started"] is True, answer
    cancelled = chain.rec.wait(event("evt.app.exitCancelled"), timeout=5)
    assert cancelled is not None, chain.sup.text()
    assert cancelled[1]["payload"]["by"] == "manager", cancelled[1]
    time.sleep(1.0)
    assert chain.sup.proc.poll() is None, "the cancelled exit ended the session:\n" + chain.sup.text()
    # nothing was stopped: every role is still ready with its pid, and the engine answers
    after = chain.states()
    for name, pid in pids.items():
        assert after[name]["pid"] == pid and after[name]["state"] == "ready", (name, after[name])
    assert "flows" in chain.snapshot_ok()
    procs.kill(chain.sup.proc)          # the stub cancels every exit: end the session here


LATE_HELLO_MS = 3000         # echo:slowhello<ms> connects this long after its start (EchoRole, WI-0034)
LATE_DEADLINE_MS = 12000     # far above the late hello: an exit at the deadline (the old fault) is easy to tell apart


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_a_child_that_says_hello_during_the_shutdown_gets_sys_shutdown_and_the_session_exits_clean(chains, round_no):
    # F-0037 (WI-0034): a child that is still starting when its group gets sys.shutdown (the warm worker, an editor, the
    # debug window) says sys.hello later. It must get sys.shutdown then; before the fix it never did, its group never
    # ended, storage (the last group) never got sys.shutdown, and both were terminated at the deadline (exit 5).
    late = "echo:slowhello%d" % LATE_HELLO_MS
    chain = chains("storage," + late, ["--test-roles"])
    pids = chain.wait_ready(["storage"])
    state = chain.states()[late]["state"]
    if state != "starting":
        pytest.skip("the late child was already %s when the exit began (machine too slow for the scenario)" % state)
    t0 = time.perf_counter()
    answer = chain.request_exit({"deadlineMs": LATE_DEADLINE_MS})
    assert answer["payload"]["started"] is True, answer
    code = chain.sup.wait_exit(timeout=LATE_DEADLINE_MS / 1000 + 10)
    elapsed = time.perf_counter() - t0
    print("\nMEASURE exit with a child that says hello during the shutdown: %.2f s, exit %s" % (elapsed, code))
    assert code == EXIT_OK, chain.sup.text()
    assert elapsed <= LATE_HELLO_MS / 1000 + CLEAN_EXIT_BUDGET_S, "exit took %.2f s" % elapsed
    assert chain.rec.wait(event("evt.process.ready", name=late), timeout=EVENT_LAG_S), "the late child never said hello"
    for name in ("storage", late):
        exited = chain.rec.wait(event("evt.process.exited", name=name), timeout=EVENT_LAG_S)
        assert exited and exited[1]["payload"]["clean"] is True, (name, exited)
    assert not alive(pids["storage"]), describe_pid(pids["storage"])   # F-0095: say what runs there
    assert wait_until(lambda: not session_processes(chain.session), 5.0), session_processes(chain.session)


SLOW_HELLO_MS = int(scaled(4000))      # F-0039: this child says hello long after the deadline
SLOW_DEADLINE_MS = int(scaled(1500))


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_a_child_that_has_not_connected_does_not_hold_storage_and_the_session_ends_with_storage_clean(chains, round_no):
    # F-0039: a child in state "starting" (here a worker whose hello comes after the deadline) used to hold its group and
    # with it storage, the last group. At the deadline storage was terminated without sys.shutdown (clean false). Now
    # the group does not wait for a child that has never connected: storage is told to shut down and ends clean; the
    # late child is the only one that is ended at the deadline (exit 5).
    late = "echo:slowhello%d" % SLOW_HELLO_MS
    chain = chains("storage," + late, ["--test-roles"])
    pids = chain.wait_ready(["storage"])
    state = chain.states()[late]["state"]
    if state != "starting":
        pytest.skip("the late child was already %s when the exit began (machine too slow for the scenario)" % state)
    answer = chain.request_exit({"deadlineMs": SLOW_DEADLINE_MS})
    assert answer["payload"]["started"] is True, answer
    code = chain.sup.wait_exit(timeout=SLOW_DEADLINE_MS / 1000 + scaled(10))
    assert code == EXIT_FORCED, "the late child must be ended at the deadline (exit 5), got %s" % code + chain.sup.text()
    exited = chain.rec.wait(event("evt.process.exited", name="storage"), timeout=EVENT_LAG_S)
    assert exited and exited[1]["payload"]["clean"] is True, ("storage was not told to shut down", exited, chain.sup.text())
    assert "terminating storage" not in chain.sup.text(), chain.sup.text()
    assert not alive(pids["storage"]), describe_pid(pids["storage"])   # F-0095: say what runs there
    assert wait_until(lambda: not session_processes(chain.session), 5.0), session_processes(chain.session)


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_two_sessions_in_a_row_both_exit_within_2_seconds(chains, round_no):
    for n in (1, 2):
        chain = chains(FULL_CHAIN, HEADLESS_OPTS, label="sup%d" % n)
        chain.wait_ready(["storage", "engine", "manager"])
        t0 = time.perf_counter()
        chain.request_exit()
        code = chain.sup.wait_exit(timeout=30)
        elapsed = time.perf_counter() - t0
        print("\nMEASURE session %d exit: %.3f s, exit %s" % (n, elapsed, code))
        assert code == EXIT_OK, chain.sup.text()
        assert elapsed <= CLEAN_EXIT_BUDGET_S, "session %d exit took %.2f s" % (n, elapsed)
        assert wait_until(lambda: not session_processes(chain.session), 5.0), session_processes(chain.session)
