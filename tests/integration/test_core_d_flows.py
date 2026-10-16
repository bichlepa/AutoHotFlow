"""WI-0055: end-to-end tests of the core set D, flow control: Action_Execute_Flow, Action_Stop_Flow and
Condition_Flow_Running, with the flow builder in real sessions (supervisor, storage, engine).

The called flows are enabled after the start of the session: the help of Execute_Flow says that the trigger must be
enabled, and until S0003 a trigger is enabled when its flow is (`flows.enable`). What a called instance did comes back
through its variables (ReturnVariables and a probe in the caller) or through its `evt.instance.ended` (`flows.ended`).
The engine functions behind the elements, and more variants of the cases, are in tests/ahk/engine_call_flow.test.ahk.
"""

import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.timing import scaled

SLEEP_MS = 1500


# --- builders --------------------------------------------------------------------------------------------------------
def exec_pars(target="", trigger="", wait=0, send=1, ret=0, skip=0, which=None):
    """The parameters of Action_Execute_Flow. target "" = this flow, trigger "" = the default trigger (`which` sets
    WhichTrigger whatever the trigger)."""
    return dict(ThisFlow=0 if target else 1, flowID=target,
                WhichTrigger=which or ("Specified" if trigger else "Default"), triggerID=trigger, SendLocalVars=send,
                WaitToFinish=wait, ReturnVariables=ret, SkipDisabled=skip)


def caller(name, target, probe=("y",), setup_x=True, **pars):
    """trigger -> [x := 1] -> Execute_Flow(target) -> probe -> AFTER"""
    fb = FlowBuilder(name)
    prev = fb.trigger()
    if setup_x:
        prev = fb.chain(prev, fb.action("Action_New_variable", Varname="x", VarValue="1", expression="Expression"))
    ex = fb.action("Action_Execute_Flow", name="EXEC", **exec_pars(target, **pars))
    fb.chain(prev, ex)
    after = fb.action("Action_Do_nothing", name="AFTER")
    if probe:
        fb.chain(ex, fb.probe(*probe), after)
    else:
        fb.chain(ex, after)
    return fb


def callee(name):
    """trigger -> y := x + 1 -> x := 10"""
    fb = FlowBuilder(name)
    fb.chain(fb.trigger(), fb.action("Action_New_variable", Varname="y", VarValue="x + 1", expression="Expression"),
             fb.action("Action_New_variable", Varname="x", VarValue="10", expression="Expression"))
    return fb


def sleeper(name, ms=SLEEP_MS, policy="default"):
    """trigger -> Sleep(ms) -> DONE"""
    fb = FlowBuilder(name, execution_policy=policy)
    fb.chain(fb.trigger(), fb.action("Action_Sleep", Duration=ms, Unit="Milliseconds"),
             fb.action("Action_Do_nothing", name="DONE"))
    return fb


def one_element(name, cls, **pars):
    """trigger -> <cls>"""
    fb = FlowBuilder(name)
    fb.chain(fb.trigger(), fb.action(cls, **pars))
    return fb


def self_caller(name, policy, wait):
    """A flow that calls itself through its second manual trigger "rec" (the pattern of the v1 test flows):
    start: depth := 0 -> E0 (calls rec) -> AFTER0
    rec:   depth >= 3? yes -> DONE; no -> depth := depth + 1 -> E (calls rec) -> AFTER"""
    fb = FlowBuilder(name, execution_policy=policy)
    start = fb.trigger(name="start")
    rec = fb.trigger(name="rec")
    zero = fb.action("Action_New_variable", Varname="depth", VarValue="0", expression="Expression")
    e0 = fb.action("Action_Execute_Flow", name="E0", **exec_pars("", rec.id, wait))
    fb.chain(start, zero, e0, fb.action("Action_Do_nothing", name="AFTER0"))
    cond = fb.condition("Condition_Expression", Expression="depth >= 3")
    fb.connect(rec, cond)
    fb.connect(cond, fb.action("Action_Do_nothing", name="DONE"), "yes")
    inc = fb.action("Action_New_variable", Varname="depth", VarValue="depth + 1", expression="Expression")
    e = fb.action("Action_Execute_Flow", name="E", **exec_pars("", rec.id, wait))
    fb.connect(cond, inc, "no")
    fb.chain(inc, e, fb.action("Action_Do_nothing", name="AFTER"))
    return fb, start


def exec_message(run):
    """The message of the exception of the element EXEC (or E0), or ''."""
    for s in run.steps:
        if s.name in ("EXEC", "E0") and s.state == "exception":
            return s.message
    return ""


def finished(run):
    assert run.reason == "finished", (run.reason, run.exceptions)
    assert not run.exceptions, run.exceptions
    assert run.names[-1] == "AFTER", run.names


def session(flows, builders, enable=None):
    """Adds the flows, starts the session, enables the flows (default: all). Returns the flow IDs."""
    ids = [flows.add(fb) for fb in builders]
    flows.start()
    flows.enable(*(ids if enable is None else enable))
    return ids


# --- waiting, variables, a third flow ---------------------------------------------------------------------------------
def test_execute_flow_waits_sends_and_returns_the_variables(flows):
    session(flows, [callee("callee"), caller("wait-ret", "callee", wait=1, ret=1, probe=("x", "y")),
                    caller("wait-noret", "callee", wait=1), caller("nowait", "callee", wait=0),
                    caller("nosend", "callee", wait=1, send=0)])
    run = flows.run("wait-ret")
    finished(run)
    assert run.probe("y").text == "2" and run.probe("x").text == "10", "y came back, x was overwritten"
    run = flows.run("wait-noret")
    finished(run)
    assert run.probe("y").type == "<missing>", "nothing comes back without ReturnVariables"
    mark = flows.mark()
    run = flows.run("nowait")
    finished(run)
    assert [e["reason"] for e in flows.ended("callee", mark)] == ["finished"], "the called flow ran"
    run = flows.run("nosend")
    assert run.reason == "exception"
    assert exec_message(run).startswith("The called flow 'callee' ended with an exception: element "), exec_message(run)


def test_a_third_flow_runs_while_an_element_waits_for_another_flow(flows):
    session(flows, [sleeper("slow"), caller("waits", "slow", wait=1, probe=()),
                    one_element("third", "Action_Do_nothing")])
    started = time.monotonic()
    waiting = flows.begin("waits")
    third = flows.run("third", timeout=3)
    assert third.reason == "finished"
    assert time.monotonic() - started < scaled(SLEEP_MS / 1000.0), "the third flow did not wait for the sleeper"
    assert flows.executing("waits"), "the caller still waits"
    run = flows.wait(waiting)
    finished(run)
    assert time.monotonic() - started >= SLEEP_MS / 1000.0


def test_default_trigger_and_specified_trigger_and_their_errors(flows):
    two = FlowBuilder("two-triggers")
    t1 = two.trigger(name="first")                              # the default trigger (the first one of the builder)
    t2 = two.trigger(name="second")
    two.connect(t1, two.action("Action_New_variable", Varname="y", VarValue="first"))
    two.connect(t2, two.action("Action_New_variable", Varname="y", VarValue="second"))
    session(flows, [two, caller("by-default", "two-triggers", wait=1, ret=1),
                    caller("by-id", "two-triggers", trigger=t2.id, wait=1, ret=1),
                    caller("bad-id", "two-triggers", trigger="element9999999999", wait=1),
                    caller("no-id", "two-triggers", trigger="", wait=1, which="Specified")])
    assert flows.run("by-default").probe("y").text == "first"
    assert flows.run("by-id").probe("y").text == "second"
    run = flows.run("bad-id")
    assert exec_message(run) == "Flow 'two-triggers' does not have the trigger with ID 'element9999999999'."
    run = flows.run("no-id")
    assert exec_message(run) == "Trigger ID is empty"


# --- disabled, missing, exception, missing package ---------------------------------------------------------------------
def test_disabled_and_missing_flows(flows):
    disabled = callee("disabled")
    trigger_id = next(h.id for h in disabled.handles.values() if h.kind == "trigger")
    session(flows, [disabled, caller("to-disabled", "disabled", wait=1),
                    caller("skip-disabled", "disabled", wait=1, skip=1),
                    caller("to-missing", "Flow 1999999999", wait=1)],
            enable=["to-disabled", "skip-disabled", "to-missing"])
    mark = flows.mark()
    run = flows.run("to-disabled")
    assert run.reason == "exception"
    assert exec_message(run) == "Trigger '%s' in 'disabled' is disabled" % trigger_id
    finished(flows.run("skip-disabled"))
    assert flows.ended("disabled", mark, timeout=0.5) == [], "the disabled flow did not start"
    run = flows.run("to-missing")                                # the flowID of a flow that was deleted
    assert exec_message(run) == "Flow 'Flow 1999999999' does not exist"


def test_the_called_flow_ends_with_an_exception_or_has_an_element_of_a_missing_package(flows):
    session(flows, [one_element("throws", "Action_TestThrow"), one_element("no-package", "Nope.Action_Gone"),
                    caller("to-throws", "throws", wait=1), caller("to-no-package", "no-package", wait=1),
                    caller("to-throws-nowait", "throws", wait=0)])
    run = flows.run("to-throws")
    assert run.reason == "exception"
    assert exec_message(run).startswith("The called flow 'throws' ended with an exception: element 'element")
    assert exec_message(run).endswith("': test"), exec_message(run)
    run = flows.run("to-no-package")                              # E0047: the called instance ends with exception
    assert exec_message(run).endswith("element class 'Nope.Action_Gone' is not available: package 'Nope' is not "
                                      "installed"), exec_message(run)
    finished(flows.run("to-throws-nowait"))                       # without waiting the caller does not see it


# --- stops while waiting -------------------------------------------------------------------------------------------------
def test_the_called_flow_is_stopped_while_the_caller_waits(flows):
    session(flows, [sleeper("slow-a"), caller("waits-a", "slow-a", wait=1, probe=())])
    waiting = flows.begin("waits-a")
    assert _wait(lambda: flows.executing("slow-a")), "the called flow did not start"
    flows.request_ok("engine", "cmd.flow.stop", {"flowId": "slow-a"})
    run = flows.wait(waiting, timeout=3)
    assert run.reason == "exception"
    assert exec_message(run) == "The called flow 'slow-a' was stopped (flow.stop)."


@pytest.mark.slow
def test_the_caller_is_stopped_while_it_waits_and_the_called_flow_runs_on(flows):
    session(flows, [sleeper("slow-b"), caller("waits-b", "slow-b", wait=1, probe=())])
    mark = flows.mark()
    waiting = flows.begin("waits-b")
    assert _wait(lambda: flows.executing("slow-b")), "the called flow did not start"
    flows.request_ok("engine", "cmd.flow.stop", {"flowId": "waits-b"})
    run = flows.wait(waiting, timeout=3)
    assert run.reason == "flow.stop"
    ends = flows.ended("slow-b", mark, timeout=SLEEP_MS / 1000.0 + 5)
    assert [e["reason"] for e in ends] == ["finished"], "the called flow ran to its end"


# --- a flow that calls itself ----------------------------------------------------------------------------------------------
SELF_CASES = [
    # name, policy, wait, the reasons of the instances in the order they ended (start, then rec 1 to 4)
    ("self-parallel-nowait", "parallel", 0, ["finished"] * 5),
    ("self-parallel-wait", "default", 1, ["finished"] * 5),
    ("self-wait-nowait", "wait", 0, ["finished"] * 5),
    ("self-wait-wait", "wait", 1, ["exception"]),
    ("self-skip-nowait", "skip", 0, ["exception"]),
    ("self-skip-wait", "skip", 1, ["exception"]),
    ("self-stop-nowait", "stop", 0, ["policy stop"] * 4 + ["finished"]),
    ("self-stop-wait", "stop", 1, ["policy stop"] * 4 + ["finished"]),
]


@pytest.mark.slow
def test_a_flow_calls_itself_with_and_without_waiting_under_every_policy(flows):
    builders = {}
    for name, policy, wait, _ in SELF_CASES:
        builders[name] = self_caller(name, policy, wait)
    session(flows, [fb for fb, _ in builders.values()])
    for name, policy, wait, want in SELF_CASES:
        fb, start = builders[name]
        mark = flows.mark()
        run = flows.run(name, trigger=start.id)
        got = [e["reason"] for e in flows.ended(name, mark, count=len(want), timeout=5)]
        assert got == want, (name, got, run.exceptions)
        if name == "self-wait-wait":
            assert "its execution policy is wait and one of its instances waits for the calling element" \
                in exec_message(run), exec_message(run)
        if name.startswith("self-skip"):
            assert "is running and its execution policy is skip" in exec_message(run), exec_message(run)


def test_waiting_calls_of_a_flow_to_itself_are_limited(flows):
    fb = FlowBuilder("endless")
    t = fb.trigger()
    fb.chain(t, fb.action("Action_Execute_Flow", name="E0", **exec_pars("", t.id, wait=1)))
    session(flows, [fb])
    mark = flows.mark()
    run = flows.run("endless", timeout=30)
    assert run.reason == "exception"
    ends = flows.ended("endless", mark, count=101, timeout=10)
    assert len(ends) == 101 and {e["reason"] for e in ends} == {"exception"}
    assert any("100 calls that wait for each other are the limit" in e["text"] for e in run.log), \
        [e["text"] for e in run.log][:5]


# --- Condition_Flow_Running and Action_Stop_Flow ------------------------------------------------------------------------------
def running_check(name, target):
    fb = FlowBuilder(name)
    cond = fb.condition("Condition_Flow_Running", flowID=target)
    fb.connect(fb.trigger(), cond)
    fb.connect(cond, fb.action("Action_Do_nothing", name="YES"), "yes")
    fb.connect(cond, fb.action("Action_Do_nothing", name="NO"), "no")
    return fb


@pytest.mark.slow
def test_flow_running_sees_running_and_queued_instances(flows):
    session(flows, [sleeper("queue", ms=800, policy="wait"), running_check("is-running", "queue"),
                    running_check("is-self", "is-self"), running_check("is-missing", "Flow 1999999999")])
    assert flows.run("is-running").names[-1] == "NO"
    assert flows.run("is-self").names[-1] == "YES", "the own flow is executing"
    run = flows.run("is-missing")
    assert run.reason == "exception" and run.exceptions == ["Flow 'Flow 1999999999' does not exist"]
    mark = flows.mark()
    first = flows.begin("queue")
    second = flows.request_ok("engine", "cmd.flow.start", {"flowId": "queue"})
    assert second.get("waiting") is True
    assert flows.run("is-running").names[-1] == "YES"
    flows.wait(first)
    assert flows.run("is-running").names[-1] == "YES", "the queued instance runs now"
    assert [e["reason"] for e in flows.ended("queue", mark, count=2, timeout=5)] == ["finished", "finished"]
    assert flows.run("is-running").names[-1] == "NO"


def test_stop_flow_stops_running_and_queued_instances_and_its_own_flow(flows):
    stopper = FlowBuilder("stopper")
    stopper.chain(stopper.trigger(), stopper.action("Action_Stop_Flow", flowID="victim"),
                  stopper.action("Action_Do_nothing", name="AFTER"))
    own = FlowBuilder("stops-itself")
    own.chain(own.trigger(), own.action("Action_Stop_Flow", flowID="stops-itself"),
              own.action("Action_Do_nothing", name="AFTER"))
    session(flows, [sleeper("victim", ms=5000, policy="wait"), stopper, own,
                    one_element("stops-missing", "Action_Stop_Flow", flowID="Flow 1999999999")])
    mark = flows.mark()
    flows.begin("victim")
    assert flows.request_ok("engine", "cmd.flow.start", {"flowId": "victim"}).get("waiting") is True
    finished(flows.run("stopper"))
    ends = flows.ended("victim", mark, count=2, timeout=3)
    assert [e["reason"] for e in ends] == ["element.stopflow", "element.stopflow"]
    run = flows.run("stops-itself")
    assert run.reason == "element.stopflow"
    assert "AFTER" not in run.names
    run = flows.run("stops-missing")
    assert run.exceptions == ["Flow 'Flow 1999999999' does not exist"]


def _wait(predicate, timeout=5.0):
    end = time.monotonic() + scaled(timeout)
    while time.monotonic() < end:
        if predicate():
            return True
        time.sleep(0.05)
    return False
