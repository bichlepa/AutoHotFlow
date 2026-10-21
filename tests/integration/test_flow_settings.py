"""WI-0109, REQ-USE-080 (the switch of the notices per flow), PROTOCOL 4.2 (flow settings) and 4.7 (switch): the per-flow switch
of the notices of unhandled exceptions in a real session. The session is the one of the notice tests (storage, engine, headless
manager and tray): a flow whose flowSettings.notifyUnhandledErrors is false gives no notice, a flow with true gives one, and
"default" (or no key) takes the global setting. The copy of the variables of a switched-off error is kept (PROTOCOL 4.7a); that
is checked by the error window test, not here.
"""

from support.flowbuilder import FlowBuilder
from support.timing import scaled
from test_notices import notices_of, shown, start_shown, wait_for  # the fixture and the helpers of the notice tests

WAIT_S = scaled(5.0)


def throwing(name, switch=None):
    """Every start ends with an unhandled exception (Action_TestThrow has no connection for it). switch: the value of
    flowSettings.notifyUnhandledErrors, or None for no key."""
    settings = {} if switch is None else {"notifyUnhandledErrors": switch}
    fb = FlowBuilder(name, flow_settings=settings)
    fb.chain(fb.trigger(), fb.action("Action_TestThrow", name="THROWS"))
    return fb


def test_a_flow_switched_off_gives_no_notice_and_a_flow_switched_on_does(shown):
    quiet = shown.add(throwing("quiet", switch=False))
    loud = shown.add(throwing("loud", switch=True))
    start_shown(shown)
    shown.begin(quiet)
    shown.begin(loud)
    assert shown.ended(quiet, count=1, timeout=WAIT_S), "the quiet flow did not end"
    assert shown.ended(loud, count=1, timeout=WAIT_S), "the loud flow did not end"
    assert wait_for(lambda: len(notices_of(shown, loud)) == 1, WAIT_S), "the flow switched on gives its notice"
    assert notices_of(shown, quiet) == [], "the flow switched off gives no notice"


def test_default_takes_the_global_switch_and_a_flow_value_overrides_it(shown):
    inherit = shown.add(throwing("inherit", switch="default"))
    forced = shown.add(throwing("forced", switch=True))
    start_shown(shown)
    shown.request_ok("engine", "cmd.settings.set", {"settings": {"notifyUnhandledErrors": False}})
    shown.begin(inherit)
    shown.begin(forced)
    assert shown.ended(inherit, count=1, timeout=WAIT_S), "the inheriting flow did not end"
    assert shown.ended(forced, count=1, timeout=WAIT_S), "the forced flow did not end"
    assert wait_for(lambda: len(notices_of(shown, forced)) == 1, WAIT_S), "the flow value wins over the global setting"
    assert notices_of(shown, inherit) == [], "default takes the global setting, which is off"
