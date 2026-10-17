"""WI-0073 task 6 (REQ-PRF-030, F-0073): the manager with 200 big flows. The data folder is the one of test_big_flows.py
(the 8 big v1 flows copied 200 times, each with an enabled timer trigger), the session is storage, engine, trigger host and
the manager.

Measured and recorded (MEASURE lines):
 - the time from the request that shows the manager ("Show manager": cmd.app.command without arguments, as the tray menu
   sends it, to a manager that is not running) to a manager that holds the 200 flows and the state "ready" (headless: the
   model, read with cmd.test.state);
 - the largest answer of cmd.engine.snapshot (bytes of the payload, seconds);
 - the private bytes of the manager with the 200 flows (headless, and with the window in the gui variant);
 - gui variant: the time the window needs to fill its tree, written by the manager to its log.
"""

import json
import time
from pathlib import Path

import psutil
import pytest

from support import metrics
from support.timing import scaled
from test_big_flows import fill_flows      # imports stresskit, which puts tests/fault on the path
from faultkit import Chain, event, request_ok, wait_until

COUNT = 200      # plus the skeleton flow that the Chain adds
READY_S = 300.0
FILLED_BUDGET_S = 10.0
ROLES = "storage,engine,triggerhost,manager"


def private_mb(pid):
    return round(psutil.Process(pid).memory_full_info().private / 2**20, 1)


def wait_engine_ready(chain):
    deadline = time.monotonic() + READY_S
    while time.monotonic() < deadline:
        if chain.rec.find(event("evt.engine.ready")):
            return
        time.sleep(0.2)
    raise AssertionError("evt.engine.ready did not come:\n" + chain.sup.text())


def manager_state(chain):
    return request_ok(chain.obs, "manager", "cmd.test.state", {}, timeout=15)["state"]


def filled(chain):
    try:
        st = manager_state(chain)
    except Exception:
        return False
    return st["engine"] == "ready" and len(st["flows"]) >= COUNT


@pytest.mark.stress
@pytest.mark.timeout(700)
def test_the_manager_holds_200_big_flows_quickly_and_in_little_memory(procs, datadir, session_id):
    names, total = fill_flows(datadir, COUNT)
    chain = Chain(procs, datadir, session_id, ROLES, ["--headless"], run_timeout=650)
    try:
        wait_engine_ready(chain)
        assert wait_until(lambda: filled(chain), scaled(60.0)), "the manager never held the 200 flows"
        # the largest snapshot answer: size and time
        t0 = time.perf_counter()
        ans = chain.obs.request("engine", "cmd.engine.snapshot", {}, timeout=30)
        snap_s = time.perf_counter() - t0
        snap_bytes = len(json.dumps(ans["payload"]))
        assert ans["payload"]["ok"] and len(ans["payload"]["flows"]) >= COUNT
        mem_running = private_mb(chain.pid("manager"))

        # Show manager when it is not running: kill it, then ask the supervisor as the tray menu does.
        old = chain.pid("manager")
        psutil.Process(old).kill()
        assert chain.rec.wait(event("evt.process.crashed", name="manager"), timeout=10) is not None
        t1 = time.perf_counter()
        request_ok(chain.obs, "supervisor", "cmd.app.command", {"argv": []})
        t_ready = None
        deadline = time.perf_counter() + scaled(FILLED_BUDGET_S * 3)
        while time.perf_counter() < deadline:
            st = chain.states().get("manager", {})
            if st.get("state") == "ready" and st.get("pid") != old:
                t_ready = time.perf_counter() - t1
                break
            time.sleep(0.02)
        assert t_ready is not None, "no new manager:\n" + chain.sup.text()
        while time.perf_counter() < deadline and not filled(chain):
            time.sleep(0.02)
        t_filled = time.perf_counter() - t1
        assert filled(chain), "the new manager never held the 200 flows"
        mem_new = private_mb(chain.pid("manager"))
        metrics.record("manager with 200 big flows", flows=COUNT, megabytes=round(total / 2**20, 2),
                       seconds_show_to_process_ready=round(t_ready, 2), seconds_show_to_filled=round(t_filled, 2),
                       snapshot_bytes=snap_bytes, snapshot_seconds=round(snap_s, 3),
                       manager_private_mb_running=mem_running, manager_private_mb_new=mem_new,
                       machine=metrics.machine())
        print("\nshow to filled %.2f s (process ready after %.2f s), snapshot %d bytes in %.3f s, manager private %s / %s MB"
              % (t_filled, t_ready, snap_bytes, snap_s, mem_running, mem_new))
        assert t_filled < scaled(FILLED_BUDGET_S), t_filled
    finally:
        chain.close()


@pytest.mark.stress
@pytest.mark.gui
@pytest.mark.timeout(700)
def test_the_window_fills_its_tree_with_200_big_flows(procs, datadir, session_id):
    """Gui: the manager with its window. The window logs the time of the first fill with the engine ready."""
    fill_flows(datadir, COUNT)
    chain = Chain(procs, datadir, session_id, ROLES, [], run_timeout=650)
    mem = None
    try:
        wait_engine_ready(chain)
        chain.wait_ready(["manager"], timeout=scaled(60.0))
        time.sleep(scaled(10.0))               # the window fills its tree by a timer after the snapshot
        mem = private_mb(chain.pid("manager"))
        snap = request_ok(chain.obs, "manager", "cmd.diag.snapshot", {})["snapshot"]
        assert snap["info"]["flows"] >= COUNT and snap["info"]["windowVisible"] == 1, snap["info"]
    finally:
        chain.close()
    log = (Path(datadir) / "Log" / "Log_manager.txt").read_text(encoding="utf-8", errors="replace")
    lines = [ln for ln in log.splitlines() if "first display with the engine ready" in ln]
    assert lines, "the window did not log its first display"
    metrics.record("manager window with 200 big flows", flows=COUNT, manager_private_mb=mem,
                   first_display=lines[0].split("first display with the engine ready:")[1].strip(),
                   machine=metrics.machine())
    print("\nwindow: %s, manager private %s MB" % (lines[0].split("ready:")[1].strip(), mem))
