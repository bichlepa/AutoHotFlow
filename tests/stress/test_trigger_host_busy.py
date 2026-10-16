"""WI-0067 task 2 (REQ-TRG-010): the trigger host keeps its timers on schedule while the engine is busy.

Part without keys (done here): an inline test element blocks the ENGINE for BUSY_MS (Action_TestBlockInline), while a
Trigger_TestTimer (the trigger host, its own process) fires every INTERVAL_MS. Every fire writes the host-side time
(A_TestTick, the A_TickCount of the trigger host) and every instance writes the time at which the engine processed it
(A_TickCount in the engine). A_TickCount is one clock for all processes of the machine (GetTickCount, 15.6 ms
resolution), so the host times, the busy window and the processing times compare directly.

Not in this file (pending the owner, see NEEDS-ATTENTION.md and doc/MANUAL-CHECKS.md): a hotkey on an unassigned key
during the busy time (the hook must not be removed by Windows and must fire afterwards). That needs a decision on how
keys are delivered in the tests.

The figures are recorded with metrics.record (MEASURE line, AHF_MEASURE_OUT). The asserts are the minimum the
requirement needs; the figures are the measurement.
"""

import json
import statistics
import time

import psutil
import pytest

from support import metrics
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled

HOST_ROLES = "storage,engine,triggerhost"
INTERVAL_MS = 100
BUSY_MS = 3000
SETTLE_S = 1.0          # ticks before the busy block, and after it, to see the processing


@pytest.fixture
def host_flows(procs, datadir, session_id):
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def build_flows():
    """The three flows: the lists (init), the ticks of the timer, the busy block of the engine."""
    init = FlowBuilder("busy-init")
    steps = [init.action("Action_New_List", Varname=name, NumberOfElements="Multiple", VarValues="init")
             for name in ("global_ticks", "global_procs", "global_marks")]
    init.chain(init.trigger(), *steps, init.action("Action_Do_nothing"))

    ticks = FlowBuilder("busy-ticks", execution_policy="parallel", flow_settings={"maxParallelInstances": 0})
    timer = ticks.trigger("Test.Trigger_TestTimer", Interval=str(INTERVAL_MS))     # the test package (not Action_Test*)
    host_side = ticks.action("Action_Add_To_List", Varname="global_ticks", NumberOfElements="One",
                             VarValue="A_TestTick", expression="Expression", WhichPosition="Last")
    engine_side = ticks.action("Action_Add_To_List", Varname="global_procs", NumberOfElements="One",
                               VarValue="A_TickCount", expression="Expression", WhichPosition="Last")
    ticks.chain(timer, host_side, engine_side, ticks.action("Action_Do_nothing"))

    busy = FlowBuilder("busy-block")
    mark_start = busy.action("Action_Add_To_List", Varname="global_marks", NumberOfElements="One",
                             VarValue="A_TickCount", expression="Expression", WhichPosition="Last")
    block = busy.action("Action_TestBlockInline", Duration=str(BUSY_MS))
    mark_end = busy.action("Action_Add_To_List", Varname="global_marks", NumberOfElements="One",
                           VarValue="A_TickCount", expression="Expression", WhichPosition="Last")
    busy.chain(busy.trigger(), mark_start, block, mark_end, busy.action("Action_Do_nothing"))
    return init, ticks, timer, busy


def read_list(host_flows, name):
    """The values of a global list (without the initial "init"), as the engine wrote them to its file."""
    pair = host_flows.wait_var(name)
    assert pair is not None, (name, host_flows.stderr_text())
    return [v for v in json.loads(pair[1]) if v != "init"]


@pytest.mark.stress
@pytest.mark.timeout(240)
def test_the_host_keeps_its_timer_while_the_engine_is_blocked(host_flows):
    init, ticks, timer, busy = build_flows()
    init_id = host_flows.add(init)
    ticks_id = host_flows.add(ticks)
    busy_id = host_flows.add(busy)
    state_dir = host_flows.datadir / "FlowStates"
    state_dir.mkdir(exist_ok=True)
    (state_dir / (ticks_id + ".json")).write_text(
        json.dumps({"formatVersion": 1, "enabled": [timer.id]}), encoding="utf-8")
    host_flows.start()
    host_flows.run(init_id, timeout=scaled(30))
    time.sleep(SETTLE_S)                                  # the timer runs alone: the baseline of the schedule
    psutil.cpu_percent(interval=None)
    busy_run = host_flows.run(busy_id, timeout=scaled(60))
    assert busy_run.reason == "finished" and not busy_run.exceptions, (busy_run.reason, busy_run.exceptions)
    time.sleep(SETTLE_S)
    cpu_after_busy = psutil.cpu_percent(interval=None)
    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": ticks_id})     # no more ticks
    time.sleep(SETTLE_S)                                  # the queued instances are processed, the files written

    host = [int(v) for v in read_list(host_flows, "global_ticks")]
    procs = [int(v) for v in read_list(host_flows, "global_procs")]
    marks = [int(v) for v in read_list(host_flows, "global_marks")]
    assert len(marks) == 2 and len(host) > 0, (marks, len(host), host_flows.stderr_text())
    busy_start, busy_end = marks
    assert busy_end - busy_start >= BUSY_MS * 0.95, (busy_start, busy_end)

    pairs = list(zip(host, procs))
    gaps = [b - a for a, b in zip(host, host[1:])]
    busy_gaps = [b - a for a, b in zip(host, host[1:]) if busy_start <= a and b <= busy_end]
    in_busy = [h for h in host if busy_start <= h <= busy_end]
    lags = [p - h for h, p in pairs]
    busy_lags = [p - h for h, p in pairs if busy_start <= h <= busy_end]
    processed_in_busy = sum(1 for p in procs if busy_start < p < busy_end)
    first_after = min((p for h, p in pairs if busy_start <= h <= busy_end), default=None)
    expected_in_busy = (busy_end - busy_start) / INTERVAL_MS
    figures = dict(
        interval_ms=INTERVAL_MS, busy_ms=BUSY_MS, busy_measured_ms=busy_end - busy_start,
        host_fires=len(host), engine_processed=len(procs),
        host_fires_in_busy=len(in_busy), expected_in_busy=round(expected_in_busy, 1),
        host_gap_median_ms=statistics.median(gaps), host_gap_max_ms=max(gaps),
        host_gap_in_busy_median_ms=statistics.median(busy_gaps) if busy_gaps else None,
        host_gap_in_busy_max_ms=max(busy_gaps) if busy_gaps else None,
        processing_lag_median_ms=statistics.median(lags),
        processing_lag_in_busy_max_ms=max(busy_lags) if busy_lags else None,
        first_processed_after_busy_ms=(first_after - busy_end) if first_after is not None else None,
        processed_during_busy=processed_in_busy,
        cpu_system_percent_after_busy=cpu_after_busy,
        machine=metrics.machine(), run_mode="serial, alone (stress tier)",
        hotkey_part="pending owner (how keys are delivered in tests); not run")
    metrics.record("trigger host while the engine is blocked", **figures)
    print("\nMEASURE busy block: %s" % figures)

    # The host keeps firing during the block: nobody waits for the engine (the schedule is kept).
    assert len(in_busy) >= 0.8 * expected_in_busy, figures
    assert max(busy_gaps) < 2 * INTERVAL_MS + 50, figures
    # The engine processes the events queued during the block only after it, and loses none of them.
    assert processed_in_busy == 0, figures
    assert len(procs) >= len(host) - 1, figures
    assert first_after is not None and first_after >= busy_end - 20, figures
