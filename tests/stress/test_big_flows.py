"""WI-24: large flow files must neither keep the hub busy nor starve the heartbeat of the engine.

 - Hub cost of one large frame: a res.storage.flow.read with the biggest v1 flow (93 KB) goes through
   Hub._OnFrame (fake connections, no I/O). Budget: under 5 ms (before WI-24: about 220 ms).
 - Many flows at the start: the Data directory holds N big flows (copies of the large v1 flows under new
   names, tests/data/bigflows). The chain must start without `hung`/`crashed`, load every flow, and a
   `cmd.engine.snapshot` asked during the loading must be answered in under 1 s. The time from the start
   of the supervisor to `evt.engine.ready` is recorded (a finding if it is far above 30 s, WI-24 point 6).

Smoke variants run in the default run, the full 200-flow test with `-m stress`. Every test prints one
MEASURE line (support/metrics.py).
"""

import shutil
import time
from pathlib import Path

import pytest

from support import metrics
from support.timing import scaled
from stresskit import StressChain, _connect, hwnd_of, stress_chain  # noqa: F401  (fixture)
from faultkit import FULL_CHAIN, STUB_OPTS, Chain, event, wait_until

TESTS_DIR = Path(__file__).resolve().parents[1]
BIG_FLOWS = TESTS_DIR / "data" / "bigflows"
BIGGEST_FLOW = BIG_FLOWS / "Flow 1010290492.json"
HELPER = TESTS_DIR / "ahk" / "helpers" / "hub_frame_cost.ahk"

HUB_FRAME_BUDGET_MS = 5.0
SNAPSHOT_BUDGET_S = 1.0
LOAD_NOTE_S = 30.0          # WI-24 point 6: above this, the load time is a finding for "native JSON parser"


@pytest.mark.parametrize("runs", [pytest.param(10, id="smoke"),
                                  pytest.param(100, id="100", marks=pytest.mark.stress)])
def test_hub_cost_of_a_large_frame_is_below_the_budget(run_ahk, runs):
    res = run_ahk(HELPER, BIGGEST_FLOW, runs, timeout=110)
    assert not res.timed_out, res.stderr
    bench = [r for r in res.records if r.get("type") == "bench"]
    assert bench, "no result line (exit %s): %s" % (res.returncode, res.stderr)
    bench = bench[0]
    metrics.record("hub cost per large frame", runs=runs, frame_chars=bench["frame_chars"],
                   mean_ms=bench["mean_ms"], max_ms=bench["max_ms"], machine=metrics.machine())
    print("\nhub cost of a %d char frame: mean %.3f ms, max %.3f ms (%d runs)"
          % (bench["frame_chars"], bench["mean_ms"], bench["max_ms"], runs))
    assert bench["delivered_ok"] == 1, "the target did not receive the frame unchanged except for `from`"
    assert bench["mean_ms"] < HUB_FRAME_BUDGET_MS, bench


def fill_flows(datadir, count):
    """Copies the big flows round-robin to Flows/<n>.json. Returns the flow ids and the total size in bytes."""
    flows = Path(datadir) / "Flows"
    flows.mkdir(exist_ok=True)
    sources = sorted(BIG_FLOWS.glob("*.json"))
    assert sources, "no flows in %s" % BIG_FLOWS
    names, total = [], 0
    for n in range(count):
        src = sources[n % len(sources)]
        name = "Big %03d" % n
        shutil.copyfile(src, flows / (name + ".json"))
        names.append(name)
        total += src.stat().st_size
    return names, total


def load_chain_and_probe(procs, datadir, session_id, count):
    """Starts the chain over `count` big flows and asks for snapshots until evt.engine.ready.
    Returns a dict with the measurements; leaves cleaning up to the caller (chain)."""
    names, total_bytes = fill_flows(datadir, count)
    chain = Chain(procs, datadir, session_id, FULL_CHAIN, STUB_OPTS, run_timeout=400)
    result = {"chain": chain, "names": names, "bytes": total_bytes}
    sc = StressChain(chain)
    probe = _connect(chain.sup.pipe, "probe", sc.hub_hwnd)
    result["probe"] = probe
    latencies, timeouts = [], 0
    ready = None
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        ready = chain.rec.find(event("evt.engine.ready"))
        if ready:
            break
        t0 = time.perf_counter()
        try:
            answer = probe.request("engine", "cmd.engine.snapshot", {}, timeout=5)
        except Exception:
            timeouts += 1
            latencies.append(time.perf_counter() - t0)
            continue
        dt = time.perf_counter() - t0
        if answer["payload"].get("ok"):          # not_found before the engine has said hello is no sample
            latencies.append(dt)
        time.sleep(0.02)
    result["latencies"] = latencies
    result["timeouts"] = timeouts
    result["t_ready"] = (ready[0][0] - chain.sup.t0) if ready else None
    return result


@pytest.mark.parametrize("count", [pytest.param(20, id="smoke"),
                                   pytest.param(200, id="200", marks=[pytest.mark.stress, pytest.mark.timeout(400)])])
def test_many_big_flows_load_without_hung_and_with_a_responsive_engine(procs, datadir, session_id, count):
    result = load_chain_and_probe(procs, datadir, session_id, count)
    chain = result["chain"]
    try:
        assert result["t_ready"] is not None, "evt.engine.ready did not come:\n" + chain.sup.text()
        lat = metrics.Dist([x * 1000 for x in result["latencies"]]) if result["latencies"] else None
        snap = chain.snapshot_ok(timeout=10)
        states = chain.states()
        restarts = {n: p.get("restarts") for n, p in states.items()}
        bad_events = chain.rec.find(lambda m: m.get("type") in ("evt.process.hung", "evt.process.crashed",
                                                                "evt.process.restarted"))
        # Since WI-31 the engine waits for storage and reports no error for it (F-24): every error counts.
        errors = chain.rec.find(lambda m: m.get("type") == "evt.storage.error")
        metrics.record("big flow collection loaded", flows=count, megabytes=round(result["bytes"] / 2**20, 2),
                       seconds_to_ready=round(result["t_ready"], 2),
                       snapshot_during_load_ms=lat.as_dict() if lat else None,
                       snapshot_timeouts=result["timeouts"], flows_loaded=len(snap["flows"]),
                       storage_errors=len(errors), machine=metrics.machine())
        print("\n%d flows (%.1f MB): ready after %.2f s, %d loaded, snapshot during load: %s, timeouts %d"
              % (count, result["bytes"] / 2**20, result["t_ready"], len(snap["flows"]), lat, result["timeouts"]))
        assert not bad_events, [m["type"] + " " + str(m["payload"]) for _, m in bad_events]
        assert all(r == 0 for r in restarts.values()), restarts
        assert not errors, [m["payload"] for _, m in errors[:3]]
        loaded = {f["flowId"] for f in snap["flows"]}
        assert set(result["names"]) <= loaded, "missing: %s" % sorted(set(result["names"]) - loaded)[:5]
        assert lat is not None and result["timeouts"] == 0, "no sample or a snapshot timed out"
        assert lat.max < scaled(SNAPSHOT_BUDGET_S * 1000), str(lat)
    finally:
        result["probe"].close()
        chain.close()
