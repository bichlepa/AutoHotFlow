"""WI-16: an event flood and the log queue of the storage (finding F-08, measured, not a budget test).

The manager stub writes every engine event to the log through the storage (PROTOKOLL 4.8). The storage writes
the queue one operation per timer slice, so it drains only about 30 lines per second, and the queue has no
limit. This test floods the engine with events for 20 s and records how far the storage falls behind (memory
of the storage, time until the log files stop changing). The only assertions are the ones that matter for
the architecture: the engine stays responsive in the budget while the storage is behind, no process is
restarted, and the storage still lives and answers afterwards.
"""

import time
from pathlib import Path

import pytest

from support import metrics
from stresskit import stress_chain  # noqa: F401  (fixture)

FLOW = "flood"
FLOOD_SECONDS = 20.0
DRAIN_LIMIT_S = 240.0
MEDIAN_BUDGET_MS = 5.0
P99_BUDGET_MS = 50.0


def newest_log_change(logdir):
    files = list(Path(logdir).glob("*")) if Path(logdir).exists() else []
    return max((f.stat().st_mtime for f in files), default=0.0)


@pytest.mark.stress
@pytest.mark.timeout(500)
def test_event_flood_keeps_the_engine_responsive_and_the_backlog_of_the_log_is_measured(stress_chain, datadir):
    sc = stress_chain(flows={FLOW: (100, "parallel")})
    loader = sc.client("loader")
    probe = sc.client("probe")
    storage_pid = sc.pids["storage"]
    before = metrics.proc_snapshot(storage_pid)
    latencies, started = [], 0
    end = time.monotonic() + FLOOD_SECONDS
    while time.monotonic() < end:
        ids = loader.send_many("engine", "cmd.flow.start", [{"flowId": FLOW}] * 5, timeout_ms=5000)
        started += len(ids)
        for i in ids:
            assert loader.answer(i, 10)["payload"].get("ok")
        for _ in range(3):
            t0 = time.perf_counter()
            assert probe.request("engine", "cmd.engine.snapshot", {}, timeout=5)["payload"]["ok"]
            latencies.append((time.perf_counter() - t0) * 1000)
        time.sleep(0.1)
    flood_end = time.monotonic()
    at_end = metrics.proc_snapshot(storage_pid)

    logdir = Path(datadir) / "Log"
    drained_after = None
    while time.monotonic() - flood_end < DRAIN_LIMIT_S:
        if time.time() - newest_log_change(logdir) > 3.0:
            drained_after = time.monotonic() - flood_end - 3.0
            break
        time.sleep(1.0)
    after = metrics.proc_snapshot(storage_pid)
    dist = metrics.Dist(latencies)
    states = sc.process_list()
    metrics.record("event flood and log backlog", flood_seconds=FLOOD_SECONDS, instances=started,
                   events_per_second=round(started * 8 / FLOOD_SECONDS), engine_snapshot_ms=dist.as_dict(),
                   storage_before=before, storage_at_end_of_flood=at_end, storage_after_drain=after,
                   log_drained_seconds_after_flood=None if drained_after is None else round(drained_after, 1),
                   machine=metrics.machine())
    print("\nflood: %d instances (about %d events/s) in %.0f s, engine snapshot latency %s\n"
          "storage %s -> %s (end of flood) -> %s; log stopped changing %s s after the flood"
          % (started, started * 8 / FLOOD_SECONDS, FLOOD_SECONDS, dist, before, at_end, after,
             "never within the limit" if drained_after is None else "%.0f" % drained_after))

    assert all(p["restarts"] == 0 and p["state"] == "ready" for p in states.values()), states
    assert dist.median < MEDIAN_BUDGET_MS and dist.p99 < P99_BUDGET_MS, str(dist)
