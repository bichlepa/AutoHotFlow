"""WI-0047 (E0045, REQ-PKG-060): the package is part of the identity of an element, in a real session.

The test packages Test and TestTwin (tests/elements/) both have the classes Action_TestPackageName (inline) and
Action_TestPackageNameWorker (worker); each writes its package and its qualified ID into a global variable. One flow
runs all four in one session (supervisor, storage, engine and the worker pool of the test entry): the registry of the
engine, the inline run and the worker job (`cmd.worker.run` with the qualified ID) must each pick the class of the
package that the flow element names. A flow in the v1 format whose elements write `package: default` (as 8 elements
of the test flows do) loads and runs.
"""

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def test_two_packages_with_a_class_of_the_same_name_are_told_apart_in_registry_run_and_worker_job(flows):
    fb = FlowBuilder("twins")
    fb.chain(fb.trigger(),
             fb.action("Test.Action_TestPackageName", Tag="a"),
             fb.action("TestTwin.Action_TestPackageName", Tag="b"),
             fb.action("Test.Action_TestPackageNameWorker", Tag="c"),
             fb.action("TestTwin.Action_TestPackageNameWorker", Tag="d"))
    run = flows.run(fb)
    assert run.reason == "finished", (run.steps, run.exceptions)
    expected = {"a": "Test Test.Action_TestPackageName", "b": "TestTwin TestTwin.Action_TestPackageName",
                "c": "Test Test.Action_TestPackageNameWorker", "d": "TestTwin TestTwin.Action_TestPackageNameWorker"}
    for tag, text in expected.items():
        assert flows.wait_var("global_pkg_" + tag, lambda p, t=text: p[1] == t) == ("normal", text), tag


@pytest.mark.slow
def test_a_v1_flow_whose_elements_write_package_default_in_lower_case_loads_and_runs(flows):
    fb = FlowBuilder("lower", v2=False)
    fb.chain(fb.trigger("default.Trigger_Manual"),
             fb.action("default.Action_Sleep", Duration="0.05", Unit="Seconds"),
             fb.action("default.Action_Do_nothing"))
    assert {e["package"] for e in fb.to_dict()["allElements"].values()} == {"default"}
    run = flows.run(fb)
    assert run.reason == "finished", (run.steps, run.exceptions)
    assert run.names == ["Trigger_Manual", "Action_Sleep", "Action_Do_nothing"]
    assert [s.state for s in run.steps] == ["finished"] * 3
