"""WI-0118 (REQ-VAR-020): end-to-end tests of Action_Script, the script form of the expression language run by an action.

Each flow runs the script and then probes the variables it names; a script that fails ends with the exception of the run.
The mode of the flow (strict or compatibility, E0034) is parametrized where a warning decides the result.
"""

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def script_flow(name, script, probes=("x",), strict=True):
    """trigger -> Action_Script -> probes of the variables `probes`."""
    fb = FlowBuilder(name, strict_types=strict)
    el = fb.action("Action_Script", Script=script)
    fb.chain(fb.trigger(), el, fb.probe(*probes))
    return fb


def probed(run, name):
    probe = run.seen.get(name) if run.seen else None
    return None if probe is None else (probe.text, probe.type)


def test_script_sets_variables_and_the_last_value_is_not_stored(flows):
    runs = run_all(flows, [
        script_flow("scr_assign", "x := 2 * 3\ny := \"text\"", probes=("x", "y")),
        script_flow("scr_if", "x := 7\nif x > 5 {\n    y := \"big\"\n} else {\n    y := \"small\"\n}", probes=("y",)),
        script_flow("scr_value_only", "1 + 1", probes=("x",)),
    ])
    assert probed(runs[0], "x") == ("6", "Integer") and probed(runs[0], "y") == ("text", "String")
    assert probed(runs[1], "y") == ("big", "String")
    assert runs[2].exceptions and probed(runs[2], "x") is None      # a line with only a value is an error


def test_script_text_is_not_substituted_as_a_variable(flows):
    run = run_all(flows, [script_flow("scr_percent", 'y := 5\nx := "%y%"')])[0]
    assert probed(run, "x") == ("%y%", "String")


@pytest.mark.parametrize("strict", [True, False], ids=["strict", "compat"])
def test_script_error_ends_with_exception(flows, strict):
    run = run_all(flows, [script_flow("scr_error_%s" % strict, "x := (1 +", strict=strict)])[0]
    assert run.exceptions and probed(run, "x") is None, run.exceptions


def test_script_division_by_zero_in_strict_mode_is_an_exception(flows):
    strict, compat = run_all(flows, [
        script_flow("scr_div_strict", "x := 1 / 0", strict=True),
        script_flow("scr_div_compat", "x := 1 / 0", strict=False),
    ])
    assert strict.exceptions and probed(strict, "x") is None
    assert probed(compat, "x") == ("", "String")                     # compatibility: the failed part is the empty text


def test_empty_script_is_an_exception(flows):
    run = run_all(flows, [script_flow("scr_empty", "")])[0]
    assert len(run.exceptions) == 1 and "Script" in run.exceptions[0], run.exceptions

