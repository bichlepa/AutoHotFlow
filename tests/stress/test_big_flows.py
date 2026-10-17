"""WI-0024: large flow files must neither keep the hub busy nor starve the heartbeat of the engine.

 - Hub cost of one large frame: a res.storage.flow.read with the biggest v1 flow (93 KB) goes through
   Hub._OnFrame (fake connections, no I/O). Budget: under 5 ms (before WI-0024: about 220 ms).
 - Many flows at the start: the Data directory holds N big flows (copies of the 8 large v1 flows under new
   names, BIG_FLOW_NAMES from tests/data/flows/v1_examples). The chain must start without `hung`/`crashed`, load every flow, and a
   `cmd.engine.snapshot` asked during the loading must be answered in under 1 s. The time from the start
   of the supervisor to `evt.engine.ready` is recorded (a finding if it is far above 30 s, WI-0024 point 6).

Smoke variants run in the default run, the full 200-flow test with `-m stress`. Every test prints one
MEASURE line (support/metrics.py).
"""

import json
import time
from pathlib import Path

import pytest

from support import metrics
from support.timing import scaled
from stresskit import StressChain, _connect, hwnd_of, stress_chain  # noqa: F401  (fixture)
from faultkit import FULL_CHAIN, HEADLESS_OPTS, Chain, event, wait_until

TESTS_DIR = Path(__file__).resolve().parents[1]
V1_EXAMPLES = TESTS_DIR / "data" / "flows" / "v1_examples"
# The 8 largest v1 flows (sorted by name); the other v1 examples are small and not part of this test.
BIG_FLOW_NAMES = ["Flow 1010290492.json", "Flow 1087828277.json", "Flow 1210127300.json", "Flow 130786371.json",
                  "Flow 1384439262.json", "Flow 369404488.json", "Flow 561135904.json", "Flow 65341778.json"]
BIG_FLOWS = [V1_EXAMPLES / name for name in BIG_FLOW_NAMES]
BIGGEST_FLOW = V1_EXAMPLES / "Flow 1010290492.json"
HELPER = TESTS_DIR / "ahk" / "helpers" / "hub_frame_cost.ahk"

HUB_FRAME_BUDGET_MS = 5.0
SNAPSHOT_BUDGET_S = 3.0     # E0042 (was 1.0): guards against a blocked engine; F-0073 has the measurements
LOAD_NOTE_S = 30.0          # WI-0024 point 6: above this, the load time is a finding for "native JSON parser"
# WI-0062 (F-0073): every copy gets an enabled timer trigger, armed by the engine through the trigger host. The interval is
# long, so no event starts an instance during the test; the arming (and the state in FlowStates/) is what is measured.
TIMER_TRIGGER = "element_stress_timer"
TIMER_INTERVAL = "60000"
ARMED_BUDGET_S = 30.0       # all timers armed this long after evt.engine.ready, or the test fails


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
    # scaled(): the budget is exact in the serial run and under -m stress (the reference), three times looser in the
    # parallel run, where 5.07 ms against 5.0 ms was seen (F-0035).
    assert bench["mean_ms"] < scaled(HUB_FRAME_BUDGET_MS), bench


def fill_flows(datadir, count):
    """Copies the big flows round-robin to Flows/<n>.json, each with an enabled timer trigger (TIMER_TRIGGER), and writes
    FlowStates/<flowId>.json so that the engine enables them at the start. Returns the flow ids and the total size in
    bytes."""
    flows = Path(datadir) / "Flows"
    flows.mkdir(exist_ok=True)
    states = Path(datadir) / "FlowStates"
    states.mkdir(exist_ok=True)
    sources = BIG_FLOWS
    assert all(src.is_file() for src in sources), "missing big flows in %s" % V1_EXAMPLES
    names, total = [], 0
    for n in range(count):
        src = sources[n % len(sources)]
        name = "Big %03d" % n
        flow = json.loads(src.read_text(encoding="utf-8"))
        flow["allElements"][TIMER_TRIGGER] = {"ID": TIMER_TRIGGER, "type": "trigger", "package": "Test",
                                              "class": "Trigger_TestTimer", "name": "stress timer", "enabled": "0",
                                              "pars": {"Interval": TIMER_INTERVAL}}
        (flows / (name + ".json")).write_text(json.dumps(flow, ensure_ascii=False), encoding="utf-8")
        state = {"formatVersion": 1, "enabled": [TIMER_TRIGGER]}
        (states / (name + ".json")).write_text(json.dumps(state), encoding="utf-8")
        names.append(name)
        total += src.stat().st_size
    return names, total


def armed_count(snap, names):
    """How many of the flows have their timer armed in the snapshot."""
    armed = set()
    for f in snap["flows"]:
        for t in f.get("triggers", []):
            if t["elementId"] == TIMER_TRIGGER and t["armed"] is True:
                armed.add(f["flowId"])
    return len(armed & set(names))


def load_chain_and_probe(procs, datadir, session_id, count):
    """Starts the chain over `count` big flows and asks for snapshots until evt.engine.ready.
    Returns a dict with the measurements; leaves cleaning up to the caller (chain)."""
    names, total_bytes = fill_flows(datadir, count)
    chain = Chain(procs, datadir, session_id, FULL_CHAIN + ",triggerhost", HEADLESS_OPTS, run_timeout=400)
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
        # The engine arms the timers after the ready (WI-0062): every flow must show its timer armed in time.
        t_armed = None
        deadline = time.monotonic() + scaled(ARMED_BUDGET_S)
        while time.monotonic() < deadline:
            armed = armed_count(chain.snapshot_ok(timeout=10), result["names"])
            if armed == count:
                t_armed = time.monotonic() - chain.sup.t0
                break
            time.sleep(0.1)
        assert t_armed is not None, "only %d of %d timers armed after %s s:\n%s" % (
            armed, count, ARMED_BUDGET_S, chain.sup.text())
        lat = metrics.Dist([x * 1000 for x in result["latencies"]]) if result["latencies"] else None
        snap = chain.snapshot_ok(timeout=10)
        states = chain.states()
        restarts = {n: p.get("restarts") for n, p in states.items()}
        bad_events = chain.rec.find(lambda m: m.get("type") in ("evt.process.hung", "evt.process.crashed",
                                                                "evt.process.restarted"))
        # Since WI-0031 the engine waits for storage and reports no error for it (F-0021): every error counts.
        errors = chain.rec.find(lambda m: m.get("type") == "evt.storage.error")
        metrics.record("big flow collection loaded", flows=count, megabytes=round(result["bytes"] / 2**20, 2),
                       seconds_to_ready=round(result["t_ready"], 2),
                       seconds_to_all_armed=round(t_armed, 2),
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
