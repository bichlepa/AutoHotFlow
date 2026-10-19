"""WI-0082 task 2 (REQ-PRF-030, E0040): private bytes of the background processes in the variants of S0004.

The corpus is that of test_trigger_host_memory.py (five periodic timers, a Start_up and a manual trigger, all enabled
through FlowStates). Variants:

 - manager: the manager role runs headless (no window object; a real window is opened by the gui tests only), the tray
   role runs headless (icon hidden, E0046). 1 and 3 workers (--workers and --warm-workers are passed on to the engine).
 - startup: the product start with Windows (--windows-startup): the supervisor leaves the manager out (E0064, E0070), so
   there is no manager process. 1 and 3 workers.

Each variant is sampled RUNS times (one session each); every sample is the private bytes of every process 2 s after the
engine is ready and again SAMPLE_S seconds later. The number of worker processes is checked.
"""

import json
import time

import psutil
import pytest

from support import metrics
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled
from test_trigger_host_memory import PERIODIC_FLOWS, PERIOD_MS, background_processes, sample, totals

SAMPLE_S = 20.0
RUNS = 3

# name -> (roles, extra options, expected process names besides the workers)
VARIANTS = {
    "manager": ("storage,engine,triggerhost,manager", ["--headless", "--tray"],
                {"supervisor", "storage", "engine", "triggerhost", "manager", "tray"}),
    "startup": ("storage,engine,triggerhost,manager", ["--headless", "--tray", "--windows-startup"],
                {"supervisor", "storage", "engine", "triggerhost", "tray"}),
}


def add_corpus(runner):
    state_dir = runner.datadir / "FlowStates"
    state_dir.mkdir(exist_ok=True)
    armed = {}
    for i in range(PERIODIC_FLOWS):
        fb = FlowBuilder("periodic-%d" % i)
        timer = fb.trigger("Trigger_Periodic_Timer", Interval=str(PERIOD_MS), Unit="MilliSeconds")
        fb.chain(timer, fb.action("Action_Do_nothing"))
        armed[runner.add(fb)] = timer.id
    fb = FlowBuilder("startup")
    startup = fb.trigger("Trigger_Start_up", startupType="AutoHotFlow")
    fb.chain(startup, fb.action("Action_Do_nothing"))
    armed[runner.add(fb)] = startup.id
    fb = FlowBuilder("manual")
    manual = fb.trigger()
    fb.chain(manual, fb.action("Action_Do_nothing"))
    armed[runner.add(fb)] = manual.id
    for fid, trigger_id in armed.items():
        (state_dir / (fid + ".json")).write_text(
            json.dumps({"formatVersion": 1, "enabled": [trigger_id]}), encoding="utf-8")


def role_of(name):
    return "worker" if name.startswith("worker") else name


def wait_workers(session, count, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        found = background_processes(session)
        if sum(1 for n, _ in found.values() if n.startswith("worker")) >= count:
            return found
        time.sleep(0.2)
    return background_processes(session)


@pytest.mark.stress
@pytest.mark.timeout(300)
@pytest.mark.parametrize("run", range(RUNS))
@pytest.mark.parametrize("workers", [1, 3])
@pytest.mark.parametrize("variant", sorted(VARIANTS))
def test_memory_of_the_background_processes(procs, datadir, session_id, variant, workers, run):
    roles, extra, expected = VARIANTS[variant]
    runner = FlowRunner(procs, datadir, session_id, roles=roles)
    try:
        add_corpus(runner)
        runner.start(extra=extra + ["--workers=%d" % workers, "--warm-workers=%d" % workers])
        session = runner.sessions[-1]
        found = wait_workers(session, workers, scaled(20.0))
        time.sleep(2.0)
        early = sample(background_processes(session))
        time.sleep(SAMPLE_S)
        late = sample(background_processes(session))
    finally:
        runner.close()
    names = {role_of(n) for n in late}
    assert expected <= names, (sorted(names), runner.stderr_text())
    assert ("manager" in names) == ("manager" in expected), sorted(names)
    live_workers = sum(len(rs) for n, rs in late.items() if n.startswith("worker"))
    assert live_workers == workers, (live_workers, sorted(late))
    per_role = {}
    for n, rs in late.items():
        if n.startswith("wrapper"):
            continue
        per_role.setdefault(role_of(n), []).extend(r["private_mb"] for r in rs)
    early_private, _ = totals(early)
    late_private, late_wset = totals(late)
    metrics.record("memory of the background processes, variant", variant=variant, workers=workers, run=run,
                   sample_s=SAMPLE_S, early_sum_private_mb=early_private, late_sum_private_mb=late_private,
                   late_sum_wset_mb=late_wset, per_role_private_mb=per_role,
                   cpu_system_percent=psutil.cpu_percent(interval=None), machine=metrics.machine())
    print("\nMEASURE %s %d worker(s): sum private %.1f MB (early %.1f), per role %s"
          % (variant, workers, late_private, early_private, per_role))
    assert late_private < 100.0, (late_private, per_role)
