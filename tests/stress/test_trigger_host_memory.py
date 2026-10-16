"""WI-0067 task 3 (REQ-PRF-030, E0040): the memory of the background processes with the real trigger host and armed
triggers. The session is the product as far as the test can start it: supervisor, storage, engine, trigger host and
the manager stub (headless), with a flow for each trigger kind that runs in the background: five periodic timers, a
Start_up trigger and a manual trigger, all enabled through FlowStates. (No hotkey: it needs keys, see
test_trigger_host_busy.py.)

The figures are the private bytes, the working set and the handles of every process, sampled 2 s after the start
(armed, nothing else running) and again after SAMPLE_S seconds of armed triggers (the timers fire about every second).
The triggers fire into flows without workers, so no worker process is started by them.
"""

import json
import time

import psutil
import pytest

from support import metrics
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner, session_processes
from support.timing import scaled

ROLES = "storage,engine,triggerhost,manager"
STUB = ["--ui=stub", "--headless"]
PERIODIC_FLOWS = 5
PERIOD_MS = 1000
SAMPLE_S = 30.0


@pytest.fixture
def host_flows(procs, datadir, session_id):
    runner = FlowRunner(procs, datadir, session_id, roles=ROLES)
    yield runner
    runner.close()


def background_processes(session):
    """pid -> (name, psutil.Process) of the processes of the session: the supervisor, the roles and the wrappers."""
    found = {}
    for pid in session_processes(session):
        try:
            p = psutil.Process(pid)
            cmd = " ".join(p.cmdline())
        except psutil.Error:
            continue
        if "ahkrun" in cmd:
            name = "wrapper (test tooling)"
        elif "--role=" in cmd:
            name = cmd.split("--role=")[1].split()[0]
        else:
            name = "supervisor"
        found[pid] = (name, p)
    return found


def sample(procs_by_pid):
    rows = {}
    for pid, (name, p) in procs_by_pid.items():
        try:
            full = p.memory_full_info()
            rows.setdefault(name, []).append(dict(
                pid=pid, private_mb=round(full.private / 2**20, 2), wset_mb=round(full.rss / 2**20, 2),
                handles=p.num_handles()))
        except psutil.Error:
            pass
    return rows


def totals(rows):
    """Sum over the background processes (not the wrapper), private bytes and working set in MB."""
    private = sum(r["private_mb"] for name, rs in rows.items() if not name.startswith("wrapper") for r in rs)
    wset = sum(r["wset_mb"] for name, rs in rows.items() if not name.startswith("wrapper") for r in rs)
    return round(private, 1), round(wset, 1)


@pytest.mark.stress
@pytest.mark.timeout(300)
def test_memory_of_the_background_processes_with_armed_triggers(host_flows):
    state_dir = host_flows.datadir / "FlowStates"
    state_dir.mkdir(exist_ok=True)
    armed = {}
    for i in range(PERIODIC_FLOWS):
        fb = FlowBuilder("periodic-%d" % i)
        timer = fb.trigger("Trigger_Periodic_Timer", Interval=str(PERIOD_MS), Unit="MilliSeconds")
        fb.chain(timer, fb.action("Action_Do_nothing"))
        fid = host_flows.add(fb)
        armed[fid] = timer.id
    fb = FlowBuilder("startup")
    startup = fb.trigger("Trigger_Start_up", startupType="AutoHotFlow")
    fb.chain(startup, fb.action("Action_Do_nothing"))
    armed[host_flows.add(fb)] = startup.id
    fb = FlowBuilder("manual")
    manual = fb.trigger()
    fb.chain(manual, fb.action("Action_Do_nothing"))
    armed[host_flows.add(fb)] = manual.id
    for fid, trigger_id in armed.items():
        (state_dir / (fid + ".json")).write_text(
            json.dumps({"formatVersion": 1, "enabled": [trigger_id]}), encoding="utf-8")

    host_flows.start(extra=STUB)
    time.sleep(2.0)
    early = sample(background_processes(host_flows.sessions[-1]))
    cpu_before = psutil.cpu_percent(interval=None)
    time.sleep(SAMPLE_S)
    late = sample(background_processes(host_flows.sessions[-1]))
    cpu_after = psutil.cpu_percent(interval=None)

    # the triggers really fired: every periodic flow started instances during the sample time
    starts = {}
    for m in host_flows.messages():
        if m.get("type") == "evt.instance.started":
            starts[m["payload"]["flowId"]] = starts.get(m["payload"]["flowId"], 0) + 1
    fired = {fid: starts.get(fid, 0) for fid in armed if fid.startswith("periodic-")}
    assert all(n >= 5 for n in fired.values()), (fired, host_flows.stderr_text())
    names = sorted(set(early) | set(late))
    early_private, early_wset = totals(early)
    late_private, late_wset = totals(late)
    per_role = {name: {"private_mb": [r["private_mb"] for r in late.get(name, [])],
                       "wset_mb": [r["wset_mb"] for r in late.get(name, [])],
                       "handles": [r["handles"] for r in late.get(name, [])]} for name in names}
    figures = dict(
        roles=ROLES, periodic_flows=PERIODIC_FLOWS, period_ms=PERIOD_MS, startup_and_manual_triggers=2,
        sample_s=SAMPLE_S, early_sum_private_mb=early_private, early_sum_wset_mb=early_wset,
        late_sum_private_mb=late_private, late_sum_wset_mb=late_wset, per_role_late=per_role,
        cpu_system_percent_before=cpu_before, cpu_system_percent_after=cpu_after,
        machine=metrics.machine(), run_mode="serial, alone (stress tier)")
    metrics.record("memory of the background processes with armed triggers", **figures)
    print("\nMEASURE armed triggers: sum private %.1f MB (early %.1f), working set %.1f MB; per role %s"
          % (late_private, early_private, late_wset, per_role))
    # The budget of E0040 is the sum of the background processes below 100 MB; the trigger host itself stays small.
    assert late_private < 100.0, figures
    th = per_role.get("triggerhost", {}).get("private_mb", [])
    assert th and th[0] < 30.0, figures
