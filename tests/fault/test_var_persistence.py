"""WI-0041: global and static variables survive a restart of the engine and of the session.

Under the real supervisor (storage, engine, UI stub). A flow with the test element Action_TestSetVar changes or reads
variables; the test looks at the files below Variables/ and, through the probe step of the element, at what the engine
loaded from them. Covered: the round trip of v1 variable files (tests/data/variables), the delayed write, the write
at shutdown, the loss of what was not written when the engine is killed, and a frozen storage.
"""

import json
import shutil
import time
import uuid
from pathlib import Path

import psutil
import pytest

from faultkit import FULL_CHAIN, STUB_OPTS, request_ok, wait_until, write_flow
from faultfixtures import chains  # noqa: F401  (fixture)
from faultkit import event
from support.timing import scaled

pytestmark = pytest.mark.fault

ROOT = Path(__file__).resolve().parents[2]
DATA_VARS = ROOT / "tests" / "data" / "variables"
STATIC_FLOW = "Flow 1000000001"       # the folder name of the static variables in tests/data/variables
READY_S = 20.0
FILE_S = scaled(8.0)                   # a write after the delay of 200 ms
OPTS = [*STUB_OPTS]


# --- helpers ----------------------------------------------------------------------------------------------

def steps(*items):
    return json.dumps(list(items))


def probe(*names):
    return [{"op": "probe", "name": n} for n in names]


def var_stem(datadir, scope_dir, name):
    return Path(datadir) / "Variables" / scope_dir / name if scope_dir else Path(datadir) / "Variables" / name


def read_text(path):
    text = Path(path).read_bytes().decode("utf-8")
    return text[1:] if text.startswith("﻿") else text


def read_pair(datadir, name, scope_dir=""):
    """(type, content) of a variable on disk, or None if the files are missing or not complete yet."""
    stem = var_stem(datadir, scope_dir, name)
    try:
        meta = json.loads(read_text(str(stem) + ".ahfvd"))
        return meta["type"], read_text(str(stem) + ".ahfvar")
    except (OSError, ValueError, KeyError):
        return None


def wait_pair(datadir, name, predicate, scope_dir="", timeout=FILE_S):
    ok = wait_until(lambda: (read_pair(datadir, name, scope_dir) is not None
                             and predicate(read_pair(datadir, name, scope_dir))), timeout)
    return read_pair(datadir, name, scope_dir) if ok else None


def new_session():
    return "u" + uuid.uuid4().hex[:12]


def ready_count(chain):
    return len(chain.rec.find(event("evt.engine.ready")))


def wait_ready_count(chain, n, timeout=READY_S):
    assert wait_until(lambda: ready_count(chain) >= n, timeout), "evt.engine.ready #%d missing:\n%s" % (n, chain.sup.text())


def run_flow(chain, flow, timeout=10.0):
    request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "flow:" + flow})
    started = request_ok(chain.obs, "engine", "cmd.flow.start", {"flowId": flow})
    ended = chain.rec.wait(event("evt.instance.ended", instanceId=started["instanceId"]), scaled(timeout))
    assert ended is not None, "instance of '%s' did not end:\n%s" % (flow, chain.sup.text())
    assert ended[1]["payload"]["reason"] == "finished", ended[1]
    return ended


def probed(datadir, name):
    """(text, type) that the probe step left for the variable name, read from the files of the probe variables."""
    text = wait_pair(datadir, "global_probe_" + name, lambda p: True)
    kind = wait_pair(datadir, "global_probetype_" + name, lambda p: True)
    assert text is not None and kind is not None, "probe of %s not written" % name
    return text[1], kind[1]


def fresh_probe(datadir, names):
    """Removes the files of earlier probes, so that the next probe cannot be mistaken for an old one."""
    for name in names:
        for prefix in ("global_probe_", "global_probetype_"):
            for ext in (".ahfvd", ".ahfvar"):
                p = Path(str(var_stem(datadir, "", prefix + name)) + ext)
                if p.exists():
                    p.unlink()


# --- the round trip of v1 files -----------------------------------------------------------------------------

def test_v1_variable_files_are_loaded_changed_written_and_loaded_again(chains, datadir):
    shutil.copytree(DATA_VARS, datadir / "Variables")
    names = ["global_synthetic_list", "global_synthetic_text", "static_synthetic_map", "static_synthetic_text"]
    write_flow(datadir, STATIC_FLOW, "Action_TestSetVar", {"Steps": steps(
        *probe(*names),
        {"op": "set", "name": "static_synthetic_map",
         "value": {"text": "1", "number": 3, "nested": {"key": "v2"}, "extra": [1, 2.5, "x"]}},
        {"op": "set", "name": "global_synthetic_text", "value": "42"},
        {"op": "set", "name": "global_float", "value": 2.5},
        {"op": "set", "name": "global_new", "value": "x"},
        {"op": "delete", "name": "global_synthetic_list"})})
    first = chains(FULL_CHAIN, OPTS)
    wait_ready_count(first, 1)
    run_flow(first, STATIC_FLOW)

    # What the engine loaded: the contents of the v1 files, texts stay texts (M-0039).
    got = {n: probed(datadir, n) for n in names}
    assert json.loads(got["global_synthetic_list"][0]) == ["alpha", "beta", "gamma"]
    assert got["global_synthetic_list"][1] == "Map"
    assert json.loads(got["static_synthetic_map"][0]) == {"text": "1", "number": 2, "nested": {"key": "value"}}
    assert got["global_synthetic_text"] == ("0.500000", "String")
    assert got["static_synthetic_text"] == ("007 with umlaut ä", "String")

    # What the engine wrote after the change: file pairs in the v1 format that read back with the same values.
    pair = wait_pair(datadir, "static_synthetic_map", lambda p: "v2" in p[1], scope_dir=STATIC_FLOW)
    assert pair is not None and pair[0] == "object"
    assert json.loads(pair[1]) == {"text": "1", "number": 3, "nested": {"key": "v2"}, "extra": [1, 2.5, "x"]}
    assert wait_pair(datadir, "global_synthetic_text", lambda p: p[1] == "42") == ("normal", "42")
    assert wait_pair(datadir, "global_float", lambda p: True) == ("normal", "2.5")
    assert wait_pair(datadir, "global_new", lambda p: True) == ("normal", "x")
    assert wait_until(lambda: not (datadir / "Variables" / "global_synthetic_list.ahfvd").exists(), FILE_S)
    assert not (datadir / "Variables" / "global_synthetic_list.ahfvar").exists()
    assert read_pair(datadir, "static_synthetic_text", STATIC_FLOW) == ("normal", "007 with umlaut ä")  # untouched

    # A new session on the same data folder: the changed values come back.
    request_exit = first.request_exit()
    assert request_exit["payload"]["started"] is True
    assert first.sup.wait_exit(30) == 0, first.sup.text()
    fresh_probe(datadir, names + ["global_float", "global_new"])
    write_flow(datadir, STATIC_FLOW, "Action_TestSetVar", {"Steps": steps(
        *probe(*names, "global_float", "global_new"))})
    second = chains(FULL_CHAIN, OPTS, session=new_session())
    wait_ready_count(second, 1)
    run_flow(second, STATIC_FLOW)
    got = {n: probed(datadir, n) for n in names + ["global_float", "global_new"]}
    assert got["global_synthetic_list"] == ("<missing>", "<missing>")
    assert json.loads(got["static_synthetic_map"][0]) == {"text": "1", "number": 3, "nested": {"key": "v2"},
                                                          "extra": [1, 2.5, "x"]}
    assert got["global_synthetic_text"] == ("42", "String")
    assert got["global_float"] == ("2.5", "String")           # a number is stored as its text, as in v1
    assert got["global_new"] == ("x", "String")
    assert got["static_synthetic_text"] == ("007 with umlaut ä", "String")


# --- delayed writing, shutdown, crash ---------------------------------------------------------------------------

def test_a_change_is_written_after_the_delay_and_survives_a_killed_engine(chains, datadir):
    write_flow(datadir, "setter", "Action_TestSetVar", {"Steps": steps(
        {"op": "set", "name": "global_kept", "value": "before the kill"},
        {"op": "set", "name": "static_kept", "value": {"a": [1, 2]}})})
    write_flow(datadir, "reader", "Action_TestSetVar", {"Steps": steps(*probe("global_kept"))})
    chain = chains(FULL_CHAIN, OPTS)
    wait_ready_count(chain, 1)
    run_flow(chain, "setter")
    t0 = time.perf_counter()
    assert wait_pair(datadir, "global_kept", lambda p: True) == ("normal", "before the kill")
    print("\nMEASURE variable written %.3f s after the end of the instance" % (time.perf_counter() - t0))
    assert wait_pair(datadir, "static_kept", lambda p: True, scope_dir="setter")[0] == "object"

    pid = chain.pid("engine")
    psutil.Process(pid).kill()
    chain.wait_restarted_ready("engine", pid, timeout=15.0)
    wait_ready_count(chain, 2)
    run_flow(chain, "reader")
    assert probed(datadir, "global_kept") == ("before the kill", "String")


def test_a_change_younger_than_the_delay_is_written_at_shutdown_and_lost_with_a_kill(chains, datadir):
    slow = [*OPTS, "--var-write-delay-ms=30000"]
    write_flow(datadir, "setter", "Action_TestSetVar", {"Steps": steps(
        {"op": "set", "name": "global_late", "value": "written at exit"})})
    chain = chains(FULL_CHAIN, slow)
    wait_ready_count(chain, 1)
    run_flow(chain, "setter")
    time.sleep(scaled(1.0))
    assert read_pair(datadir, "global_late") is None, "written before the delay was over"
    assert chain.request_exit()["payload"]["started"] is True
    assert chain.sup.wait_exit(30) == 0, chain.sup.text()
    assert read_pair(datadir, "global_late") == ("normal", "written at exit")

    # The same change with a kill of the engine instead of an orderly exit: it is lost (M-0001, M-0006).
    shutil.rmtree(datadir / "Variables")
    other = chains(FULL_CHAIN, slow, session=new_session())
    wait_ready_count(other, 1)
    run_flow(other, "setter")
    time.sleep(scaled(0.5))
    pid = other.pid("engine")
    psutil.Process(pid).kill()
    other.wait_restarted_ready("engine", pid, timeout=15.0)
    time.sleep(scaled(1.0))
    assert read_pair(datadir, "global_late") is None


# --- a frozen storage -------------------------------------------------------------------------------------------

def test_frozen_storage_does_not_block_the_engine_and_the_write_happens_after_thawing(chains, datadir):
    write_flow(datadir, "setter", "Action_TestSetVar", {"Steps": steps(
        {"op": "set", "name": "global_frozen", "value": "after the thaw"})})
    chain = chains(FULL_CHAIN, [*OPTS, "--var-write-timeout-ms=1000"])
    wait_ready_count(chain, 1)
    storage = chain.pid("storage")
    chain.freeze(storage)
    t0 = time.perf_counter()
    run_flow(chain, "setter")                               # the engine runs the flow while storage is frozen
    assert chain.snapshot_ok()["flows"], "engine does not answer"
    assert time.perf_counter() - t0 < scaled(3.0)
    error = chain.rec.wait(event("evt.storage.error", op="var.set"), scaled(6.0))
    assert error is not None, "no evt.storage.error for the variable:\n" + chain.sup.text()
    assert read_pair(datadir, "global_frozen") is None
    chain.thaw(storage)
    assert wait_pair(datadir, "global_frozen", lambda p: True, timeout=scaled(15.0)) == ("normal", "after the thaw")
