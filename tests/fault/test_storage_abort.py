"""WI-0015: the storage process is killed in the middle of a write (atomic write, WI-0012).

Under the real supervisor: a 5 MB flow write is sent, storage is killed after a short delay (0 to 500 ms, so
different phases of the write are hit). The target file must be the old or the new content, complete and valid
JSON, never a half one. The supervisor restarts storage, and a new write then succeeds.

A temp file (<name>.ahf-<pid>.tmp) of the killed process may stay behind; that is allowed, the target is what counts.
"""

import json
import time

import psutil
import pytest

from faultkit import FULL_CHAIN, HEADLESS_OPTS, repeat_ids, request_ok

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

BIG_BYTES = 5 * 1024 * 1024
DELAYS_S = (0.1, 0.25, 0.5)        # three kills: storage is restarted at most 3 times per minute (Children policy)


def flow_text(label, pad=""):
    obj = {"name": label, "category": "", "ElementIDCounter": "1", "flowSettings": {"zoomFactor": "0.700000"},
           "allElements": {}, "allConnections": {}}
    if pad:
        obj["pad"] = pad
    return json.dumps(obj, ensure_ascii=False, indent=2)


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_killed_storage_mid_write_leaves_the_old_or_the_new_file_never_a_half_one(chains, datadir, round_no):
    chain = chains(FULL_CHAIN, HEADLESS_OPTS)
    chain.wait_ready(["storage", "engine", "manager"])
    target = datadir / "Flows" / "atomic.json"
    old = flow_text("old")
    target.write_text(old, encoding="utf-8")
    outcomes = []
    for n, delay in enumerate(DELAYS_S):
        pid = chain.pid("storage")
        new = flow_text("new %d" % n, pad="y" * BIG_BYTES)
        chain.obs.send("storage", "cmd.storage.flow.write", {"path": "Flows/atomic.json", "text": new, "backup": True},
                       timeout_ms=30000)
        time.sleep(delay)
        psutil.Process(pid).kill()
        new_pid, t_ready = chain.wait_restarted_ready("storage", pid, timeout=15.0)
        parsed = json.loads(target.read_bytes().decode("utf-8"))          # must be complete JSON
        which = "old" if parsed["name"] == "old" else ("new" if parsed["name"] == "new %d" % n else "?")
        outcomes.append(which)
        assert which in ("old", "new"), "unexpected content in round %d: %s" % (n, parsed.get("name"))
        if which == "new":
            assert len(parsed["pad"]) == BIG_BYTES, "half-written new file"
        # the restarted storage serves again, and the next write goes through
        answer = request_ok(chain.obs, "storage", "cmd.storage.flow.write",
                            {"path": "Flows/atomic.json", "text": old, "backup": False}, timeout=30.0)
        assert answer["ok"]
        assert json.loads(target.read_bytes().decode("utf-8"))["name"] == "old"
    print("\nMEASURE storage killed mid-write, file after kill (delays %s): %s" % (DELAYS_S, outcomes))
    assert "flows" in chain.snapshot_ok()
