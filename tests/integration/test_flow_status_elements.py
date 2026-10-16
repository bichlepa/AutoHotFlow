"""WI-0065: the elements Action_Set_Flow_Status and Condition_Flow_Enabled (decision E0056, REQ-ELM-250, REQ-TRG-050) in real
sessions (supervisor, storage, engine, and the trigger host where a timer trigger has to be armed), with the flow builder.

Every choice of both elements is run for another flow and for the flow of the element, with triggers that switch with the
flow and triggers of their own. The state is read from the engine (`cmd.engine.snapshot`), what an element did from its
steps (names, states, messages) and its log. The engine functions behind the elements are in tests/ahk/.
"""

import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner, flows  # noqa: F401  (fixture)
from support.timing import scaled

HOST_ROLES = "storage,engine,triggerhost"
TIMER_INTERVAL = "200"
WAIT_S = 10.0


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well (a timer trigger must be armed)."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


# --- builders --------------------------------------------------------------------------------------------------------
def target_flow(name):
    """FOLLOW (manual, switches with the flow, the default trigger) -> FOLLOW_DONE; OWN (manual, its own state) ->
    OWN_DONE. Returns the builder and the two trigger handles."""
    fb = FlowBuilder(name)
    follow = fb.trigger(name="FOLLOW")
    own = fb.element("Trigger_Manual", "trigger", name="OWN", extra={"followsFlow": False})
    fb.chain(follow, fb.action("Action_Do_nothing", name="FOLLOW_DONE"))
    fb.chain(own, fb.action("Action_Do_nothing", name="OWN_DONE"))
    return fb, follow, own


def set_pars(enable, which, target="target", trigger="", this_flow=0):
    return dict(Enable=enable, ThisFlow=this_flow, flowID=target, WhichTrigger=which, triggerID=trigger)


def cond_pars(which, target="target", trigger="", this_flow=0):
    return dict(ThisFlow=this_flow, flowID=target, WhichTrigger=which, triggerID=trigger)


def set_caller(name, pars):
    """trigger -> SET (Action_Set_Flow_Status with pars) -> DONE"""
    fb = FlowBuilder(name)
    fb.chain(fb.trigger(), fb.action("Action_Set_Flow_Status", name="SET", **pars), fb.action("Action_Do_nothing", name="DONE"))
    return fb


def cond_caller(name, pars):
    """trigger -> COND (Condition_Flow_Enabled with pars) -> yes: YES | no: NO"""
    fb = FlowBuilder(name)
    cond = fb.condition("Condition_Flow_Enabled", name="COND", **pars)
    fb.chain(fb.trigger(), cond)
    fb.connect(cond, fb.action("Action_Do_nothing", name="YES"), "yes")
    fb.connect(cond, fb.action("Action_Do_nothing", name="NO"), "no")
    return fb


def timer_flow(name):
    """A flow whose only trigger is the test timer (WI-0061), which switches with the flow. Returns the builder and the
    trigger handle."""
    fb = FlowBuilder(name)
    timer = fb.trigger("Test.Trigger_TestTimer", Interval=TIMER_INTERVAL)
    fb.chain(timer, fb.action("Action_Do_nothing", name="TICK"))
    return fb, timer


# --- reading the state -------------------------------------------------------------------------------------------------
def snapshot_flow(flows_, flow_id):
    for f in flows_.request_ok("engine", "cmd.engine.snapshot", {})["flows"]:
        if f["flowId"] == flow_id:
            return f
    raise AssertionError("the engine has no flow '%s'" % flow_id)


def trigger_info(flows_, flow_id, trigger):
    for t in snapshot_flow(flows_, flow_id)["triggers"]:
        if t["elementId"] == trigger.id:
            return t
    raise AssertionError("no trigger %s in the snapshot of %s" % (trigger.id, flow_id))


def enabled(flows_, flow_id, trigger):
    return trigger_info(flows_, flow_id, trigger)["enabled"]


def armed(flows_, flow_id, trigger):
    return trigger_info(flows_, flow_id, trigger)["armed"]


def states(flows_, flow_id, follow, own):
    """(FOLLOW enabled, OWN enabled)"""
    return (enabled(flows_, flow_id, follow), enabled(flows_, flow_id, own))


def element_step(run, name):
    """(state, message) of the last step of the element with this name, or None if it did not run."""
    found = [s for s in run.steps if s.name == name]
    return (found[-1].state, found[-1].message) if found else None


def session(flows_, builders, enable=()):
    """Adds the flows and starts the session; the flows in `enable` get `cmd.flow.enable`. Returns the flow IDs."""
    ids = [flows_.add(fb) for fb in builders]
    flows_.start()
    for flow_id in enable:
        flows_.enable(flow_id)
    return ids


def run_set(flows_, caller_id):
    run = flows_.run(caller_id)
    assert run.reason == "finished", (run.reason, run.exceptions, run.steps)
    assert run.names[-1] == "DONE", run.names
    assert element_step(run, "SET") == ("finished", ""), element_step(run, "SET")
    return run


def run_cond(flows_, caller_id):
    """The answer of a condition caller: "yes" or "no" (the branch that ran)."""
    run = flows_.run(caller_id)
    assert run.reason == "finished", (run.reason, run.exceptions, run.steps)
    branch = [n for n in run.names if n in ("YES", "NO")]
    assert len(branch) == 1, run.names
    return branch[0] == "YES"


# --- Action_Set_Flow_Status ----------------------------------------------------------------------------------------------
def test_set_flow_status_every_choice_for_another_flow(flows):
    """Enable and disable with every choice of WhichTrigger; the target is another flow (ThisFlow 0)."""
    target, follow, own = target_flow("target")
    names = ["any-on", "all-on", "all-off", "any-off", "ind-on", "ind-off", "def-on", "def-off", "spec-on", "spec-off"]
    pars = {"any-on": set_pars("Enable", "Any"), "all-on": set_pars("Enable", "All"),
            "all-off": set_pars("Disable", "All"), "any-off": set_pars("Disable", "Any"),
            "ind-on": set_pars("Enable", "Independent"), "ind-off": set_pars("Disable", "Independent"),
            "def-on": set_pars("Enable", "Default"), "def-off": set_pars("Disable", "Default"),
            "spec-on": set_pars("Enable", "Specified", trigger=own.id),
            "spec-off": set_pars("Disable", "Specified", trigger=own.id)}
    callers = {n: set_caller("c-" + n, pars[n]) for n in names}
    ids = session(flows, [target] + list(callers.values()))
    tid = ids[0]
    flow_of = {n: i for n, i in zip(names, ids[1:])}
    assert states(flows, tid, follow, own) == (False, False), "a flow of the v2 model starts with all triggers disabled"

    def check(name, expected):
        run_set(flows, flow_of[name])
        assert states(flows, tid, follow, own) == expected, name

    check("any-on", (True, False))       # The flow: the triggers that switch with the flow
    check("ind-on", (True, True))        # Triggers of their own: only the independent one changes
    check("any-off", (False, True))      # The flow off: the independent trigger stays on
    check("ind-off", (False, False))
    check("all-on", (True, True))        # All triggers
    check("any-off", (False, True))
    check("all-off", (False, False))     # All off: the complete switch-off
    check("def-on", (True, False))       # the default trigger (the first manual trigger, FOLLOW)
    check("def-off", (False, False))
    check("spec-on", (False, True))      # Specified: OWN
    check("spec-off", (False, False))


def test_set_flow_status_from_the_own_flow_does_not_stop_the_instance(flows):
    """A flow that switches itself off by its own trigger runs to its end; the other triggers keep their state."""
    fb = FlowBuilder("self")
    follow = fb.trigger(name="FOLLOW")
    own = fb.element("Trigger_Manual", "trigger", name="OWN", extra={"followsFlow": False})
    fb.chain(follow, fb.action("Action_Set_Flow_Status", name="SET", **set_pars("Disable", "Any", target="self", this_flow=1)),
             fb.action("Action_Do_nothing", name="AFTER"))
    fb.chain(own, fb.action("Action_Do_nothing", name="OWN_DONE"))
    flow_id = session(flows, [fb], enable=())[0]
    flows.request_ok("engine", "cmd.trigger.enable", {"flowId": flow_id, "elementId": follow.id})
    flows.request_ok("engine", "cmd.trigger.enable", {"flowId": flow_id, "elementId": own.id})
    assert states(flows, flow_id, follow, own) == (True, True)
    run = flows.run(flow_id, trigger=follow.id)
    assert run.reason == "finished", (run.reason, run.exceptions)
    assert run.names[-1] == "AFTER", run.names
    assert states(flows, flow_id, follow, own) == (False, True), "its own trigger switched off, the independent one stays"


def test_set_flow_status_own_flow_with_this_flow_and_the_choice_all(flows):
    """ThisFlow 1 with All: every trigger of the own flow is switched, the flow needs no ID."""
    fb = FlowBuilder("self-all")
    follow = fb.trigger(name="FOLLOW")
    own = fb.element("Trigger_Manual", "trigger", name="OWN", extra={"followsFlow": False})
    fb.chain(follow, fb.action("Action_Set_Flow_Status", name="SET", **set_pars("Enable", "All", target="", this_flow=1)),
             fb.action("Action_Do_nothing", name="AFTER"))
    fb.chain(own, fb.action("Action_Do_nothing", name="OWN_DONE"))
    flow_id = session(flows, [fb])[0]
    run = flows.run(flow_id, trigger=follow.id)
    assert run.names[-1] == "AFTER", run.names
    assert states(flows, flow_id, follow, own) == (True, True)


def test_set_flow_status_missing_flow_and_missing_trigger_are_exceptions(flows):
    target, follow, own = target_flow("target")
    bad_flow = set_caller("bad-flow", set_pars("Enable", "Any", target="nowhere", this_flow=0))
    bad_trigger = set_caller("bad-trigger", set_pars("Enable", "Specified", trigger="element-none"))
    no_trigger_id = set_caller("empty-trigger", set_pars("Enable", "Specified", trigger=""))
    ids = session(flows, [target, bad_flow, bad_trigger, no_trigger_id])
    run = flows.run(ids[1])
    assert element_step(run, "SET")[0] == "exception" and "Flow 'nowhere' does not exist" in element_step(run, "SET")[1]
    assert run.names[-1] != "DONE", "an element that fails ends the flow at its exception"
    run = flows.run(ids[2])
    message = element_step(run, "SET")[1]
    assert element_step(run, "SET")[0] == "exception" and "does not have the trigger with ID 'element-none'" in message, message
    run = flows.run(ids[3])
    assert element_step(run, "SET") == ("exception", "Trigger ID is empty"), element_step(run, "SET")
    assert states(flows, ids[0], follow, own) == (False, False), "the failed switches changed nothing"


def test_set_flow_status_choice_that_matches_no_trigger_ends_normal_with_a_log_entry(flows):
    """A flow with only the following trigger has no trigger of its own: Independent is normal, nothing changes."""
    fb = FlowBuilder("only-follow")
    follow = fb.trigger(name="FOLLOW")
    fb.chain(follow, fb.action("Action_Do_nothing", name="FOLLOW_DONE"))
    caller = set_caller("c-ind", set_pars("Enable", "Independent", target="only-follow"))
    ids = session(flows, [fb, caller])
    run = run_set(flows, ids[1])
    assert element_step(run, "SET") == ("finished", ""), element_step(run, "SET")
    assert any("matches the choice 'Independent'" in e["text"] for e in run.log), run.log
    assert enabled(flows, ids[0], follow) is False


def test_set_flow_status_default_trigger_of_a_flow_without_one_is_an_exception(flows):
    """A flow without a manual trigger has no default trigger: the v1 text."""
    fb = FlowBuilder("no-manual")
    timer = fb.trigger("Test.Trigger_TestTimer", Interval="1000")
    fb.chain(timer, fb.action("Action_Do_nothing", name="TICK"))
    caller = set_caller("c-def", set_pars("Enable", "Default", target="no-manual"))
    ids = session(flows, [fb, caller])
    run = flows.run(ids[1])
    assert element_step(run, "SET") == ("exception", "Flow 'no-manual' does not have any manual trigger."), element_step(run, "SET")


def test_set_flow_status_switch_arms_a_timer_trigger_and_keeps_the_state_after_a_restart(host_flows):
    """The switch arms the test timer (WI-0061, WI-0062) and the state is kept after a restart of the session (E0057, E0063)."""
    flows_ = host_flows
    timer, trigger = timer_flow("timed")
    caller = set_caller("c-timed", set_pars("Enable", "Any", target="timed"))
    ids = session(flows_, [timer, caller])
    timed = ids[0]
    assert enabled(flows_, timed, trigger) is False and armed(flows_, timed, trigger) is False
    run_set(flows_, ids[1])
    assert wait_until(lambda: armed(flows_, timed, trigger) is True), "the switch did not arm the timer"
    flows_.stop()                                 # the regular end of the session (cmd.app.exit)
    flows_.start()
    assert wait_until(lambda: armed(flows_, timed, trigger) is True), "the state was not kept over the restart"
    assert enabled(flows_, timed, trigger) is True
    flows_.request_ok("engine", "cmd.flow.disable", {"flowId": timed})
    assert wait_until(lambda: armed(flows_, timed, trigger) is False), "a disabled timer stays armed"


def wait_until(predicate, timeout=WAIT_S):
    deadline = time.monotonic() + scaled(timeout)
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(0.05)
    return False


# --- Condition_Flow_Enabled ----------------------------------------------------------------------------------------------
def test_condition_flow_enabled_every_choice(flows):
    """Each choice, asked while the states are: nothing, own only, the flow only, both."""
    target, follow, own = target_flow("target")
    choices = {"any": cond_pars("Any", target="target"), "anyt": cond_pars("AnyTrigger", target="target"),
               "allt": cond_pars("AllTriggers", target="target"), "anyi": cond_pars("AnyIndependent", target="target"),
               "def": cond_pars("Default", target="target"),
               "spec-own": cond_pars("Specified", target="target", trigger=own.id),
               "spec-follow": cond_pars("Specified", target="target", trigger=follow.id)}
    callers = {n: cond_caller("q-" + n, p) for n, p in choices.items()}
    ids = session(flows, [target] + list(callers.values()))
    tid = ids[0]
    ask = {n: ids[i + 1] for i, n in enumerate(choices)}

    def answers(expected):
        got = {n: run_cond(flows, ask[n]) for n in choices}
        assert got == expected, got

    # nothing enabled
    answers({"any": False, "anyt": False, "allt": False, "anyi": False, "def": False, "spec-own": False, "spec-follow": False})
    flows.request_ok("engine", "cmd.trigger.enable", {"flowId": tid, "elementId": own.id})
    answers({"any": False, "anyt": True, "allt": False, "anyi": True, "def": False, "spec-own": True, "spec-follow": False})
    flows.enable(tid)
    answers({"any": True, "anyt": True, "allt": True, "anyi": True, "def": True, "spec-own": True, "spec-follow": True})
    flows.request_ok("engine", "cmd.flow.disable", {"flowId": tid})
    answers({"any": False, "anyt": True, "allt": False, "anyi": True, "def": False, "spec-own": True, "spec-follow": False})


def test_condition_flow_enabled_asks_the_target_state_not_the_arming(flows):
    """The answer is the target state of the trigger (E0056, WI-0060), whether or not the trigger is armed (no host here)."""
    target, follow, own = target_flow("target")
    cond = cond_caller("q-own", cond_pars("Specified", target="target", trigger=own.id))
    ids = session(flows, [target, cond])
    assert run_cond(flows, ids[1]) is False
    flows.request_ok("engine", "cmd.trigger.enable", {"flowId": ids[0], "elementId": own.id})
    assert run_cond(flows, ids[1]) is True


def test_condition_flow_enabled_a_choice_without_triggers_is_no_with_a_log_entry(flows):
    """A flow without any trigger: every choice gives no, and the log says why."""
    fb = FlowBuilder("empty")
    fb.chain(fb.action("Action_Do_nothing", name="ONLY"))
    cond = cond_caller("q-all", cond_pars("AllTriggers", target="empty"))
    ids = session(flows, [fb, cond])
    run = flows.run(ids[1])
    assert run.reason == "finished" and "NO" in run.names and "YES" not in run.names, run.names
    assert any("has no trigger for the choice 'AllTriggers'" in e["text"] for e in run.log), run.log


def test_condition_flow_enabled_missing_flow_and_trigger_are_exceptions(flows):
    target, follow, own = target_flow("target")
    missing = cond_caller("q-missing", cond_pars("Any", target="nowhere", this_flow=0))
    empty = cond_caller("q-empty", cond_pars("Specified", target="target", trigger=""))
    ids = session(flows, [target, missing, empty])
    run = flows.run(ids[1])
    state, message = element_step(run, "COND")
    assert state == "exception" and message == "Flow 'nowhere' does not exist", (state, message)
    run = flows.run(ids[2])
    assert element_step(run, "COND") == ("exception", "Trigger ID is empty"), element_step(run, "COND")


# --- the flow state that cannot be read ----------------------------------------------------------------------------------
def test_a_switch_of_a_flow_whose_state_cannot_be_read_ends_the_element_with_exception(flows, datadir):
    """An element cannot wait for the read (E0063): the switch is refused at once and nothing changes."""
    target, follow, own = target_flow("target")
    caller = set_caller("c-unreadable", set_pars("Enable", "Any"))
    (datadir / "FlowStates").mkdir(exist_ok=True)
    (datadir / "FlowStates" / "target.json").mkdir()     # a folder where the file is: it exists and cannot be read
    target_id, caller_id = session(flows, [target, caller])
    run = flows.run(caller_id)
    state, message = element_step(run, "SET")
    assert state == "exception" and "cannot be read" in message, (state, message)
    assert run.names[-1] != "DONE", run.names
    assert states(flows, target_id, follow, own) == (False, False), "a refused switch changes nothing"
