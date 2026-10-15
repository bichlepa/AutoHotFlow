"""WI-0016: many parallel instances of one flow (L5, doc/TEST-STRATEGY.md 3, scenario 1).

The flow has ExecutionPolicy `parallel` and a sleep element, so all instances are alive at the same time.
The requests are sent back to back without waiting for the answers. Expected:
 - every start is answered `ok` with its own instance id (error rate 0),
 - every instance ends with reason `finished` within the sleep time plus a limit, none stays `running`,
 - 6 element events per instance (3 elements, running and finished), the last state of each element is
   `finished` with countRuns 0, the seq numbers rise by one, the snapshot says the flow is not executing.

The smoke variant runs in the default test run, the full one with `-m stress`.
"""

import time

import pytest

from support import metrics
from stresskit import stress_chain  # noqa: F401  (fixture)

FLOW = "par"
END_LIMIT_S = 20.0          # after the last end is due


def params():
    return [pytest.param(10, 1000, id="smoke"),
            pytest.param(50, 3000, id="50", marks=[pytest.mark.stress, pytest.mark.timeout(200)]),
            pytest.param(200, 6000, id="200", marks=[pytest.mark.stress, pytest.mark.timeout(200)])]


@pytest.mark.parametrize("count,sleep_ms", params())
def test_parallel_instances_all_end_and_the_counters_return_to_zero(stress_chain, count, sleep_ms):
    sc = stress_chain(flows={FLOW: (sleep_ms, "parallel")})
    probe = sc.client("probe", topics=("engine", "flow:" + FLOW))
    t0 = time.perf_counter()
    ids = probe.send_many("engine", "cmd.flow.start", [{"flowId": FLOW}] * count, timeout_ms=10000)
    answers = [probe.answer(i, timeout=15) for i in ids]
    burst_s = time.perf_counter() - t0
    failed = [a for a in answers if not a["payload"].get("ok")]
    assert not failed, "%d of %d starts failed, first: %s" % (len(failed), count, failed[0])
    instance_ids = [a["payload"]["instanceId"] for a in answers]
    assert len(set(instance_ids)) == count, "instance ids are not unique"

    # collect events until every instance has ended (or the limit is over)
    events = []
    ended = 0
    deadline = time.monotonic() + sleep_ms / 1000 + END_LIMIT_S
    while ended < count and time.monotonic() < deadline:
        for msg in probe.events(timeout=0.5):
            events.append(msg)
            if msg["type"] == "evt.instance.ended":
                ended += 1
            if ended >= count:
                break
    all_ended_s = time.perf_counter() - t0
    events += list(probe.events(timeout=1.0))      # a late straggler would show up here
    ended_msgs = [m for m in events if m["type"] == "evt.instance.ended"]
    started_msgs = [m for m in events if m["type"] == "evt.instance.started"]

    assert len(started_msgs) == count, (len(started_msgs), count)
    assert len(ended_msgs) == count, "only %d of %d instances ended" % (len(ended_msgs), count)
    assert sorted(m["payload"]["instanceId"] for m in ended_msgs) == sorted(instance_ids)
    reasons = {m["payload"]["reason"] for m in ended_msgs}
    failed_elements = [(m["payload"]["elementId"], m["payload"].get("message")) for m in events
                       if m["type"] == "evt.element.state" and m["payload"]["state"] == "exception"]
    assert reasons == {"finished"}, "%s; %d instances not finished, element exceptions: %s" % (
        reasons, sum(1 for m in ended_msgs if m["payload"]["reason"] != "finished"), failed_elements[:5])

    # how many were alive at the same time (order of the events as the engine produced them)
    alive = peak = 0
    for m in events:
        if m["type"] == "evt.instance.started":
            alive += 1
            peak = max(peak, alive)
        elif m["type"] == "evt.instance.ended":
            alive -= 1
    assert alive == 0
    assert peak >= count * 0.8, "peak concurrency %d of %d: the starts did not overlap" % (peak, count)

    element_events = [m for m in events if m["type"] == "evt.element.state"]
    assert len(element_events) == 6 * count, (len(element_events), 6 * count)
    assert not [m for m in element_events if m["payload"]["state"] == "exception"]
    last = {}
    for m in element_events:
        last[m["payload"]["elementId"]] = m["payload"]
    assert len(last) == 3
    for element_id, payload in last.items():
        assert payload["countRuns"] == 0 and payload["state"] == "finished", (element_id, payload)

    flow_states = [m["payload"]["executing"] for m in events if m["type"] == "evt.flow.state"]
    assert flow_states[-1] == 0, flow_states[-5:]
    engine_events = [m for m in events if m.get("from") == "engine" and "seq" in m.get("payload", {})]
    seqs = [m["payload"]["seq"] for m in engine_events]
    assert seqs == list(range(seqs[0], seqs[0] + len(seqs))), "seq gap or reordering: %s" % _gaps(engine_events)

    snapshot = probe.request("engine", "cmd.engine.snapshot", {}, timeout=5)["payload"]
    assert not [f for f in snapshot["flows"] if f["flowId"] == FLOW][0]["executing"]
    states = sc.process_list()
    assert states["engine"]["pid"] == sc.pids["engine"] and states["engine"]["restarts"] == 0

    metrics.record("parallel instances", instances=count, sleep_ms=sleep_ms, peak=peak,
                   burst_seconds=round(burst_s, 2), all_ended_seconds=round(all_ended_s, 2),
                   events=len(events), engine=metrics.proc_snapshot(sc.pids["engine"]))
    print("\nparallel: %d instances, peak %d, starts answered in %.2f s, all ended after %.2f s (sleep %.1f s), %d events"
          % (count, peak, burst_s, all_ended_s, sleep_ms / 1000, len(events)))


def _gaps(engine_events):
    """The first places where seq does not rise by one, with the message types around them."""
    out = []
    for i in range(1, len(engine_events)):
        a, b = engine_events[i - 1], engine_events[i]
        if b["payload"]["seq"] != a["payload"]["seq"] + 1:
            out.append((i, a["payload"]["seq"], a["type"], b["payload"]["seq"], b["type"]))
        if len(out) >= 5:
            break
    return out
