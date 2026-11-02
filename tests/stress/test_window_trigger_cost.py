"""WI-0132 task 1 (REQ-TRG-010, ELEMENT-API-V2): the cost of ten armed window or process triggers in the trigger host, and
their effect on the other triggers. Measured in a real session (storage, engine, triggerhost) against the baseline of
the same session with only the test timer armed (Test.Trigger_TestTimer, a 100 ms timer in the trigger host):

  baseline           the timer alone
  window shared      ten Trigger_Window_Opens with the same interval (100 ms): one shared poll (WatchPoll)
  process shared     ten Trigger_Process_starts with the same interval (100 ms): one shared poll and one snapshot per tick
  window distinct    ten Trigger_Window_Opens with ten intervals (100 to 190 ms): ten polls

Figures: CPU of the trigger host process (percent of one core, from its CPU times over SAMPLE_S), system CPU, and the gaps
between the ticks of the test timer (host side, A_TickCount of the trigger host: 15.6 ms resolution). The triggers watch
names that exist nowhere (no window, no process), so nothing fires and no own window or process is started. Serial, alone
(stress tier). The figures go to doc/MEASUREMENTS.md; the asserts are only the minimum (all armed, the timer runs).
"""

import json
import statistics
import time
import uuid

import psutil
import pytest

from support import metrics
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner, session_processes
from support.triggerwait import wait_armed

HOST_ROLES = "storage,engine,triggerhost"
COUNT = 10
SAMPLE_S = 15.0
TIMER_MS = 100
POLL_MS = 100


def trigger_host_pid(session):
    """The pid of the trigger host role of the session (its command line names the role)."""
    for pid in session_processes(session):
        try:
            if "--role=triggerhost" in " ".join(psutil.Process(pid).cmdline()):
                return pid
        except psutil.Error:
            continue
    return None


def ticks_flow():
    """The test timer (trigger host) and the list of its host-side ticks: the time of every tick goes to global_ticks."""
    init = FlowBuilder("cost-init")
    init_step = init.action("Action_New_List", Varname="global_ticks", NumberOfElements="Multiple", VarValues="init")
    init.chain(init.trigger(), init_step, init.action("Action_Do_nothing"))
    fb = FlowBuilder("cost-ticks", execution_policy="parallel", flow_settings={"maxParallelInstances": 0})
    timer = fb.trigger("Test.Trigger_TestTimer", Interval=str(TIMER_MS))
    stamp = fb.action("Action_Add_To_List", Varname="global_ticks", NumberOfElements="One", VarValue="A_TestTick",
                      expression="Expression", WhichPosition="Last")
    fb.chain(timer, stamp, fb.action("Action_Do_nothing"))
    return init, fb, timer


def armed_flows(variant):
    """The flows of the variant: (builder, trigger) pairs. Every trigger watches a name that does not exist."""
    token = uuid.uuid4().hex[:8]
    flows = []
    for i in range(COUNT):
        if variant == "process shared":
            name = "ahf_cost_%s_%d.exe" % (token, i)
            fb = FlowBuilder("process-%d" % i)
            trigger = fb.trigger("Trigger_Process_starts", ProcessName=name, interval=str(POLL_MS),
                                 NotTriggerOnEnable="1")
        else:
            title = "AhfCostWindow-%s-%d" % (token, i)
            interval = POLL_MS + (i * 10 if variant == "window distinct" else 0)
            fb = FlowBuilder("window-%d" % i)
            trigger = fb.trigger("Trigger_Window_Opens", Wintitle=title, TitleMatchMode="3", interval=str(interval),
                                 NotTriggerOnEnable="1")
        fb.chain(trigger, fb.action("Action_Do_nothing"))
        flows.append((fb, trigger))
    return flows


def gaps_of(values):
    return [b - a for a, b in zip(values, values[1:])]


def run_variant(procs, tmp_path, index, variant):
    """One session of the variant: returns the figures (CPU of the trigger host, tick gaps, the armed count)."""
    session = "cost" + uuid.uuid4().hex[:10]
    datadir = tmp_path / ("variant-%d" % index)
    datadir.mkdir()
    runner = FlowRunner(procs, datadir, session, roles=HOST_ROLES)
    try:
        init, ticks, timer = ticks_flow()
        init_id = runner.add(init)
        tick_id = runner.add(ticks)
        ids = []
        if variant != "baseline":
            for fb, trigger in armed_flows(variant):
                ids.append((runner.add(fb), trigger))
        state_dir = runner.datadir / "FlowStates"
        state_dir.mkdir(exist_ok=True)
        (state_dir / (tick_id + ".json")).write_text(
            json.dumps({"formatVersion": 1, "enabled": [timer.id]}), encoding="utf-8")
        for fid, trigger in ids:
            (state_dir / (fid + ".json")).write_text(
                json.dumps({"formatVersion": 1, "enabled": [trigger.id]}), encoding="utf-8")
        runner.start()
        runner.run(init_id, timeout=30)
        armed = sum(1 for fid, trigger in ids if wait_armed(runner, fid, trigger.id, timeout=20))
        assert armed == len(ids), (variant, armed, len(ids), runner.stderr_text())
        time.sleep(1.0)                                   # the timer runs alone for a moment: the schedule settles
        host = psutil.Process(trigger_host_pid(runner.sessions[-1]))
        psutil.cpu_percent(interval=None)
        cpu0 = host.cpu_times()
        t0 = time.monotonic()
        time.sleep(SAMPLE_S)
        cpu1 = host.cpu_times()
        wall = time.monotonic() - t0
        system = psutil.cpu_percent(interval=None)
        host_cpu = ((cpu1.user + cpu1.system) - (cpu0.user + cpu0.system)) / wall * 100.0
        runner.request_ok("engine", "cmd.flow.disable", {"flowId": tick_id})
        time.sleep(1.0)
        pair = runner.wait_var("global_ticks")
        assert pair is not None, runner.stderr_text()
        values = [int(v) for v in json.loads(pair[1]) if v != "init"]
        gaps = gaps_of(values)
        return dict(variant=variant, armed=armed, host_cpu_percent=round(host_cpu, 2),
                    system_cpu_percent=system, ticks=len(values),
                    gap_median_ms=statistics.median(gaps) if gaps else None,
                    gap_p95_ms=sorted(gaps)[int(0.95 * (len(gaps) - 1))] if gaps else None,
                    gap_max_ms=max(gaps) if gaps else None)
    finally:
        runner.close()


@pytest.mark.stress
@pytest.mark.timeout(600)
def test_ten_armed_window_or_process_triggers_cost_little_in_the_trigger_host(procs, tmp_path):
    results = []
    for index, variant in enumerate(["baseline", "window shared", "process shared", "window distinct"]):
        result = run_variant(procs, tmp_path, index, variant)
        results.append(result)
        print("\nMEASURE trigger cost: %s" % result)
    figures = dict(count=COUNT, sample_s=SAMPLE_S, timer_ms=TIMER_MS, poll_ms=POLL_MS, results=results,
                   machine=metrics.machine(), run_mode="serial, alone (stress tier)")
    metrics.record("ten armed window or process triggers in the trigger host", **figures)
    baseline = results[0]
    for result in results:
        assert result["ticks"] >= 10, (result, "the test timer did not run")
        assert result["gap_max_ms"] is not None and result["gap_max_ms"] < 2000, result
    assert baseline["armed"] == 0
    for result in results[1:]:
        assert result["armed"] == COUNT, result
