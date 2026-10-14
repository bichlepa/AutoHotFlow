"""WI-49: the flow builder and the headless flow runner against a real session (supervisor, storage, engine).

Only the skeleton elements exist so far, so the flows use `Action_TestSetVar` (set, probe), `Action_Sleep`,
`Action_Do_nothing` and `Action_TestThrow`. Condition and loop elements come with WI-52 and later; the builder already
writes their connections, and the engine loads such a flow (second test).
"""

import json

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.flowrun import Probe, read_var, var_value

SET_X = '[{"op":"set","name":"x","value":7}]'


def test_a_flow_runs_headless_and_shows_its_path_and_variables(flows):
    fb = FlowBuilder("path")
    fb.chain(fb.trigger(), fb.action("Action_TestSetVar", Steps=SET_X), fb.probe("x"), fb.action("Action_Do_nothing"))
    run = flows.run(fb)
    assert run.reason == "finished"
    assert run.names == ["Trigger_Manual", "Action_TestSetVar", "Probe x", "Action_Do_nothing"]
    assert [s.state for s in run.steps] == ["finished"] * 4
    assert run.probe("x") == Probe("7", "Integer", "instance")


@pytest.mark.slow
def test_an_exception_takes_the_exception_connection(flows):
    fb = FlowBuilder("exc")
    els = fb.linear("Trigger_Manual -> Action_TestThrow exception-> Action_Do_nothing")
    run = flows.run(fb)
    assert run.reason == "finished" and run.path == [e.id for e in els]
    assert run.state_of(els[1]) == ["exception"] and run.exceptions == ["test"]


@pytest.mark.slow
def test_the_engine_loads_the_flow_of_the_builder_unchanged_with_a_condition_and_a_loop(flows):
    fb = FlowBuilder("shape", strict_types=True)
    t, loop = fb.trigger(), fb.loop("Loop_SimpleLoop", repeatCount=2)
    cond, body = fb.condition("Condition_Expression", Expression="x = 1"), fb.action("Action_Do_nothing")
    fb.connect(t, loop)
    fb.connect(loop, body, "head")
    fb.connect(body, cond)
    fb.connect(cond, loop, "yes", into="break")
    fb.connect(cond, loop, "no", into="tail")
    flows.add(fb)
    flows.start()
    sent = fb.to_dict()
    got = flows.request_ok("engine", "cmd.flow.get", {"flowId": "shape"})["definition"]
    assert got["flowSettings"]["strictTypes"] in (True, 1)      # the engine sends 1 (F-364*)
    for key in ("allElements", "allConnections"):
        assert json.loads(json.dumps(got[key])) == sent[key], key      # ids, classes, parts and parameter types


@pytest.mark.slow
def test_variables_are_preset_and_read_through_the_data_folder(flows):
    flows.preset_var("global_in", "from the test")
    fb = FlowBuilder("vars")
    steps = json.dumps([{"op": "probe", "name": "global_in"}, {"op": "set", "name": "global_out", "value": "back"},
                        {"op": "probe", "name": "static_table"}])
    fb.chain(fb.trigger(), fb.action("Action_TestSetVar", Steps=steps))
    flows.preset_var("static_table", {"a": [1, 2]}, flow_id="vars")
    run = flows.run(fb)
    assert run.reason == "finished"
    assert run.probe("global_in").text == "from the test"
    assert json.loads(run.probe("static_table").text) == {"a": [1, 2]} and run.probe("static_table").type == "Map"
    assert flows.wait_var("global_out", lambda p: p[1] == "back") == ("normal", "back")
    assert var_value(read_var(flows.datadir, "global_out")) == "back"
