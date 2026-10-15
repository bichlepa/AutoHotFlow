"""Helpers for the end-to-end tests of the core elements (WI-0052): small flows with a condition, run in one session.

    builders = [condition_flow("a", "Condition_Expression", Expression="1"), ...]
    runs = run_all(flows, builders)               # one start of the session for all flows, probes read at once
    assert [answer(r) for r in runs] == ["YES", ...]

The result of a condition is not an event, so a flow ends in two marker elements named YES and NO (`Action_Do_nothing`)
behind the connections yes and no, and the test reads the path. See doc/TEST-STRATEGY.md section 9 for the flow builder
and the runner.
"""

import json

from support.flowbuilder import FlowBuilder

MODES = [("strict", True), ("compat", None)]       # the type mode of the flow (E0034): strict, compatibility


def branch(fb, cond):
    """The markers YES and NO behind the connections yes and no of a condition."""
    fb.connect(cond, fb.action("Action_Do_nothing", name="YES"), "yes")
    fb.connect(cond, fb.action("Action_Do_nothing", name="NO"), "no")


def run_all(flows, builders, timeout=10):
    """Adds all flows first (one start of the session), then runs them in order. Returns the FlowRuns in that order.
    The probes of a flow are read at once (the next run clears them): `run.seen[name]` is the Probe of a variable."""
    ids = [flows.add(fb) for fb in builders]
    flows.start()
    runs = []
    for fb, flow_id in zip(builders, ids):
        run = flows.run(flow_id, timeout=timeout)
        run.seen = {name: run.probe(name, timeout=3) for name in fb.probed} if run.reason == "finished" else {}
        runs.append(run)
    return runs


def answer(run):
    """'YES', 'NO' or 'EXCEPTION' for a flow of condition_flow: the marker that ran last, or the exception."""
    if run.reason != "finished" or run.exceptions:
        return "EXCEPTION"
    return run.names[-1]


def setvar(name, value):
    return {"op": "set", "name": name, "value": value}


def condition_flow(name, cls, strict=True, setup=None, **pars):
    """trigger -> [Action_TestSetVar with the JSON steps `setup`] -> condition -> YES / NO."""
    fb = FlowBuilder(name, strict_types=strict)
    prev = fb.trigger()
    if setup:
        step = fb.action("Action_TestSetVar", Steps=json.dumps(setup))
        fb.connect(prev, step)
        prev = step
    cond = fb.condition(cls, **pars)
    fb.connect(prev, cond)
    branch(fb, cond)
    return fb
