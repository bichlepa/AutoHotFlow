"""WI-0016: clients connect and disconnect again and again while a flow runs (L5, scenario 3).

A background client keeps the flow busy (a new parallel instance every 20 ms). N churn clients each loop:
connect, subscribe to the topics of the engine and the flow, ask for a snapshot, listen for a short while,
close. The probe client asks `cmd.engine.snapshot` all the time and measures the answer latency.

Expected: no error in any client, no unanswered request, the snapshot latency stays in the budget of
ARCHITECTURE 9 (median under 5 ms, p99 under 50 ms), no process restarted, and the handles of the supervisor
and of the engine are the same before and after (no leak per connection).

The smoke variant runs in the default test run, the full one with `-m stress`.
"""

import random
import threading
import time

import pytest

from support import metrics
from support.timing import scaled
from stresskit import stress_chain, thread_stacks  # noqa: F401  (fixture)

FLOW = "run"
MEDIAN_BUDGET_MS = 5.0
P99_BUDGET_MS = 50.0
HANDLE_SLACK = 3
CHURN_LIMIT_S = 90


def params():
    return [pytest.param(3, 2, id="smoke"),
            pytest.param(20, 8, id="20x8", marks=[pytest.mark.stress, pytest.mark.timeout(300)])]


def listen(client, seconds):
    """Counts the events that arrive within `seconds` (events() alone would not end while events keep coming)."""
    end = time.monotonic() + seconds
    count = 0
    while True:
        remaining = end - time.monotonic()
        if remaining <= 0 or client._next_event(remaining) is None:
            return count
        count += 1


class Churner(threading.Thread):
    def __init__(self, sc, index, rounds, errors, counters):
        super().__init__(name="churn-%d" % index, daemon=True)
        self.sc, self.index, self.rounds = sc, index, rounds
        self.errors, self.counters = errors, counters

    def run(self):
        rng = random.Random(self.index)
        for r in range(self.rounds):
            client = None
            try:
                t0 = time.perf_counter()
                client = self.sc.new_client("churn%d" % self.index)
                connect_s = time.perf_counter() - t0
                for topic in ("engine", "flow:" + FLOW):
                    answer = client.request("supervisor", "cmd.topic.subscribe", {"topic": topic}, timeout=5)
                    assert answer["payload"]["ok"], answer
                answer = client.request("engine", "cmd.engine.snapshot", {}, timeout=5)
                assert answer["payload"]["ok"] and answer["payload"]["flows"], answer
                received = listen(client, rng.uniform(0.05, 0.3))
                with self.counters["lock"]:
                    self.counters["connects"] += 1
                    self.counters["events"] += received
                    self.counters["connect_s"].append(connect_s)
            except Exception as exc:       # every failure counts, the test lists them
                self.errors.append("client %d round %d: %s: %s" % (self.index, r, type(exc).__name__, exc))
            finally:
                if client is not None:
                    client.close()         # abrupt for the hub: no unsubscribe, no bye


class Load(threading.Thread):
    """Starts a new instance of the flow every 20 ms until stopped."""

    def __init__(self, client, errors):
        super().__init__(name="load", daemon=True)
        self.client, self.errors = client, errors
        self.stop_flag = threading.Event()
        self.started = 0

    def run(self):
        while not self.stop_flag.is_set():
            try:
                answer = self.client.request("engine", "cmd.flow.start", {"flowId": FLOW}, timeout=5)
                if not answer["payload"].get("ok"):
                    self.errors.append("load start refused: %s" % answer["payload"])
                self.started += 1
            except Exception as exc:
                self.errors.append("load: %s: %s" % (type(exc).__name__, exc))
            self.stop_flag.wait(0.02)


@pytest.mark.parametrize("clients,rounds", params())
def test_clients_connecting_and_leaving_do_not_disturb_the_engine_or_leak(stress_chain, clients, rounds):
    sc = stress_chain(flows={FLOW: (300, "parallel")})
    probe = sc.client("probe")
    loader_client = sc.client("loader")
    sup_pid, engine_pid = sc.sup_pid, sc.pids["engine"]

    # warm up the connection path, then take the baseline
    sc.new_client("warm").close()
    time.sleep(1.0)
    before = {"supervisor": metrics.proc_snapshot(sup_pid), "engine": metrics.proc_snapshot(engine_pid)}
    pids_before = {n: p["pid"] for n, p in sc.process_list().items()}

    errors = []
    counters = {"lock": threading.Lock(), "connects": 0, "events": 0, "connect_s": []}
    load = Load(loader_client, errors)
    load.start()
    threads = [Churner(sc, i, rounds, errors, counters) for i in range(clients)]
    latencies = []
    t0 = time.perf_counter()
    for t in threads:
        t.start()
    give_up = time.monotonic() + CHURN_LIMIT_S
    while any(t.is_alive() for t in threads):
        if time.monotonic() > give_up:
            load.stop_flag.set()
            pytest.fail("churn clients did not finish in %d s, errors so far: %s\n%s"
                        % (CHURN_LIMIT_S, errors[:5], thread_stacks(threads)))
        t1 = time.perf_counter()
        try:
            answer = probe.request("engine", "cmd.engine.snapshot", {}, timeout=5)
            assert answer["payload"]["ok"], answer
            latencies.append((time.perf_counter() - t1) * 1000)
        except Exception as exc:
            errors.append("probe: %s: %s" % (type(exc).__name__, exc))
        time.sleep(0.005)
    elapsed = time.perf_counter() - t0
    load.stop_flag.set()
    load.join(timeout=10)
    for t in threads:
        t.join(timeout=10)
    time.sleep(2.0)       # the hub notices the closed pipes on its tick; the instances end (300 ms)

    after = {"supervisor": metrics.proc_snapshot(sup_pid), "engine": metrics.proc_snapshot(engine_pid)}
    states = sc.process_list()
    dist = metrics.Dist(latencies)
    connect = metrics.Dist([s * 1000 for s in counters["connect_s"]])
    metrics.record("clients churn", clients=clients, rounds=rounds, connects=counters["connects"],
                   seconds=round(elapsed, 2), instances_started=load.started, events_received=counters["events"],
                   snapshot_ms=dist.as_dict(), connect_ms=connect.as_dict(), before=before, after=after,
                   errors=len(errors))
    print("\nchurn: %d connects by %d clients in %.1f s, %d instances, snapshot latency %s, connect %s\n"
          "  supervisor %s -> %s, engine %s -> %s"
          % (counters["connects"], clients, elapsed, load.started, dist, connect,
             before["supervisor"], after["supervisor"], before["engine"], after["engine"]))

    assert not errors, "%d errors, first: %s" % (len(errors), errors[:5])
    assert counters["connects"] == clients * rounds
    assert {n: p["pid"] for n, p in states.items()} == pids_before, states
    assert all(p["restarts"] == 0 and p["state"] == "ready" for p in states.values()), states
    assert len(latencies) >= 20, "too few probe requests: %d" % len(latencies)
    assert dist.median < scaled(MEDIAN_BUDGET_MS), "median %.2f ms" % dist.median
    assert dist.p99 < scaled(P99_BUDGET_MS), "p99 %.2f ms" % dist.p99
    for name in ("supervisor", "engine"):
        assert after[name]["handles"] <= before[name]["handles"] + HANDLE_SLACK, (name, before[name], after[name])


LEAK_WARMUP = 100
LEAK_CONNECTS = 400
LEAK_GROWTH_LIMIT = 1.20      # supervisor RSS after / before (WI-0016 soak rule: growth under 20 %)


@pytest.mark.stress
@pytest.mark.timeout(200)
def test_many_connects_keep_the_memory_of_the_supervisor_flat(stress_chain):
    """num_handles alone does not show a leak of AHK objects: memory has to stay flat as well (finding F-0007)."""
    sc = stress_chain(flows={})
    sc.client("probe")

    def connect_and_leave(count):
        for i in range(count):
            c = sc.new_client("c%d" % (i % 20))
            answer = c.request("engine", "cmd.engine.snapshot", {}, timeout=5)
            assert answer["payload"]["ok"], answer
            c.close()
        time.sleep(1.5)       # the hub notices the closed pipes on its tick

    connect_and_leave(LEAK_WARMUP)
    before = metrics.proc_snapshot(sc.sup_pid)
    connect_and_leave(LEAK_CONNECTS)
    after = metrics.proc_snapshot(sc.sup_pid)
    per_connection_kb = (after["rss_mb"] - before["rss_mb"]) * 1024 / LEAK_CONNECTS
    metrics.record("supervisor memory after many connects", connects=LEAK_CONNECTS, before=before, after=after,
                   kb_per_connection=round(per_connection_kb, 1))
    print("\nsupervisor after %d connects: %s -> %s (%.1f KB per connection)"
          % (LEAK_CONNECTS, before, after, per_connection_kb))
    assert after["handles"] <= before["handles"] + HANDLE_SLACK, (before, after)
    assert after["rss_mb"] <= before["rss_mb"] * LEAK_GROWTH_LIMIT, (before, after)
