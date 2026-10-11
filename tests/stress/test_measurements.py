"""WI-16: the performance budgets of ARCHITEKTUR 9, measured on the real chain (storage, engine, manager stub).

 - message latency: answer time of `cmd.engine.snapshot` (client -> hub -> engine -> hub -> client), idle and
   under load (instances start continuously). Budget: median under 5 ms, p99 under 50 ms.
 - idle CPU of the whole system without a flow, over 30 s. Budget: under 1 %.
 - memory of the idle chain (the editor does not exist yet, so "5 open editors" cannot be measured).
 - time from the start of the supervisor until all roles are ready and the engine has loaded its flows.
   Budget: under 3 s.

Every test prints one MEASURE line (see support/metrics.py) with the numbers. The budgets are asserted, not
loosened: a miss is a finding. Python clients wake the hub like AHK roles do (stresskit.StressClient). The test
that shows the unwoken case documents the 250 ms hub timer and does not assert a budget.
"""

import statistics
import threading
import time
import uuid
from pathlib import Path

import psutil
import pytest

from stresskit import _connect, hwnd_of, stress_chain  # noqa: F401  (fixture)
from faultkit import (FULL_CHAIN, SKELETON_FLOW, SKELETON_SRC, STUB_OPTS, Sup, kill_ours, session_processes,
                      wait_until)
from support import metrics

MEDIAN_BUDGET_MS = 5.0
P99_BUDGET_MS = 50.0
IDLE_CPU_BUDGET_PCT = 1.0
STARTUP_BUDGET_S = 3.0
LOAD_FLOW = "load"


def measure_snapshot(client, count):
    values = []
    for _ in range(count):
        t0 = time.perf_counter()
        answer = client.request("engine", "cmd.engine.snapshot", {}, timeout=5)
        values.append((time.perf_counter() - t0) * 1000)
        assert answer["payload"]["ok"], answer
    return values


class Loader(threading.Thread):
    """Starts a new instance of the load flow every `period` seconds and counts what it started."""

    def __init__(self, client, period):
        super().__init__(name="loader", daemon=True)
        self.client, self.period = client, period
        self.stop_flag = threading.Event()
        self.started = 0
        self.errors = []

    def run(self):
        while not self.stop_flag.is_set():
            try:
                answer = self.client.request("engine", "cmd.flow.start", {"flowId": LOAD_FLOW}, timeout=5)
                if not answer["payload"].get("ok"):
                    self.errors.append(answer["payload"])
                self.started += 1
            except Exception as exc:
                self.errors.append("%s: %s" % (type(exc).__name__, exc))
            self.stop_flag.wait(self.period)


@pytest.mark.stress
@pytest.mark.timeout(200)
def test_message_latency_idle_and_under_load_is_within_the_budget(stress_chain):
    sc = stress_chain(flows={LOAD_FLOW: (200, "parallel")})
    probe = sc.client("probe")
    loader_client = sc.client("loader")
    measure_snapshot(probe, 100)                                  # warm up
    idle = metrics.Dist(measure_snapshot(probe, 2000))

    load = Loader(loader_client, 0.005)
    load.start()
    time.sleep(0.5)
    try:
        loaded = metrics.Dist(measure_snapshot(probe, 3000))
    finally:
        load.stop_flag.set()
        load.join(timeout=10)
    assert not load.errors, load.errors[:3]

    metrics.record("message latency snapshot", idle_ms=idle.as_dict(), under_load_ms=loaded.as_dict(),
                   instances_started_during_load=load.started, machine=metrics.machine())
    print("\nlatency idle: %s\nlatency under load (%d instances started): %s" % (idle, load.started, loaded))
    assert idle.median < MEDIAN_BUDGET_MS and idle.p99 < P99_BUDGET_MS, str(idle)
    assert loaded.median < MEDIAN_BUDGET_MS and loaded.p99 < P99_BUDGET_MS, str(loaded)


@pytest.mark.stress
@pytest.mark.timeout(120)
def test_message_latency_of_a_client_that_does_not_wake_the_hub_is_documented(stress_chain):
    # Not a budget test: a Python client without a window reaches the hub on its 250 ms timer only. Real AHK
    # roles wake the hub (Peer option hubHwnd), so this is the worst case for a client that cannot.
    sc = stress_chain(flows={}, wake_hub=False)
    probe = sc.client("probe")
    measure_snapshot(probe, 5)
    values = measure_snapshot(probe, 100)
    dist = metrics.Dist(values)
    metrics.record("message latency snapshot, hub not woken", ms=dist.as_dict())
    print("\nlatency without wake of the hub: %s" % dist)
    assert dist.max < 600, str(dist)       # a lost wake only delays: never more than the timer plus the path


@pytest.mark.stress
@pytest.mark.timeout(200)
def test_idle_cpu_and_memory_of_the_chain_without_a_flow(stress_chain):
    sc = stress_chain(flows={})
    time.sleep(5.0)                         # let the start settle (flow loading, first pings)
    roles, tooling = {}, {}
    for p in psutil.process_iter(["pid", "cmdline"]):
        cmd = p.info.get("cmdline") or []
        if any(("--session=" + sc.session) in part for part in cmd):
            (tooling if any("ahkrun" in part for part in cmd) else roles)[p.info["pid"]] = p
    assert len(roles) >= 4, "expected supervisor, storage, engine, manager: %s" % [list(roles)]
    seconds = 30.0
    cpu = metrics.cpu_percent_over(list(roles) + list(tooling), seconds)
    names = {sc.sup_pid: "supervisor", **{p["pid"]: n for n, p in sc.process_list().items()}}
    role_cpu = {names.get(pid, str(pid)): round(cpu[pid], 3) for pid in roles if pid in cpu}
    wrapper_cpu = {str(pid): round(cpu[pid], 3) for pid in tooling if pid in cpu}
    cores = psutil.cpu_count()
    total_cores_pct = sum(role_cpu.values())
    system_pct = total_cores_pct / cores
    rss = {names.get(pid, str(pid)): metrics.proc_snapshot(pid)["rss_mb"] for pid in roles}
    total_rss = round(sum(rss.values()), 1)
    metrics.record("idle cpu and memory", seconds=seconds, cores=cores, role_cpu_percent_of_one_core=role_cpu,
                   roles_sum_percent_of_one_core=round(total_cores_pct, 3), system_percent=round(system_pct, 4),
                   ahkrun_wrapper_percent_of_one_core=wrapper_cpu, rss_mb=rss, rss_sum_mb=total_rss,
                   machine=metrics.machine())
    print("\nidle cpu over %.0f s: roles %s (sum %.3f %% of one core = %.4f %% of the system), "
          "ahkrun wrappers (test tooling) %s\nrss %s, sum %.1f MB"
          % (seconds, role_cpu, total_cores_pct, system_pct, wrapper_cpu, rss, total_rss))
    # The budget is for the whole system, so the sum is normalized to all logical CPUs (the Task Manager
    # convention). The sum as percent of ONE core is recorded above; it is higher by the factor `cores`.
    assert system_pct < IDLE_CPU_BUDGET_PCT, (role_cpu, system_pct)


def start_chain_and_time_it(procs, datadir_root, run_no):
    """One supervisor from process start to all roles ready and the flows loaded. Returns the timings (s)."""
    session = "t" + uuid.uuid4().hex[:12]
    datadir = Path(datadir_root) / ("run%d" % run_no)
    (datadir / "Flows").mkdir(parents=True)
    (datadir / "Flows" / (SKELETON_FLOW + ".json")).write_bytes(SKELETON_SRC.read_bytes())
    sup = Sup(procs, datadir, session, ["--start=" + FULL_CHAIN, *STUB_OPTS], label="sup%d" % run_no)
    client = None
    try:
        hwnd = hwnd_of(sup.ahk_pid())
        t_window = time.perf_counter() - sup.t0
        client = _connect(sup.pipe, "obs", hwnd)
        t_connected = time.perf_counter() - sup.t0

        def all_ready():
            answer = client.request("supervisor", "cmd.process.list", {}, timeout=5)
            st = {p["name"]: p["state"] for p in answer["payload"]["processes"]}
            return all(st.get(n) == "ready" for n in ("storage", "engine", "manager"))

        assert wait_until(all_ready, 15.0, step=0.01), "roles not ready:\n" + sup.text()
        t_ready = time.perf_counter() - sup.t0

        def flows_loaded():
            answer = client.request("engine", "cmd.engine.snapshot", {}, timeout=5)
            return answer["payload"].get("ok") and answer["payload"]["flows"]

        assert wait_until(flows_loaded, 10.0, step=0.01), "engine did not load its flows"
        t_flows = time.perf_counter() - sup.t0
        client.request("supervisor", "cmd.app.exit", {}, timeout=5)
        code = sup.wait_exit(timeout=30)
        assert code == 0, "exit code %s:\n%s" % (code, sup.text())
        return {"window": t_window, "connected": t_connected, "roles_ready": t_ready, "flows_loaded": t_flows}
    finally:
        if client is not None:
            client.close()
        if sup.proc.poll() is None:
            procs.kill(sup.proc)
        for pid in session_processes(session):
            kill_ours(pid, session)
        wait_until(lambda: not session_processes(session), 5.0)
        sup.close()


@pytest.mark.parametrize("runs", [pytest.param(1, id="smoke"),
                                  pytest.param(10, id="10", marks=[pytest.mark.stress, pytest.mark.timeout(300)])])
def test_start_to_ready_time(procs, tmp_path, runs):
    results = [start_chain_and_time_it(procs, tmp_path, n) for n in range(runs)]
    summary = {}
    for key in results[0]:
        values = [r[key] for r in results]
        summary[key] = {"runs": runs, "median": round(statistics.median(values), 3), "max": round(max(values), 3)}
    metrics.record("start to ready", runs=runs, seconds=summary, machine=metrics.machine())
    print("\nstart to ready (%d runs): %s" % (runs, summary))
    limit = STARTUP_BUDGET_S if runs > 1 else 10.0          # one smoke run only guards against a hang
    assert summary["flows_loaded"]["median"] < limit, summary
    if runs > 1:
        assert summary["flows_loaded"]["max"] < limit * 2, summary      # no outlier beyond twice the budget
