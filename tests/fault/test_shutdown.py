"""WI-15: the session is ended while the roles are healthy, while one role is frozen, while the UI cancels in
the prepare phase, and twice in a row (ARCHITEKTUR 6.3, WI-15 shutdown list).

Budgets: healthy roles exit within CLEAN_EXIT_BUDGET_S (2 s); with a frozen role the exit ends within the
deadline plus 1 s (the supervisor terminates the frozen process at the deadline, exit code 5).
"""

import time

import psutil
import pytest

from faultkit import (CLEAN_EXIT_BUDGET_S, EXIT_FORCED, EXIT_OK, FULL_CHAIN, STUB_OPTS, alive, death_watch,
                      event, repeat_ids, session_processes, wait_until)

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

DEADLINE_MS = 2000
FROZEN_EXIT_SLACK_S = 1.0
EVENT_LAG_S = 1.0             # the recorder thread of the observer may lag a few ms behind the supervisor exit


@pytest.mark.parametrize("round_no", repeat_ids())
def test_healthy_session_exits_within_2_seconds_and_every_role_says_it_is_clean(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    pids = chain.wait_ready(["storage", "engine", "manager"])
    t0 = time.perf_counter()
    answer = chain.request_exit()
    assert answer["payload"]["started"], answer
    code = chain.sup.wait_exit(timeout=30)
    elapsed = time.perf_counter() - t0
    print("\nMEASURE healthy session exit: %.3f s, exit %s" % (elapsed, code))
    assert code == EXIT_OK, chain.sup.text()
    assert elapsed <= CLEAN_EXIT_BUDGET_S, "exit took %.2f s" % elapsed
    for name in pids:
        exited = chain.rec.wait(event("evt.process.exited", name=name), timeout=EVENT_LAG_S)
        assert exited and exited[1]["payload"]["clean"], (name, exited)
    assert not [p for p in pids.values() if alive(p)]
    assert wait_until(lambda: not session_processes(chain.session), 5.0), session_processes(chain.session)


@pytest.mark.parametrize("round_no", repeat_ids())
def test_frozen_storage_is_terminated_at_the_deadline_and_the_others_exit_clean(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
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
        assert exited and exited[1]["payload"]["clean"], (name, exited)
    assert wait_until(lambda: not session_processes(chain.session), 5.0), session_processes(chain.session)


@pytest.mark.parametrize("round_no", repeat_ids())
def test_ui_cancels_the_exit_in_phase_one_and_the_session_keeps_working(chains, procs, round_no):
    # --stub-cancel-exit: the stub answers cmd.app.prepareExit with cancel. The stub cancels every exit, so
    # this test ends the session hard at its end (tree kill, as a last resort); the leftover check still applies.
    chain = chains(FULL_CHAIN, STUB_OPTS + ["--stub-cancel-exit"])
    pids = chain.wait_ready(["storage", "engine", "manager"])
    answer = chain.request_exit()
    assert answer["payload"]["started"], answer
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


@pytest.mark.parametrize("round_no", repeat_ids())
def test_two_sessions_in_a_row_both_exit_within_2_seconds(chains, round_no):
    for n in (1, 2):
        chain = chains(FULL_CHAIN, STUB_OPTS, label="sup%d" % n)
        chain.wait_ready(["storage", "engine", "manager"])
        t0 = time.perf_counter()
        chain.request_exit()
        code = chain.sup.wait_exit(timeout=30)
        elapsed = time.perf_counter() - t0
        print("\nMEASURE session %d exit: %.3f s, exit %s" % (n, elapsed, code))
        assert code == EXIT_OK, chain.sup.text()
        assert elapsed <= CLEAN_EXIT_BUDGET_S, "session %d exit took %.2f s" % (n, elapsed)
        assert wait_until(lambda: not session_processes(chain.session), 5.0), session_processes(chain.session)
