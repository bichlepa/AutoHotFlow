"""WI-0086, REQ-EDT-040, REQ-EDT-150, REQ-VAR-100 (engine part), REQ-ROB-040, REQ-EXE-140: the engine gives an editor
the states of all elements at once (cmd.flow.runstate), the connection a thread took to an element (connectionId of
evt.element.state) and the warnings of the evaluations per element (evt.element.warning, cmd.flow.runstate).

The engine runs as a real session (supervisor, storage, engine) through FlowRunner, as in test_runaway.py.
"""

from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.timing import scaled

WAIT_S = scaled(10.0)


def element_events(messages, element_id, state=None):
    """The evt.element.state payloads of one element (and of one state, if given), in order."""
    return [m["payload"] for m in messages if m.get("type") == "evt.element.state"
            and m["payload"]["elementId"] == element_id and (state is None or m["payload"]["state"] == state)]


def run_marked(flows_, fb):
    """Adds the flow, starts the session and runs one instance: (mark, FlowRun). The mark is taken with the
    session running, so the messages since the mark are those of this instance."""
    flow_id = flows_.add(fb)
    flows_.start()
    mark = flows_.mark()
    return mark, flows_.wait(flows_.begin(flow_id))


def runstate(flows_, flow_id):
    return flows_.request_ok("engine", "cmd.flow.runstate", {"flowId": flow_id})


def element_entry(state, element_id):
    found = [e for e in state["elements"] if e["elementId"] == element_id]
    return found[0] if found else None


def test_runstate_shows_a_running_element_and_its_count_after_the_end(flows):
    fb = FlowBuilder("runstate sleep")
    trigger = fb.trigger()
    sleep = fb.action("Action_Sleep", Duration=1000, Unit="Milliseconds")
    done = fb.action("Action_Do_nothing")
    fb.connect(trigger, sleep)
    fb.connect(sleep, done)
    flow_id = flows.add(fb)
    flows.start()
    started = flows.mark()
    run = flows.begin(fb)
    assert flows.wait_message(lambda m: m.get("type") == "evt.element.state" and m["payload"]["elementId"] == sleep.id
                              and m["payload"]["state"] == "running", WAIT_S, started)
    during = runstate(flows, flow_id)
    entry = element_entry(during, sleep.id)
    assert entry["state"] == "running" and entry["countRuns"] == 1 and entry["lastRun"]
    assert during["flow"]["executing"] is True and during["flow"]["instances"] == 1
    assert [t["elementId"] for t in during["triggers"]] == [trigger.id]
    assert "warnings" in entry and "lastWarning" not in entry

    flows.wait(run)
    after = runstate(flows, flow_id)
    entry = element_entry(after, sleep.id)
    assert entry["state"] == "finished" and entry["countRuns"] == 0
    assert entry["lastRun"] == element_entry(during, sleep.id)["lastRun"]
    assert element_entry(after, done.id)["state"] == "finished"
    assert after["flow"]["executing"] is False and after["flow"]["instances"] == 0
    assert "stateError" not in after["flow"]


def test_runstate_of_an_unknown_flow_is_not_found(flows):
    fb = FlowBuilder("runstate known")
    fb.connect(fb.trigger(), fb.action("Action_Do_nothing"))
    flows.add(fb)
    flows.start()
    answer = flows.request("engine", "cmd.flow.runstate", {"flowId": "no-such-flow"})
    assert answer["ok"] is False and answer["error"]["code"] == "not_found"


def test_the_connection_taken_is_sent_with_the_running_event_on_yes_and_no(flows):
    fb = FlowBuilder("connection yes")
    trigger = fb.trigger()
    cond = fb.condition("Condition_Expression", Expression="1 = 1")
    yes = fb.action("Action_Do_nothing")
    no = fb.action("Action_Do_nothing", name="never")
    c_trigger = fb.connect(trigger, cond)
    c_yes = fb.connect(cond, yes, "yes")
    c_no = fb.connect(cond, no, "no")
    mark, run = run_marked(flows, fb)
    assert run.reason == "finished"
    messages = flows.messages(mark)
    assert [p.get("connectionId") for p in element_events(messages, trigger.id, "running")] == [None]
    assert [p.get("connectionId") for p in element_events(messages, cond.id, "running")] == [c_trigger]
    assert [p.get("connectionId") for p in element_events(messages, yes.id, "running")] == [c_yes]
    assert element_events(messages, no.id) == [], "the no branch must not run"
    assert c_no not in [p.get("connectionId") for p in element_events(messages, yes.id)]


def test_the_connections_of_a_loop_are_sent_for_the_entry_and_the_body(flows):
    fb = FlowBuilder("connection loop")
    trigger = fb.trigger()
    loop = fb.loop("Loop_SimpleLoop", repeatCount=2)
    body = fb.action("Action_Do_nothing")
    after = fb.action("Action_Do_nothing", name="after")
    c_entry = fb.connect(trigger, loop)
    c_head = fb.connect(loop, body, "head")
    c_back = fb.connect(body, loop, into="tail")
    fb.connect(loop, after, "tail")
    mark, run = run_marked(flows, fb)
    assert run.reason == "finished"
    messages = flows.messages(mark)
    body_runs = element_events(messages, body.id, "running")
    assert len(body_runs) == 2
    assert {p["connectionId"] for p in body_runs} == {c_head}
    loop_runs = element_events(messages, loop.id, "running")
    assert loop_runs[0]["connectionId"] == c_entry
    assert {p["connectionId"] for p in loop_runs[1:]} == {c_back}
    assert element_events(messages, after.id, "running")[0]["connectionId"] != c_head


def test_warnings_of_a_loop_are_counted_exactly_and_sent_coalesced(flows):
    """Compatibility mode: 'x + 1' with x unset is a type error, a warning (E0025) with the empty text. The condition
    takes the 'no' connection, so the loop runs 1000 passes."""
    passes = 1000
    fb = FlowBuilder("warnings loop", strict_types=False)
    trigger = fb.trigger()
    loop = fb.loop("Loop_SimpleLoop", repeatCount=passes)
    cond = fb.condition("Condition_Expression", Expression="x + 1")
    after = fb.action("Action_Do_nothing", name="after")
    fb.connect(trigger, loop)
    fb.connect(loop, cond, "head")
    fb.connect(cond, loop, "no", into="tail")
    fb.connect(loop, after, "tail")
    flow_id = flows.add(fb)
    flows.start()
    mark = flows.mark()
    run = flows.begin(fb)
    flows.wait(run)
    assert run.reason == "finished"
    state = runstate(flows, flow_id)
    entry = element_entry(state, cond.id)
    assert entry["countRuns"] == 0 and entry["warnings"] == passes
    assert "(line 1, column" in entry["lastWarning"] and len(entry["lastWarning"]) <= 500
    # the last count is sent when the second of the element is over: wait for it, then collect the events
    last = flows.wait_message(lambda m: m.get("type") == "evt.element.warning" and m["payload"]["elementId"] == cond.id
                              and m["payload"]["count"] == passes, WAIT_S, mark)
    assert last is not None, "the last count was never sent"
    events = [m["payload"] for m in flows.messages(mark) if m.get("type") == "evt.element.warning"
              and m["payload"]["elementId"] == cond.id]
    assert events, "no evt.element.warning was sent"
    assert len(events) <= 5, "%d events for %d warnings: not coalesced" % (len(events), passes)
    assert events[-1]["count"] == passes, "the last event must carry the exact count"
    counts = [e["count"] for e in events]
    assert counts == sorted(counts)
    assert events[-1]["text"] == entry["lastWarning"]


def test_strict_mode_gives_an_exception_and_no_warning(flows):
    fb = FlowBuilder("strict warning", strict_types=True)
    trigger = fb.trigger()
    cond = fb.condition("Condition_Expression", Expression="x + 1")
    fb.connect(trigger, cond)
    fb.connect(cond, fb.action("Action_Do_nothing"), "yes")
    flow_id = flows.add(fb)
    flows.start()
    mark = flows.mark()
    run = flows.begin(fb)
    flows.wait(run)
    assert run.reason == "exception"
    entry = element_entry(runstate(flows, flow_id), cond.id)
    assert entry["state"] == "exception" and entry["warnings"] == 0 and "lastWarning" not in entry
    assert not [m for m in flows.messages(mark) if m.get("type") == "evt.element.warning"]


def test_an_engine_restart_starts_with_empty_counts(flows):
    fb = FlowBuilder("restart counts")
    trigger = fb.trigger()
    done = fb.action("Action_Do_nothing")
    fb.connect(trigger, done)
    flow_id = flows.add(fb)
    flows.run(fb)
    assert element_entry(runstate(flows, flow_id), done.id)["countRuns"] == 0
    flows.stop()
    flows.start()
    state = runstate(flows, flow_id)
    assert state["elements"] == []
    assert state["flow"]["executing"] is False
