"""WI-0052: end-to-end tests of Action_Trace_Point and Action_Trace_Point_Check with the flow builder (the other core set A
elements are in test_core_a_elements.py).

A trace point appends "<ID> (<element ID>)" to the hidden instance variable passed_Tracepoints; the check reads it.
"""

import json

import pytest

from support.coreflows import run_all, setvar
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def tp(fb, tid, **pars):
    return fb.action("Action_Trace_Point", ID=tid, LogMessage=pars.pop("LogMessage", ""),
                     StopCondition=pars.pop("StopCondition", ""), name="TP " + tid, **pars)


def label(handle):
    """The name of a trace point in the lists of Action_Trace_Point_Check: '<ID> (<element ID>)'."""
    return "%s (%s)" % (handle.name[3:], handle.id)


def check(fb, **pars):
    pars.setdefault("MustPassTracepointsAll", 0)
    pars.setdefault("MustNotPassTracepointsAll", 0)
    pars.setdefault("MustPassTracepoints", [])
    pars.setdefault("MustNotPassTracepoints", [])
    return fb.action("Action_Trace_Point_Check", name="CHECK", **pars)


def tracepoint_flow(name, scenario):
    """trigger -> passes tp a and b -> CHECK (parameters from `scenario(fb, a, b, c)`) -> OK. The trace point c is on the
    branch that the flow does not take (a condition that is false), so it exists in the flow and is never passed."""
    fb = FlowBuilder(name)
    a, b, c = tp(fb, "a"), tp(fb, "b"), tp(fb, "c")
    never = fb.condition("Condition_Do_nothing", executionResult="No")
    chk = scenario(fb, a, b, c)
    ok = fb.action("Action_Do_nothing", name="OK")
    caught = fb.action("Action_Do_nothing", name="CAUGHT")
    fb.chain(fb.trigger(), a, b, never)
    fb.connect(never, c, "yes")
    fb.connect(never, chk, "no")
    fb.connect(chk, ok)
    fb.connect(chk, caught, "exception")
    return fb


def check_with(**make):
    """A scenario with the parameters of the check as functions of the handles (a, b, c)."""
    def scenario(fb, a, b, c):
        return check(fb, **{k: (v(a, b, c) if callable(v) else v) for k, v in make.items()})
    return scenario


TRACE_CASES = [
    # name, scenario, outcome, text in the message
    ("pass-selected", check_with(MustPassTracepoints=lambda a, b, c: [label(a), label(b)]), "OK", None),
    ("pass-missing", check_with(MustPassTracepoints=lambda a, b, c: [label(a), label(c)]), "CAUGHT",
     lambda a, b, c: "1 tracepoints were not passed which must have been passed: " + label(c) + "."),
    ("pass-all-but", check_with(MustPassTracepointsAll=1, MustNotPassTracepoints=lambda a, b, c: [label(c)]), "OK", None),
    ("pass-all", check_with(MustPassTracepointsAll=1), "CAUGHT",
     lambda a, b, c: "1 tracepoints were not passed which must have been passed: " + label(c) + "."),
    ("not-pass-selected", check_with(MustNotPassTracepoints=lambda a, b, c: [label(c)]), "OK", None),
    ("not-pass-passed", check_with(MustNotPassTracepoints=lambda a, b, c: [label(b), label(c)]), "CAUGHT",
     lambda a, b, c: "1 tracepoints were passed which must not have been passed: " + label(b) + "."),
    ("not-pass-all", check_with(MustNotPassTracepointsAll=1), "CAUGHT",
     lambda a, b, c: "2 tracepoints were passed which must not have been passed: %s, %s." % (label(a), label(b))),
    ("not-pass-all-but", check_with(MustNotPassTracepointsAll=1, MustPassTracepoints=lambda a, b, c: [label(a), label(b)]),
     "OK", None),
    ("both-messages", check_with(MustPassTracepoints=lambda a, b, c: [label(c)],
                                 MustNotPassTracepoints=lambda a, b, c: [label(a)]), "CAUGHT",
     lambda a, b, c: "1 tracepoints were not passed which must have been passed: %s. 1 tracepoints were passed which must "
                     "not have been passed: %s." % (label(c), label(a))),
    ("nothing-selected", check_with(), "OK", None),
    ("v1-empty-lists", check_with(MustPassTracepoints={}, MustNotPassTracepoints={}), "OK", None),
    ("unknown-name", check_with(MustPassTracepoints=["never existed (element9999)"]), "CAUGHT",
     lambda a, b, c: "1 tracepoints were not passed which must have been passed: never existed (element9999)."),
    ("case-insensitive", check_with(MustPassTracepoints=lambda a, b, c: [label(a).upper()]), "OK", None),
    ("both-all", check_with(MustPassTracepointsAll=1, MustNotPassTracepointsAll=1), "CAUGHT",
     lambda a, b, c: "Both 'All trace points' options are set; they exclude each other."),
]


@pytest.mark.slow
def test_trace_point_check_every_option(flows):
    builders = [tracepoint_flow("tp-" + name, scenario) for name, scenario, *_ in TRACE_CASES]
    for (name, scenario, outcome, text), fb, run in zip(TRACE_CASES, builders, run_all(flows, builders)):
        assert run.reason == "finished", (name, run.reason, run.exceptions)
        assert run.names[-1] == outcome, (name, run.names, run.exceptions)
        # the trace points ran in order, the one behind the false condition did not
        assert [n for n in run.names if n.startswith("TP ")] == ["TP a", "TP b"], name
        if text is None:
            assert not run.exceptions, (name, run.exceptions)
        else:
            handles = [h for h in fb.handles.values() if h.name.startswith("TP ")]
            expected = text(*handles)
            assert run.exceptions == [expected], (name, run.exceptions, expected)


def test_trace_points_belong_to_the_instance_and_are_hidden(flows):
    fb = FlowBuilder("tp-instance")
    first = check(fb, MustNotPassTracepointsAll=1)        # nothing may have been passed yet, in every instance
    point = tp(fb, "p")
    last = check(fb, MustPassTracepointsAll=1)
    fb.chain(fb.trigger(), first, point, fb.probe("passed_Tracepoints"), last)
    flows.add(fb)
    flows.start()
    for _ in range(2):                                  # the second instance does not see the trace points of the first
        run = flows.run("tp-instance")
        assert run.reason == "finished" and not run.exceptions, run.exceptions
        assert run.names[-1] == "CHECK"
        assert run.probe("passed_Tracepoints").location == "<missing>"   # hidden: no expression or %var% reaches it


def test_trace_point_log_message_and_stop_condition(flows):
    builders = []
    # 0: the log message with a variable; the stop condition is false
    fb = FlowBuilder("tp-log")
    log_tp = tp(fb, "logged", LogMessage="x is %x%", StopCondition="x = 99")
    fb.chain(fb.trigger(), fb.action("Action_TestSetVar", Steps=json.dumps([setvar("x", 5)])), log_tp,
             fb.action("Action_Do_nothing", name="AFTER"))
    builders.append(fb)
    # 1: the stop condition is true: the element ends with exception, the instance with all its threads is stopped, also
    # the element behind the exception connection
    fb = FlowBuilder("tp-stop")
    stop_tp = tp(fb, "stopper", StopCondition="x = 5")
    fb.chain(fb.trigger(), fb.action("Action_TestSetVar", Steps=json.dumps([setvar("x", 5)])), stop_tp)
    fb.connect(stop_tp, fb.action("Action_Do_nothing", name="AFTER-EXCEPTION"), "exception")
    fb.connect(stop_tp, fb.action("Action_Do_nothing", name="AFTER"))
    builders.append(fb)
    # 2: the same without a connection for the exception
    fb = FlowBuilder("tp-stop-unhandled")
    fb.chain(fb.trigger(), tp(fb, "stopper", StopCondition="1"), fb.action("Action_Do_nothing", name="AFTER"))
    builders.append(fb)
    # 3: a stop condition that is not readable
    fb = FlowBuilder("tp-stop-error")
    fb.chain(fb.trigger(), tp(fb, "stopper", StopCondition="1 +"), fb.action("Action_Do_nothing", name="AFTER"))
    builders.append(fb)
    # 4: a text that is a number with the value 0 and the empty text do not stop
    fb = FlowBuilder("tp-stop-falsy")
    fb.chain(fb.trigger(), tp(fb, "zero", StopCondition='"0"'), tp(fb, "empty", StopCondition='""'),
             fb.action("Action_Do_nothing", name="AFTER"))
    builders.append(fb)
    logged, stopped, unhandled, unreadable, falsy = run_all(flows, builders)

    assert logged.reason == "finished" and logged.names[-1] == "AFTER"
    assert any(e["level"] == "f0" and e["text"] == "x is 5" for e in logged.log), logged.log

    assert stopped.reason == "element.stop"
    assert "AFTER" not in stopped.names and "AFTER-EXCEPTION" not in stopped.names
    assert stopped.state_of("TP stopper") == ["exception"]
    assert stopped.exceptions == ["Stopping execution because stop Condition 'x = 5' is not false"]

    assert unhandled.reason in ("exception", "element.stop") and "AFTER" not in unhandled.names
    assert unhandled.exceptions == ["Stopping execution because stop Condition '1' is not false"]

    assert unreadable.reason == "exception" and "AFTER" not in unreadable.names
    assert "An error occured while parsing expression '1 +'" in unreadable.exceptions[0]

    assert falsy.reason == "finished" and falsy.names[-1] == "AFTER" and not falsy.exceptions


def test_trace_point_stops_every_thread_of_the_instance(flows):
    """Two branches from the trigger: one stops the instance at once, the other waits for 10 s and would add a marker."""
    fb = FlowBuilder("tp-stop-threads")
    trigger = fb.trigger()
    wait = fb.action("Action_Sleep", Duration=10, Unit="Seconds")
    fb.connect(trigger, wait)
    fb.connect(wait, fb.action("Action_Do_nothing", name="LATE"))
    fb.connect(trigger, tp(fb, "stopper", StopCondition="1"))
    run, = run_all(flows, [fb], timeout=5)
    assert run.reason in ("element.stop", "exception") and "LATE" not in run.names
    assert run.state_of("Action_Sleep") in (["running"], ["finished"], [])
