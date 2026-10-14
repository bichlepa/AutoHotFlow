"""WI-50 (ARCHITECTURE R4): variables in a worker element and the variable requests cmd.engine.var.* (PROTOCOL 4.5).

A real session (flow runner of WI-49): supervisor, storage, engine and the worker pool, with the test elements of
tests/elements/. The elements Action_TestVarFunctions (inline) and Action_TestVarFunctionsWorker (worker) call every
variable function in the same order and write a report of the results; the reports must be equal.
"""

import difflib
import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.timing import scaled

SET_X = '[{"op":"set","name":"x","value":7}]'


def _report(flows, tag):
    pair = flows.wait_var("global_varreport_" + tag)
    assert pair is not None, "no report of %s" % tag
    return pair[1].replace("\r\n", "\n")


def _engine_snapshot(flows):
    return flows.request_ok("engine", "cmd.diag.snapshot", {})["snapshot"]


def test_every_variable_function_gives_the_same_result_in_a_worker_as_inline(flows):
    ids = {}
    for tag, cls in (("inline", "Action_TestVarFunctions"), ("worker", "Action_TestVarFunctionsWorker")):
        fb = FlowBuilder("vars " + tag)
        fb.chain(fb.trigger(), fb.action(cls, Tag=tag))
        ids[tag] = flows.add(fb)
    for tag in ("inline", "worker"):
        run = flows.run(ids[tag], timeout=20)
        assert run.reason == "finished" and not run.exceptions, (tag, run.steps)
    inline, worker = _report(flows, "inline"), _report(flows, "worker")
    # the report is not trivially equal: the values and the errors of the inline run are there
    assert "get tv_int = Integer:42" in inline
    assert 'get tv_map = Map:{"#1":"one","#10":"ten","Key":2}' in inline, "keys of digits are Integers in a variable"
    assert "get tv_list.3.k = String:\"v\"" in inline
    assert "set hidden global ! a global variable cannot be hidden" in inline
    assert "eval syntax error ! " in inline
    assert "location A_Space = String:\"builtin\"" in inline
    diff = "\n".join(difflib.unified_diff(inline.splitlines(), worker.splitlines(), "inline", "worker", lineterm=""))
    assert inline == worker, "the worker gives other results than inline:\n" + diff
    assert _engine_snapshot(flows)["errors"]["count"] == 0


def test_a_client_reads_a_variable_of_a_running_instance_and_gets_gone_after_its_end(flows):
    fb = FlowBuilder("read while running")
    fb.chain(fb.trigger(), fb.action("Action_TestSetVar", Steps=SET_X), fb.action("Action_Sleep", Duration=1))
    run = flows.begin(fb)
    end = time.monotonic() + scaled(5)
    while True:
        answer = flows.instance_var(run.instance_id, "x")
        if (answer.get("ok") and answer["exists"]) or time.monotonic() > end:
            break
        time.sleep(0.05)
    assert answer.get("ok") and answer["exists"], answer
    assert answer["value"] == 7 and answer["type"] == "normal" and answer["location"] == "instance"
    assert flows.instance_var(run.instance_id, "A_TriggerID")["exists"] is False, "no thread variables without a thread"
    flows.wait(run)
    assert run.reason == "finished"
    gone = flows.instance_var(run.instance_id, "x")
    assert gone["ok"] is False and gone["error"]["code"] == "gone", gone


@pytest.mark.slow
def test_a_worker_element_that_asks_after_its_stop_gets_gone_and_the_pool_stays_healthy(flows):
    fb = FlowBuilder("ask after stop")
    fb.chain(fb.trigger(), fb.action("Action_TestAskAfterStopWorker", BlockMs=1500))
    echo = FlowBuilder("echo after")
    echo.chain(echo.trigger(), echo.action("Action_TestEchoWorker"))
    echo_id = flows.add(echo)
    run = flows.begin(fb)
    # the element sets ask_blocking right before it blocks: a stop now reaches it inside the block, not before its start
    end = time.monotonic() + scaled(10)
    while not flows.instance_var(run.instance_id, "ask_blocking").get("exists"):
        assert time.monotonic() < end, "the worker element did not start"
        time.sleep(0.02)
    flows.request_ok("engine", "cmd.flow.stop", {"flowId": run.flow_id})
    flows.wait(run, timeout=5)
    assert run.reason == "flow.stop"
    logged = flows._rec.wait(lambda m: m.get("type") == "evt.log.entry"
                             and "asked after the stop" in m["payload"].get("text", ""), scaled(10), run._mark)
    assert logged, "the element did not report its request after the stop"
    assert "gone" in logged[1]["payload"]["text"], logged[1]["payload"]
    # the worker confirmed the cancel in time: it stays in the pool and takes the next job
    again = flows.run(echo_id, timeout=15)
    assert again.reason == "finished" and not again.exceptions, again.steps
    snap = _engine_snapshot(flows)
    assert snap["errors"]["count"] == 0
    assert snap["info"]["workers"]["failures"] == 0, snap["info"]["workers"]


def test_round_trip_of_a_variable_request_from_a_worker(flows):
    fb = FlowBuilder("bench")
    fb.chain(fb.trigger(), fb.action("Action_TestVarBenchWorker", Count=300, Tag="b"))
    run = flows.run(fb, timeout=30)
    assert run.reason == "finished" and not run.exceptions, run.steps
    pair = flows.wait_var("global_varbench_b")
    median, p95, top = (float(x) for x in pair[1].split())
    print("\nMEASURE variable request worker -> engine -> worker (GetVar, 300 calls): median %.3f ms, p95 %.3f ms, "
          "max %.3f ms" % (median, p95, top))
    # only catches a broken wait (for example one that waits for the 250 ms fallback timer), not a budget
    assert median < scaled(0.05) * 1000, (median, p95, top)
