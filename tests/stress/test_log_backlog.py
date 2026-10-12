"""WI-16, WI-25: an event flood and the log queue of the storage (finding F-08).

The manager stub writes every engine event to the log through the storage (PROTOCOL 4.8). Before WI-25 the
storage drained only about 30 lines per second and the queue had no limit. This test floods the engine with
events for 20 s and records how far the storage falls behind (memory of the storage, time until the log files
stop changing). Assertions: the engine stays responsive in the budget, no process is restarted, and (WI-25) the
log is complete shortly after the flood and the memory of the storage returns close to its start value.

The second test sends log lines straight to the storage at 1500 lines per second for 10 s (WI-25: at least
1000 lines/s over 10 s), the third floods more than the limit of the log queue allows.
"""

import time
from pathlib import Path

import pytest

from support import metrics
from stresskit import stress_chain  # noqa: F401  (fixture)

FLOW = "flood"
FLOOD_SECONDS = 20.0
DRAIN_LIMIT_S = 240.0
DRAIN_BUDGET_S = 60.0   # generous: the drain takes seconds since WI-25, 240 s were not enough before
RSS_BACK_MB = 40.0      # growth over the start value that is still "back" (the queue holds at most 20000 entries)
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
    assert drained_after is not None and drained_after < DRAIN_BUDGET_S, drained_after
    assert after["rss_mb"] < before["rss_mb"] + RSS_BACK_MB, (before, after)


def _utc():
    return time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())


def _wait_text(path, needle, timeout):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            if needle in Path(path).read_bytes().decode("utf-8", "replace"):
                return True
        except OSError:
            pass
        time.sleep(0.1)
    return False


@pytest.mark.stress
@pytest.mark.timeout(300)
def test_storage_writes_1500_log_lines_per_second_for_10_seconds(stress_chain, datadir):
    """WI-25: the sender paces itself (150 lines every 100 ms). The end marker is the last line of its source
    and shows up in both files when the storage has caught up. The rate is not measured per second but
    as 'all written within 5 s after the last line was sent' (a backlog of seconds would fail it)."""
    sc = stress_chain(flows={FLOW: (100, "parallel")})
    sender = sc.client("logsender")
    storage_pid = sc.pids["storage"]
    before = metrics.proc_snapshot(storage_pid)
    count, t0 = 0, time.monotonic()
    while time.monotonic() - t0 < 10.0:
        tick = time.monotonic()
        for _ in range(150):
            sender.send("storage", "evt.log.append", {"ts": _utc(), "level": "a1", "source": "rate",
                                                     "text": "rate line %06d" % count})
            count += 1
        time.sleep(max(0.0, 0.1 - (time.monotonic() - tick)))
    sent_s = time.monotonic() - t0
    sender.send("storage", "evt.log.append", {"ts": _utc(), "level": "a1", "source": "rate", "text": "END MARKER"})
    sent_at = time.monotonic()
    logdir = Path(datadir) / "Log"
    assert _wait_text(logdir / "Log_rate.txt", "END MARKER", 30) and _wait_text(logdir / "Log.txt", "END MARKER", 5)
    lag = time.monotonic() - sent_at
    time.sleep(1.0)
    after = metrics.proc_snapshot(storage_pid)
    metrics.record("log rate", lines=count, sent_seconds=round(sent_s, 1), lag_after_last_line_s=round(lag, 2),
                   storage_before=before, storage_after=after, machine=metrics.machine())
    print("\n%d lines in %.1f s (%.0f/s), end marker written %.2f s after the last line; storage %s -> %s"
          % (count, sent_s, count / sent_s, lag, before, after))
    assert count / sent_s > 1000
    assert lag < 5.0, lag
    assert after["rss_mb"] < before["rss_mb"] + RSS_BACK_MB, (before, after)
