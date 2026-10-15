"""WI-0016: endurance run with mixed operations (marker `soak`, run with `-m soak`).

Duration: AHF_SOAK_SECONDS (default 600). Mixed load (about 130 engine events per second, six times the load before WI-0025: the manager stub writes every
event to the storage log, and the storage drains well over 1000 lines per second since WI-0025, finding F-0007; the
rate is AHF_SOAK_BURST starts of the short flow every 0.25 s, default 4): parallel bursts of a short flow, start/stop of a long
flow, snapshot requests, flow toggles. AHF_SOAK_CHURN=1 adds clients that connect and leave (off by default:
that path has its own test, finding F-0006 would make every soak run red).

At the start of the measured phase (after a warm-up of a quarter of the time, at most 30 s) and at the end the
test compares per process: pid (no restart), handle count, memory (growth under 20 %), and the number of
processes of the session. All instances have to end, no request may fail, and the late snapshot latency
must stay in the budget.
"""

import os
import threading
import time

import pytest

from stresskit import stress_chain, thread_stacks  # noqa: F401  (fixture)
from faultkit import session_processes
from support import metrics

SOAK_SECONDS = float(os.environ.get("AHF_SOAK_SECONDS", "600"))
GROWTH_LIMIT = 1.20
HANDLE_SLACK_FACTOR = 1.10
P99_BUDGET_MS = 50.0
BURST_FLOW, LONG_FLOW = "burst", "long"
BURST_SIZE = int(os.environ.get("AHF_SOAK_BURST", "4"))


class Worker(threading.Thread):
    def __init__(self, name, fn, period, errors, stop):
        super().__init__(name=name, daemon=True)
        self.fn, self.period, self.errors, self.stop_flag = fn, period, errors, stop
        self.count = 0

    def run(self):
        while not self.stop_flag.is_set():
            try:
                self.fn()
                self.count += 1
            except Exception as exc:
                self.errors.append("%s: %s: %s" % (self.name, type(exc).__name__, exc))
            self.stop_flag.wait(self.period)


def ok(client, type_, payload):
    answer = client.request("engine", type_, payload, timeout=5)
    assert answer["payload"].get("ok"), answer
    return answer["payload"]


@pytest.mark.soak
@pytest.mark.timeout(int(SOAK_SECONDS) + 180)
def test_mixed_operations_for_minutes_keep_processes_handles_and_memory_flat(stress_chain):
    sc = stress_chain(flows={BURST_FLOW: (100, "parallel"), LONG_FLOW: (5000, "parallel")},
                      run_timeout=int(SOAK_SECONDS) + 120)
    clients = {n: sc.client(n) for n in ("burst", "long", "snap", "toggle")}
    probe = sc.client("probe", topics=("engine",))
    errors, stop = [], threading.Event()
    latencies = []

    def burst():
        ids = clients["burst"].send_many("engine", "cmd.flow.start", [{"flowId": BURST_FLOW}] * BURST_SIZE,
                                         timeout_ms=5000)
        for i in ids:
            assert clients["burst"].answer(i, 10)["payload"].get("ok")

    def long_flow():
        ok(clients["long"], "cmd.flow.start", {"flowId": LONG_FLOW})
        time.sleep(0.05)
        ok(clients["long"], "cmd.flow.stop", {"flowId": LONG_FLOW})

    def snapshot():
        t0 = time.perf_counter()
        ok(clients["snap"], "cmd.engine.snapshot", {})
        latencies.append((time.monotonic(), (time.perf_counter() - t0) * 1000))

    def toggle():
        ok(clients["toggle"], "cmd.flow.enable", {"flowId": BURST_FLOW})
        ok(clients["toggle"], "cmd.flow.disable", {"flowId": BURST_FLOW})

    def churn():
        c = sc.new_client("soakchurn")
        try:
            c.request("supervisor", "cmd.topic.subscribe", {"topic": "engine"}, timeout=5)
            ok(c, "cmd.engine.snapshot", {})
        finally:
            c.close()

    workers = [Worker("burst", burst, 0.25, errors, stop), Worker("long", long_flow, 3.0, errors, stop),
               Worker("snap", snapshot, 0.05, errors, stop), Worker("toggle", toggle, 2.0, errors, stop)]
    if os.environ.get("AHF_SOAK_CHURN") == "1":
        workers.append(Worker("churn", churn, 0.5, errors, stop))

    def snap_all():
        names = {p["name"]: p["pid"] for p in sc.process_list().values()}
        procs = {"supervisor": sc.sup_pid, **names}
        return {n: metrics.proc_snapshot(pid) for n, pid in procs.items()}, procs

    for w in workers:
        w.start()
    warmup = min(30.0, SOAK_SECONDS / 4)
    time.sleep(warmup)
    before, pids_before = snap_all()
    count_before = len(session_processes(sc.session))
    mark = time.monotonic()
    time.sleep(SOAK_SECONDS - warmup)
    after, pids_after = snap_all()
    count_after = len(session_processes(sc.session))
    stop.set()
    for w in workers:
        w.join(timeout=15)
    assert not [w for w in workers if w.is_alive()], thread_stacks(workers)
    time.sleep(6.0)                      # the last instances end (5 s sleep of the long flow is stopped at once)
    snapshot_final = ok(probe, "cmd.engine.snapshot", {})
    late = metrics.Dist([ms for t, ms in latencies if t >= mark])
    metrics.record("soak", seconds=SOAK_SECONDS, warmup=warmup, operations={w.name: w.count for w in workers},
                   errors=len(errors), before=before, after=after, processes_before=count_before,
                   processes_after=count_after, late_snapshot_ms=late.as_dict(), machine=metrics.machine())
    print("\nsoak %.0f s: operations %s\nlate snapshot latency %s\nbefore %s\nafter  %s\nprocesses %d -> %d"
          % (SOAK_SECONDS, {w.name: w.count for w in workers}, late, before, after, count_before, count_after))

    assert not errors, "%d errors, first: %s" % (len(errors), errors[:5])
    assert pids_after == pids_before, "a process was restarted: %s -> %s" % (pids_before, pids_after)
    assert count_after == count_before
    assert not [f for f in snapshot_final["flows"] if f["executing"]], snapshot_final["flows"]
    for name in before:
        assert after[name]["rss_mb"] <= before[name]["rss_mb"] * GROWTH_LIMIT, (name, before[name], after[name])
        assert after[name]["handles"] <= before[name]["handles"] * HANDLE_SLACK_FACTOR + 2, (name, before[name], after[name])
    assert late.p99 < P99_BUDGET_MS, str(late)
