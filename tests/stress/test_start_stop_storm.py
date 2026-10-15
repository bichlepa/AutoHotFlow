"""WI-0016: fast start/stop sequences of a flow (L5, doc/TEST-STRATEGY.md 3, scenario 2).

One flow with a 5 s sleep element is started and stopped again and again (every third cycle with two
instances at once). Afterwards the books must balance:
 - every started instance has an `evt.instance.ended` (reason flow.stop), none is left,
 - the engine event sequence numbers (`seq`) rise by exactly one, so no state event was lost,
 - the last state of every element is `finished` with countRuns 0, the snapshot says the flow is not executing,
 - the engine process does not keep growing: handles stay flat (every request and every instance owns a timer).

The smoke variant runs in the default test run, the full one with `-m stress`.
"""

import time

import pytest

from support import metrics
from stresskit import stress_chain  # noqa: F401  (fixture)

FLOW = "slow"
WARMUP_CYCLES = 20
HANDLE_SLACK = 5            # num_handles of the engine may differ by this much after the storm
RSS_GROWTH_LIMIT = 1.20     # engine RSS after / before


def cycles_params():
    return [pytest.param(30, id="smoke"),
            pytest.param(1000, id="full", marks=[pytest.mark.stress, pytest.mark.timeout(400)])]


def one_cycle(client, cycle, start_ms, stop_ms):
    """Start one or two instances, then stop the flow. Returns the number of instances."""
    instances = 2 if cycle % 3 == 0 else 1
    ids = []
    t0 = time.perf_counter()
    for _ in range(instances):
        answer = client.request("engine", "cmd.flow.start", {"flowId": FLOW}, timeout=5)
        assert answer["payload"].get("ok"), answer
        ids.append(answer["payload"]["instanceId"])
    start_ms.append((time.perf_counter() - t0) * 1000 / instances)
    t0 = time.perf_counter()
    answer = client.request("engine", "cmd.flow.stop", {"flowId": FLOW}, timeout=5)
    stop_ms.append((time.perf_counter() - t0) * 1000)
    assert answer["payload"].get("ok") and answer["payload"]["stopped"] == instances, answer
    return ids


def drain(client, quiet_s=1.0):
    return list(client.events(timeout=quiet_s))


@pytest.mark.parametrize("cycles", cycles_params())
def test_start_stop_storm_leaves_a_consistent_engine(stress_chain, cycles):
    sc = stress_chain(flows={FLOW: (5000, "default")})
    probe = sc.client("probe", topics=("engine", "flow:" + FLOW))
    engine_pid = sc.pids["engine"]

    start_ms, stop_ms, all_ids = [], [], []
    for cycle in range(WARMUP_CYCLES):
        all_ids += one_cycle(probe, cycle, [], [])
    drain(probe, 0.5)
    before = metrics.proc_snapshot(engine_pid)

    t0 = time.perf_counter()
    for cycle in range(cycles):
        all_ids += one_cycle(probe, cycle, start_ms, stop_ms)
    elapsed = time.perf_counter() - t0
    events = drain(probe, 1.5)
    after = metrics.proc_snapshot(engine_pid)

    # engine alive, same pid, not restarted
    states = sc.process_list()
    assert states["engine"]["pid"] == engine_pid and states["engine"]["state"] == "ready", states["engine"]
    assert states["engine"]["restarts"] == 0, states["engine"]

    # every instance has exactly one start and one end
    started = [m["payload"]["instanceId"] for m in events if m["type"] == "evt.instance.started"]
    ended = [m for m in events if m["type"] == "evt.instance.ended"]
    total_after_warmup = len(started)
    expected = sum(2 if c % 3 == 0 else 1 for c in range(cycles))
    assert total_after_warmup == expected, (total_after_warmup, expected)
    assert len(set(started)) == len(started), "duplicate instance start events"
    assert sorted(m["payload"]["instanceId"] for m in ended) == sorted(started), "instances without an end"
    assert {m["payload"]["reason"] for m in ended} == {"flow.stop"}, {m["payload"]["reason"] for m in ended}

    # flow.state: executing goes 1 -> 0 and ends at 0
    flow_states = [m["payload"]["executing"] for m in events if m["type"] == "evt.flow.state"]
    assert flow_states and flow_states[-1] == 0, flow_states[-5:]

    # seq: strictly +1, one epoch, nothing lost between the first and the last event we saw
    engine_events = [m for m in events if m.get("from") == "engine" and "seq" in m.get("payload", {})]
    seqs = [m["payload"]["seq"] for m in engine_events]
    assert seqs == list(range(seqs[0], seqs[0] + len(seqs))), "seq gap or reordering: %s" % _gaps(seqs)
    assert len({m["payload"]["epoch"] for m in engine_events}) == 1

    # element states: the last state of each element has countRuns 0 and is not running
    last = {}
    for m in events:
        if m["type"] == "evt.element.state":
            last[m["payload"]["elementId"]] = m["payload"]
    assert last, "no element state seen"
    for element_id, payload in last.items():
        assert payload["countRuns"] == 0 and payload["state"] == "finished", (element_id, payload)

    snapshot = probe.request("engine", "cmd.engine.snapshot", {}, timeout=5)["payload"]
    flow = [f for f in snapshot["flows"] if f["flowId"] == FLOW][0]
    assert not flow["executing"], flow

    start_dist, stop_dist = metrics.Dist(start_ms), metrics.Dist(stop_ms)
    metrics.record("start/stop storm", cycles=cycles, instances=total_after_warmup, seconds=round(elapsed, 2),
                   engine_events=len(engine_events), start_ms=start_dist.as_dict(), stop_ms=stop_dist.as_dict(),
                   engine_before=before, engine_after=after)
    print("\nstorm: %d cycles, %d instances in %.1f s, start %s, stop %s, engine %s -> %s"
          % (cycles, total_after_warmup, elapsed, start_dist, stop_dist, before, after))

    assert after["handles"] <= before["handles"] + HANDLE_SLACK, (before, after)
    assert after["rss_mb"] <= before["rss_mb"] * RSS_GROWTH_LIMIT + 2, (before, after)


def _gaps(seqs):
    out = []
    for a, b in zip(seqs, seqs[1:]):
        if b != a + 1:
            out.append((a, b))
        if len(out) >= 5:
            break
    return out
