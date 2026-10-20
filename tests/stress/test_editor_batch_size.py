"""WI-0092 task 8 and F-0156 (doc/TEST-STRATEGY.md 3): the size of the element-state batches of a flow of 300 elements in
which every element changes within one 33 ms interval, and what the editor does with them.

The flow is a trigger and 299 actions in a row (Action_Do_nothing): one start runs all of them in a few milliseconds, so
their state changes fall into one batch interval. The test runs ROUNDS starts with a headless editor open and records
every evt.element.states of the flow (the observer subscribes to the topic flow:<id>):
 - the number of batches per start, the entries per batch and the size of each batch in bytes (the payload as JSON),
 - that every element of the flow appears in the batches of the start,
 - that the editor ends with the same states as the engine (all 300 elements finished) and the latency of its frames
   (the time from a change to the end of its frame, EditorModel.Latency, cumulative over the rounds).
The numbers are printed and recorded in doc/MEASUREMENTS.md (MS-0048); the assertions are generous, they catch a broken
batch, not a slow machine.

Run: python -m pytest tests/stress/test_editor_batch_size.py -m stress -q -n 0
"""

import json
import time

import pytest

import sys
from pathlib import Path

from stresskit import HEADLESS_OPTS, Chain, wait_until  # stresskit puts tests/fault on the path
from faultkit import AHKRUN, request_ok
from support.flowbuilder import FlowBuilder
from support.timing import scaled

FLOW = "batch300"
EDITOR = "editor:" + FLOW
ELEMENTS = 300                 # the trigger and 299 actions
ROUNDS = 5
MAX_BATCH_BYTES = 1_000_000    # a batch of 300 entries is about 60 KB; one megabyte means a broken batch
EDITOR_ENTRY = Path(__file__).resolve().parents[2] / "src" / "entry" / "editor.ahk"
MAX_P95_LATENCY_MS = 250       # generous (REQ-PRF-060 asks 50 ms with the machine quiet, see MS-0047)


def write_flow(datadir):
    fb = FlowBuilder("batch 300", flow_settings={})
    previous = fb.trigger()
    for _ in range(ELEMENTS - 1):
        nxt = fb.action("Action_Do_nothing")
        fb.connect(previous, nxt)
        previous = nxt
    fb.write(datadir, FLOW)


def batches_since(chain, t0):
    """The evt.element.states batches of the flow that arrived after t0, as (time, {"elements": [...]}).
    The client expands every batch into one evt.element.state per element (tests/support/ahfclient.py); the entries
    of one batch name the same engine event (msg["event"], the batch's seq), so they are grouped again here."""
    found = chain.rec.find(lambda m: m.get("type") == "evt.element.state"
                           and m.get("payload", {}).get("flowId") == FLOW)
    batches = {}
    for t, m in found:
        if t < t0:
            continue
        entry = {k: v for k, v in m["payload"].items() if k not in ("flowId", "seq", "epoch")}
        first, items = batches.setdefault(m["event"], (t, []))
        items.append(entry)
    return [(first, {"elements": items}) for first, items in batches.values()]


def editor_state(chain):
    """The editor's state, or {} while it does not answer yet (it is not loaded at the start)."""
    try:
        ans = chain.obs.request(EDITOR, "cmd.test.state", {}, timeout=scaled(5))
    except Exception:
        return {}
    payload = ans["payload"]
    return payload["state"] if payload.get("ok") else {}


@pytest.mark.stress
@pytest.mark.timeout(400)
def test_a_flow_of_300_elements_that_all_change_in_one_interval_sends_bounded_batches(procs, datadir, session_id):
    write_flow(datadir)
    chain = Chain(procs, datadir, session_id, "storage,engine", HEADLESS_OPTS)
    try:
        chain.wait_ready(["storage", "engine"], timeout=scaled(60))
        chain.wait_flows([FLOW], timeout=scaled(60))
        request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "flow:" + FLOW})
        # the editor is started the way the supervisor starts one (PROTOCOL 4.1), but by the test: cmd.editor.open
        # is reserved for the manager (the observer may not send it)
        procs.start([sys.executable, str(AHKRUN), "--timeout", "600", str(EDITOR_ENTRY), "--role=editor",
                     "--flow=" + FLOW, "--session=" + session_id, "--hub=" + chain.sup.pipe, "--data=" + str(datadir),
                     "--headless"], stdout=None, stderr=None)
        assert wait_until(lambda: editor_state(chain).get("rev", -1) >= 1, scaled(30)), "editor not loaded"
        # a headless editor draws only with a canvas (the window gives it one): 1920 x 1080 as the owner's screen
        assert chain.obs.request(EDITOR, "cmd.test.render", {"w": 1920, "h": 1080}, timeout=scaled(10))["payload"]["ok"]
        rounds = []
        for number in range(1, ROUNDS + 1):
            t0 = time.perf_counter()
            ans = chain.obs.request("engine", "cmd.flow.start", {"flowId": FLOW}, timeout=scaled(10))
            assert ans["payload"]["ok"], ans
            ended = wait_until(lambda: [1 for t, m in chain.rec.find(
                lambda m: m.get("type") == "evt.instance.ended" and m["payload"].get("flowId") == FLOW) if t >= t0],
                scaled(60))
            assert ended, "the flow did not end in round %d" % number
            batches = batches_since(chain, t0)
            ids = set()
            sizes = []
            for _, payload in batches:
                entries = payload["elements"]
                ids.update(e["elementId"] for e in entries)
                sizes.append((len(entries), len(json.dumps(payload).encode("utf-8"))))
            rounds.append((number, len(batches), ids, sizes))
            print("\nF-0156 round %d: batches %d, entries per batch %s, bytes per batch %s, distinct elements %d"
                  % (number, len(batches), [s[0] for s in sizes], [s[1] for s in sizes], len(ids)))
            assert len(ids) == ELEMENTS, "round %d: %d of %d elements in the batches" % (number, len(ids), ELEMENTS)
            assert max(s[1] for s in sizes) < MAX_BATCH_BYTES, sizes
        # the editor and the engine agree at the end: nothing runs
        deadline = time.monotonic() + scaled(20)
        st = editor_state(chain)
        while time.monotonic() < deadline and (st["flowState"]["executing"] is not False or st["fading"] > 0):
            time.sleep(0.2)
            st = editor_state(chain)
        assert st["elements"] == ELEMENTS, st["elements"]
        assert "running" not in st["states"].values(), st["states"]      # cmd.test.state lists the running elements only
        run = chain.obs.request("engine", "cmd.flow.runstate", {"flowId": FLOW}, timeout=scaled(10))["payload"]
        assert run["flow"]["executing"] is False and run["flow"]["instances"] == 0, run["flow"]
        latency = st["latency"]
        print("\nF-0156 editor latency (change to end of frame, %d frames): n %d, median %.1f ms, p95 %.1f ms"
              % (st["frames"], latency["n"], latency["medianUs"] / 1000, latency["p95Us"] / 1000))
        assert latency["n"] > 0 and latency["p95Us"] < MAX_P95_LATENCY_MS * 1000, latency
    finally:
        chain.close()
