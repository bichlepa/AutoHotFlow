"""WI-0123: end-to-end tests of the power and session elements of the package Default: Lock computer, Log off, Shutdown,
Reboot computer, Hibernate computer and Suspend computer (E0103). The calls go through SystemOps; the test provider records
each call with its arguments and answers from a script, so nothing is locked, logged off, shut down or suspended.

The codes are those of v1: Shutdown 9 (shut down and power off), Reboot 2, force adds 4; Log off is Shutdown 0; Hibernate
and Suspend are SetSuspendState with hibernate 1 or 0 and force 0.
"""

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.coreflows import run_all
from support.system import SystemScript, error


@pytest.fixture
def datadir_system(flows):
    """The script of the system provider: no answers, so every call returns the empty value and is only recorded."""
    system = SystemScript(flows.datadir)
    system.script({})
    return system


def power_flow(name, cls, **pars):
    fb = FlowBuilder(name)
    fb.chain(fb.trigger(), fb.action(cls, **pars))
    return fb


def calls(system, function):
    return [c for c in system.requests() if c["function"] == function]


@pytest.mark.parametrize("cls, function, args", [
    ("Action_Lock_Computer", "LockWorkStation", []),
    ("Action_Log_Off", "Shutdown", [0]),
    ("Action_Hibernate_Computer", "Hibernate", [0]),
    ("Action_Suspend_Computer", "Suspend", [0]),
])
def test_power_actions_call_the_seam_with_the_v1_arguments(flows, datadir_system, cls, function, args):
    system = datadir_system
    runs = run_all(flows, [power_flow("power_" + cls, cls)])
    assert not runs[0].exceptions, runs[0].steps
    found = calls(system, function)
    assert found and found[-1]["args"] == args, system.requests()


def test_shutdown_and_reboot_send_the_v1_codes_and_the_force_bit(flows, datadir_system):
    system = datadir_system
    runs = run_all(flows, [
        power_flow("shutdown", "Action_Shutdown", Force=0),
        power_flow("shutdown_force", "Action_Shutdown", Force=1),
        power_flow("reboot", "Action_Reboot_Computer", Force=0),
        power_flow("reboot_force", "Action_Reboot_Computer", Force=1),
    ])
    assert not any(r.exceptions for r in runs), [r.steps for r in runs]
    codes = [c["args"][0] for c in calls(system, "Shutdown")]
    assert codes == [9, 13, 2, 6]


def test_a_failing_system_call_ends_the_element_with_an_exception(flows, datadir_system):
    system = datadir_system
    system.script({"LockWorkStation": [error("no session")]})
    runs = run_all(flows, [power_flow("lock_fails", "Action_Lock_Computer")])
    assert runs[0].exceptions and "no session" in runs[0].exceptions[0]
