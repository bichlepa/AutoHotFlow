"""WI-28 step b: cmd.diag.snapshot of every role (doc/PROTOCOL.md 4.9, ARCHITECTURE 6.2).

Real supervisor with its real children (faultkit.Chain). Each role answers with the general part (Role.Snapshot)
and its own part (DiagInfo); the supervisor answers for itself. The schema is checked by
tests/support/snapshotschema.py. Nothing here depends on a fixed time: every wait is for an event.
"""

import json
import time

import psutil
import pytest

from faultkit import STUB_OPTS, event, request_ok, wait_until, write_flow

from faultfixtures import chains  # noqa: F401  (fixture)
from support import snapshotschema

pytestmark = pytest.mark.fault

SECRET = "SECRET-CONTENT-9137"
READY_S = 20.0


def snapshot_of(chain, name, timeout=5.0):
    payload = request_ok(chain.obs, name, "cmd.diag.snapshot", {}, timeout=timeout)
    return payload["snapshot"]


def full_chain(chains, datadir, flows=(), extra=()):
    for name, cls, pars in flows:
        write_flow(datadir, name, cls, pars)
    chain = chains("storage,engine,manager", [*STUB_OPTS, *extra])
    chain.wait_ready(["storage", "engine", "manager", "worker:1"], timeout=READY_S)
    chain.wait_flows(timeout=READY_S)
    return chain


@pytest.mark.slow
def test_every_role_answers_with_the_general_part_and_its_own_part(chains, datadir):
    chain = full_chain(chains, datadir)
    for name, role in (("storage", "storage"), ("engine", "engine"), ("manager", "manager"),
                       ("worker:1", "worker"), ("supervisor", "supervisor")):
        snap = snapshot_of(chain, name)
        snapshotschema.check_snapshot(snap, role)
        assert snap["name"] == name
    engine = snapshot_of(chain, "engine")
    assert any(f["flowId"] == "skeleton" for f in engine["info"]["flows"]), engine["info"]["flows"]
    assert engine["info"]["workers"]["size"] == 4 and engine["info"]["workers"]["warm"] == 1
    assert [s["name"] for s in engine["info"]["workers"]["slots"]] == ["worker:1"]
    assert engine["peer"]["status"] == "ready"


def test_the_snapshot_counters_move_with_time(chains, datadir):
    chain = full_chain(chains, datadir)
    first = snapshot_of(chain, "storage")
    # the second call needs a moment of storage uptime and the answer to the first one on its log
    assert wait_until(lambda: snapshot_of(chain, "storage")["uptimeMs"] > first["uptimeMs"], 5.0)
    second = snapshot_of(chain, "storage")
    assert second["pid"] == first["pid"] == chain.pid("storage")
    assert second["startedAt"] == first["startedAt"]


def test_the_engine_part_shows_a_running_instance_with_its_thread(chains, datadir):
    chain = full_chain(chains, datadir, flows=[("slow", "Action_Sleep", {"Duration": "5000", "Unit": "Milliseconds"})])
    answer = request_ok(chain.obs, "engine", "cmd.flow.start", {"flowId": "slow"})
    inst = answer["instanceId"]

    def thread_in_sleep():
        info = snapshot_of(chain, "engine")["info"]
        return [i for i in info["instances"] if i["instanceId"] == inst and
                any(t["elementId"] == "element0000000002" and t["state"] == "running" for t in i["threads"])]

    assert wait_until(thread_in_sleep, 10.0), snapshot_of(chain, "engine")["info"]["instances"]
    info = snapshot_of(chain, "engine")["info"]
    flow = [f for f in info["flows"] if f["flowId"] == "slow"][0]
    assert flow["executing"] is True and flow["enabled"] is False
    request_ok(chain.obs, "engine", "cmd.flow.stop", {"flowId": "slow"})


def test_a_snapshot_holds_names_and_states_but_no_contents(chains, datadir):
    """Names, ids and states are fine. The value of an element parameter must not be in any snapshot."""
    chain = full_chain(chains, datadir, flows=[
        ("secretflow", "Action_Sleep", {"Duration": "5000", "Unit": "Milliseconds", "Comment": SECRET})])
    request_ok(chain.obs, "engine", "cmd.flow.start", {"flowId": "secretflow"})
    for name in ("storage", "engine", "manager", "worker:1", "supervisor"):
        text = snapshotschema.dump(snapshot_of(chain, name))
        assert SECRET not in text, name
    # the content option is reserved: even when asked, nothing is added (and the call does not fail)
    text = snapshotschema.dump(request_ok(chain.obs, "engine", "cmd.diag.snapshot", {"content": True})["snapshot"])
    assert SECRET not in text
    request_ok(chain.obs, "engine", "cmd.flow.stop", {"flowId": "secretflow"})


def test_the_supervisor_part_has_the_process_table_hub_links_and_process_events(chains, datadir):
    chain = full_chain(chains, datadir)
    snap = snapshot_of(chain, "supervisor")
    snapshotschema.check_snapshot(snap, "supervisor")
    children = {c["name"]: c for c in snap["children"]}
    assert {"storage", "engine", "manager", "worker:1"} <= set(children), list(children)
    assert children["engine"]["state"] == "ready" and children["engine"]["pid"] == chain.pid("engine")
    links = {l["name"] for l in snap["hub"]["links"]}
    assert {"storage", "engine", "manager", "obs"} <= links, links
    types = [e["type"] for e in snap["processEvents"]]
    assert "evt.process.started" in types and "evt.process.ready" in types, types


def test_the_supervisor_snapshot_keeps_the_output_of_a_dead_child(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    request_ok(chain.obs, "echo:a", "cmd.test.stderr", {"text": "last words " + SECRET})
    psutil.Process(chain.pid("echo:a")).kill()
    assert chain.rec.wait(event("evt.process.crashed", name="echo:a"), timeout=10) is not None
    snap = snapshot_of(chain, "supervisor")
    echo = [c for c in snap["children"] if c["name"] == "echo:a"][0]
    assert echo["state"] == "crashed" and isinstance(echo["exitCode"], int)
    assert any(SECRET in line for line in echo["output"]), echo["output"]


def test_unhandled_errors_are_in_the_snapshot_with_their_stack(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    request_ok(chain.obs, "echo:a", "cmd.test.throwlater", {"count": 2})
    assert wait_until(lambda: snapshot_of(chain, "echo:a")["errors"]["count"] >= 2, 10.0)
    snap = snapshot_of(chain, "echo:a")
    snapshotschema.check_snapshot(snap, "echo")
    err = snap["errors"]["recent"][-1]
    assert err["errorType"] == "ValueError" and "deliberate error" in err["message"]
    assert err["stack"] != "" and err["line"] > 0
    # the log ring holds the role's own a0 line about it
    assert any("unexpected ValueError" in e["text"] for e in snap["log"]["recent"]), snap["log"]["recent"][-5:]
    # the supervisor has the same errors in its ring
    sup = snapshot_of(chain, "supervisor")
    assert len(sup["diagErrors"]) >= 2 and sup["diagErrors"][-1]["name"] == "echo:a"


def test_the_log_of_the_snapshot_is_cut_to_100_entries(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    request_ok(chain.obs, "echo:a", "cmd.test.log", {"count": 300, "level": "a3", "text": "x" * 800})
    snap = snapshot_of(chain, "echo:a")
    recent = snap["log"]["recent"]
    assert len(recent) == 100
    assert max(len(e["text"]) for e in recent) <= 503      # 500 characters and the cut mark
    assert recent[-1]["level"] == "a3"
