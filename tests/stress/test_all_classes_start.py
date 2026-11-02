"""WI-0135 task 4 (REQ-PRF-030, R0003, E0040): memory and start with all real element classes (the 152 of v1).

MS-0042 and MS-0029 were measured before S0008, with the classes of the core set (and synthetic classes). The role entries
in src/entry/ include the real element files of their mode now (the generated includes), so a normal session shows the cost
of all classes. Two measurements:

 - memory: supervisor, storage, engine, trigger host, manager (headless) and tray with one warm worker, then one editor
   (a real editor process opened through the headless manager). The budget of E0040 (below 100 MB private bytes, the sum of
   the background processes; editors are not counted) is asserted for the background processes; the editor is recorded.
 - start: the time of a worker from cmd.process.spawn to the state ready (tools/measure_r3.py worker_start, the method of
   MS-0029), 3 workers per run.

Run: python -m pytest tests/stress/test_all_classes_start.py -m stress -q -n 0
"""

import sys
import time
from pathlib import Path

import psutil
import pytest

from support import metrics
from support.timing import scaled

TESTS_DIR = Path(__file__).resolve().parents[1]
ROOT = TESTS_DIR.parent
sys.path.insert(0, str(TESTS_DIR / "e2e"))
sys.path.insert(0, str(ROOT / "tools"))

from test_manager import FLOW, Sup, connect_obs, flow_data, wait_ready, wait_until  # noqa: E402
from test_manager_editor import edit_results, finish, op  # noqa: E402
from test_trigger_host_memory import background_processes, sample, totals  # noqa: E402

RUNS = 3
START_RUNS = 5
SAMPLE_S = 10.0


@pytest.mark.stress
@pytest.mark.timeout(300)
@pytest.mark.parametrize("run", range(RUNS))
def test_memory_of_the_processes_with_all_real_classes_and_one_editor(procs, datadir, session_id, run):
    flow_data(datadir)
    sup = Sup(procs, datadir, session_id, ["--start=storage,engine,triggerhost,manager", "--headless", "--tray",
                                           "--workers=1", "--warm-workers=1"])
    obs = connect_obs(sup.pipe)
    try:
        wait_ready(obs, ["storage", "engine", "triggerhost", "manager"])
        time.sleep(2.0)
        before = sample(background_processes(session_id))
        time.sleep(SAMPLE_S)
        background = sample(background_processes(session_id))
        op(obs, "select", flowId=FLOW)
        assert edit_results(obs, flowId=FLOW)[0][3] is True
        assert wait_until(lambda: any(n.startswith("editor") for n, _ in background_processes(session_id).values()), scaled(20))
        time.sleep(SAMPLE_S)
        with_editor = sample(background_processes(session_id))
    finally:
        try:
            finish(sup, obs)
        except Exception:
            pass
    background_mb, background_wset = totals(background)
    all_mb, all_wset = totals(with_editor)
    editors = [r["private_mb"] for n, rs in with_editor.items() if n.startswith("editor") for r in rs]
    per_role = {n: [r["private_mb"] for r in rs] for n, rs in with_editor.items() if not n.startswith("wrapper")}
    metrics.record("memory with all real classes", run=run, background_private_mb=background_mb,
                   background_wset_mb=background_wset, early_private_mb=totals(before)[0], with_editor_private_mb=all_mb,
                   with_editor_wset_mb=all_wset, editor_private_mb=editors, per_role_private_mb=per_role,
                   cpu_system_percent=psutil.cpu_percent(interval=None), machine=metrics.machine())
    print("\nMEASURE all classes: background %.1f MB (wset %.1f), with editor %.1f MB (editor %s), per role %s"
          % (background_mb, background_wset, all_mb, editors, per_role))
    assert editors, "no editor process was sampled"
    assert background_mb < 100.0, (background_mb, per_role)


@pytest.mark.stress
@pytest.mark.timeout(600)
def test_start_of_a_worker_with_all_real_classes(procs, datadir):
    import measure_r3
    rows = []
    for run in range(START_RUNS):
        folder = Path(datadir) / ("run%d" % run)
        folder.mkdir()
        rows.append(measure_r3.worker_start(ROOT / "tests" / "integration" / "helpers" / "AutoHotFlowTest.ahk", procs, folder))
    times = sorted(t for r in rows for t in r["worker_start_ms"])
    median = times[len(times) // 2]
    mem = [r["worker_mem"] for r in rows]
    metrics.record("start of a worker with all real classes", times_ms=times, median_ms=median, worker_mem=mem,
                   machine=metrics.machine())
    print("\nMEASURE worker start: median %.0f ms (min %.0f, max %.0f), %d values; memory %s"
          % (median, times[0], times[-1], len(times), mem))
    assert median < scaled(1000.0)
