"""WI-0129: the action Action_Set_element_parameter (REQ-ELM-250, E0001, E0065) in real sessions (supervisor, storage, engine
and, where a timer trigger has to be armed, the trigger host), with the flow builder.

The change is an edit of the flow: the own flow and another flow, a running element keeps its value while the next start
sees the new one, a changed trigger is armed again and fires with the new parameter, the file has the new value after the
automatic save, the standard name is generated again, and a missing flow, element or parameter ends the element with an
exception. Not covered here: an open editor showing the change (its display is the owner's manual check, PROTOCOL 4.11).
"""

import json
import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner, flows, read_var  # noqa: F401  (fixture flows)
from support.timing import scaled

HOST_ROLES = "storage,engine,triggerhost"
TIMER_INTERVAL = "100"
SAVE_WAIT_S = 15.0
PARAM_TEXT = "newParameterValueMultilineEdit/VarValue"
PARAM_EDIT_DURATION = "newParameterValueEdit/Duration"
PARAM_EDIT_INTERVAL = "newParameterValueEdit/Interval"


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well (a timer trigger has to be armed)."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def read_probe(flows_, flow_id=None):
    """The variable Probe as it is on disk (for a failure message)."""
    return read_var(flows_.datadir, "global_Probe", flow_id)


def element_step(run, name):
    """(state, message) of the last step of the element with this name, or None if it did not run."""
    found = [s for s in run.steps if s.name == name]
    return (found[-1].state, found[-1].message) if found else None


def setter(name, flow_id, element, parameter, value, this_flow=0):
    """Action_Set_element_parameter named `name` that changes `parameter` of `element` in the flow `flow_id`."""
    return dict(name=name, ThisFlow=this_flow, flowID=flow_id, elementID=element.id, parameterID=parameter
                , **{parameter.split("/")[0]: value})


def read_file_element(datadir, flow_id, element_id):
    """The element Map of the flow file as it is on disk, or None while the file cannot be read."""
    try:
        text = (datadir / "Flows" / (flow_id + ".json")).read_text(encoding="utf-8-sig")
        return json.loads(text)["allElements"].get(element_id)
    except (OSError, ValueError, KeyError):
        return None


def wait_file(datadir, flow_id, element_id, predicate):
    """Waits until the element of the flow file satisfies predicate (the automatic saving writes it a few seconds later)."""
    deadline = time.monotonic() + scaled(SAVE_WAIT_S)
    element = None
    while time.monotonic() < deadline:
        element = read_file_element(datadir, flow_id, element_id)
        if element is not None and predicate(element):
            return element
        time.sleep(0.1)
    raise AssertionError("the flow file of '%s' does not show the change: %r" % (flow_id, element))


def new_variable(name, value):
    """The pars of an Action_New_variable that writes the variable `name`; it has no name of its own, so its name is
    generated (StandardName)."""
    return dict(Varname=name, VarValue=value)


# --- the own flow ----------------------------------------------------------------------------------------------------------
def test_set_element_parameter_changes_an_element_of_the_own_flow_and_saves_it(flows, datadir):
    """trigger -> SET (changes NEW) -> NEW: NEW starts after the change, so it writes the new value. The standard name is
    generated again, and the file has the new value after the automatic save."""
    fb = FlowBuilder("own flow")
    new = fb.action("Action_New_variable", **new_variable("global_Probe", "old"))
    setter_handle = fb.action("Action_Set_element_parameter", **setter("SET", "", new, PARAM_TEXT, "changed", this_flow=1))
    fb.chain(fb.trigger(), setter_handle, new)
    flow_id = flows.add(fb)
    flows.start()

    run = flows.run(flow_id)
    assert run.reason == "finished", (run.reason, run.exceptions)
    assert element_step(run, "SET") == ("finished", ""), element_step(run, "SET")
    assert flows.wait_var("global_Probe", lambda pair: pair[1] == "changed") is not None, read_probe(flows)

    element = wait_file(datadir, flow_id, new.id, lambda el: el["pars"].get("VarValue") == "changed")
    assert "= changed" in element["name"], element["name"]


def test_set_element_parameter_with_an_unknown_element_ends_with_exception(flows):
    fb = FlowBuilder("own flow missing")
    fb.chain(fb.trigger(), fb.action("Action_Set_element_parameter", name="SET", ThisFlow=1, flowID="", elementID="element0000000099"
                                     , parameterID=PARAM_TEXT, newParameterValueMultilineEdit="x"))
    flow_id = flows.add(fb)
    flows.start()
    run = flows.run(flow_id)
    assert element_step(run, "SET")[0] == "exception", run.steps
    assert "does not have the element with ID 'element0000000099'" in element_step(run, "SET")[1]


# --- another flow ----------------------------------------------------------------------------------------------------------
def test_set_element_parameter_changes_an_element_of_another_flow(flows, datadir):
    """The target flow is not running; the next run of it writes the new value, and its file has it."""
    target = FlowBuilder("target")
    new = target.action("Action_New_variable", **new_variable("global_Probe", "old"))
    target.chain(target.trigger(), new)
    target_id = flows.add(target)

    caller = FlowBuilder("caller")
    caller.chain(caller.trigger(), caller.action("Action_Set_element_parameter"
                                                 , **setter("SET", target_id, new, PARAM_TEXT, "other flow")))
    caller_id = flows.add(caller)
    flows.start()

    caller_run = flows.run(caller_id)
    assert element_step(caller_run, "SET") == ("finished", ""), element_step(caller_run, "SET")

    target_run = flows.run(target_id)
    assert target_run.reason == "finished", (target_run.reason, target_run.exceptions)
    assert flows.wait_var("global_Probe", lambda pair: pair[1] == "other flow") is not None
    wait_file(datadir, target_id, new.id, lambda el: el["pars"].get("VarValue") == "other flow")


# --- running elements --------------------------------------------------------------------------------------------------------
def test_a_running_element_keeps_its_value_and_the_next_start_sees_the_new_one(flows, datadir):
    """target: trigger -> SLEEP (1.5 s) -> NEW. While SLEEP runs, another flow sets the Duration of SLEEP to 0 (the running
    element keeps its 1.5 s) and the value of NEW (not started yet: it writes the new value)."""
    target = FlowBuilder("sleeping")
    sleep = target.action("Action_Sleep", name="SLEEP", Duration="1500", Unit="Milliseconds")
    new = target.action("Action_New_variable", **new_variable("global_Probe", "old"))
    target.chain(target.trigger(), sleep, new)
    target_id = flows.add(target)

    caller = FlowBuilder("caller of the sleep")
    set_sleep = caller.action("Action_Set_element_parameter", **setter("SET_SLEEP", target_id, sleep, PARAM_EDIT_DURATION, "0"))
    set_new = caller.action("Action_Set_element_parameter", **setter("SET_NEW", target_id, new, PARAM_TEXT, "new value"))
    caller.chain(caller.trigger(), set_sleep, set_new)
    caller_id = flows.add(caller)
    flows.start()

    started = time.monotonic()
    target_run = flows.begin(target_id)
    time.sleep(0.5)                       # the target is inside its sleep now
    caller_run = flows.run(caller_id)
    assert element_step(caller_run, "SET_SLEEP") == ("finished", ""), element_step(caller_run, "SET_SLEEP")
    assert element_step(caller_run, "SET_NEW") == ("finished", ""), element_step(caller_run, "SET_NEW")
    flows.wait(target_run)
    elapsed = time.monotonic() - started
    assert target_run.reason == "finished", (target_run.reason, target_run.exceptions)
    assert elapsed >= scaled(1.2), "the running sleep kept its old duration of 1.5 s, the run took %.2f s" % elapsed
    assert flows.wait_var("global_Probe", lambda pair: pair[1] == "new value") is not None


# --- triggers ---------------------------------------------------------------------------------------------------------------
def test_a_changed_timer_trigger_fires_with_the_new_interval(host_flows, datadir):
    """A test timer that fires every 100 ms; the caller sets its Interval to 1000 ms. Its next fires are one second apart."""
    flows = host_flows
    timer = FlowBuilder("timer")
    trigger = timer.trigger("Test.Trigger_TestTimer", Interval=TIMER_INTERVAL)
    timer.chain(trigger, timer.action("Action_Do_nothing", name="TICK"))
    timer_id = flows.add(timer)

    caller = FlowBuilder("interval caller")
    caller.chain(caller.trigger(), caller.action("Action_Set_element_parameter"
                                                 , **setter("SET", timer_id, trigger, PARAM_EDIT_INTERVAL, "1000")))
    caller_id = flows.add(caller)
    flows.start()
    flows.enable(timer_id)

    mark = flows.mark()
    fast = flows.ended(timer_id, since=mark, count=3, timeout=10)
    assert len(fast) >= 3, fast

    caller_run = flows.run(caller_id)
    assert element_step(caller_run, "SET") == ("finished", ""), element_step(caller_run, "SET")
    mark = flows.mark()
    started = time.monotonic()
    slow = flows.ended(timer_id, since=mark, count=2, timeout=20)
    assert len(slow) >= 2, slow
    assert time.monotonic() - started >= scaled(1.5), "the changed trigger did not fire at 1000 ms intervals"
    wait_file(datadir, timer_id, trigger.id, lambda el: el["pars"].get("Interval") == "1000")


# --- the value and the errors ----------------------------------------------------------------------------------------------
@pytest.mark.parametrize("flow_id_value, element_value, parameter, expected", [
    ("no such flow", None, PARAM_TEXT, "Flow 'no such flow' does not exist"),
    ("", "element0000000099", PARAM_TEXT, "does not have the element with ID 'element0000000099'"),
    ("", None, "newParameterValueMultilineEdit/NoSuchParameter", "parameter 'NoSuchParameter' is invalid"),
])
def test_set_element_parameter_missing_flow_element_or_parameter_is_an_exception(flows, flow_id_value, element_value,
                                                                                  parameter, expected):
    target = FlowBuilder("target of the error")
    new = target.action("Action_New_variable", **new_variable("global_Probe", "old"))
    target.chain(target.trigger(), new)
    target_id = flows.add(target)
    caller = FlowBuilder("caller of the error")
    pars = dict(name="SET", ThisFlow=0, flowID=flow_id_value or target_id, parameterID=parameter
                , newParameterValueMultilineEdit="x")
    pars["elementID"] = element_value or new.id
    caller.chain(caller.trigger(), caller.action("Action_Set_element_parameter", **pars))
    caller_id = flows.add(caller)
    flows.start()
    run = flows.run(caller_id)
    state, message = element_step(run, "SET")
    assert state == "exception", (state, message)
    assert expected in message, message
