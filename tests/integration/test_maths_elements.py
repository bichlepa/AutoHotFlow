"""WI-0118: end-to-end tests of the maths elements of the package Default: Random number, Absolute number, Square root,
Trigonometry, Rounding a number and Exponentiation. Every test builds small flows with the flow builder, adds them to
the data folder of one session and runs them one after the other (`support/coreflows.py`). The result is read with a
probe of the variable `x` after the element; an error is the exception of the run.

Expected values are those of v1 where v1 has a result; where v1 wrote an empty text for a result that is not defined,
the element ends with an exception (MIGRATION M-0104). The square root of an exact whole number is a whole number, any
other result a decimal number (decision of WI-0118, Action_Square_Root.ahk).
"""

import json
import math

import pytest

from support.coreflows import run_all, setvar
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def maths_flow(name, cls, strict=True, setup=None, **pars):
    """trigger -> [Action_TestSetVar with the variables `setup`] -> the element -> probe of `x`."""
    fb = FlowBuilder(name, strict_types=strict)
    prev = fb.trigger()
    if setup:
        step = fb.action("Action_TestSetVar", Steps=json.dumps([setvar(n, v) for n, v in setup]))
        fb.connect(prev, step)
        prev = step
    el = fb.action(cls, Varname="x", **pars)
    fb.connect(prev, el)
    fb.connect(el, fb.probe("x"))
    return fb


def value(run):
    """The probe of `x` as (text, type), or None when the flow ended before the probe (an exception)."""
    probe = run.seen.get("x") if run.seen else None
    return None if probe is None else (probe.text, probe.type)


def close(run, expected, tolerance=1e-9):
    text, _ = value(run)
    assert abs(float(text) - expected) <= tolerance, (text, expected)


# --- Action_Random_number -------------------------------------------------------------------------------------------
def test_random_number_gives_a_number_between_the_limits(flows):
    runs = run_all(flows, [
        maths_flow("rnd_fixed", "Action_Random_number", MinValue=7, MaxValue=7),
        maths_flow("rnd_range", "Action_Random_number", MinValue=1, MaxValue=10),
        maths_flow("rnd_float", "Action_Random_number", MinValue="2.5", MaxValue=2.5),
        maths_flow("rnd_reverse", "Action_Random_number", MinValue=5, MaxValue=1),
    ])
    assert value(runs[0]) == ("7", "Integer")
    text, kind = value(runs[1])
    assert kind == "Integer" and 1 <= int(text) <= 10
    assert value(runs[2]) == ("2.5", "Float")
    text, kind = value(runs[3])                    # AutoHotkey v2 takes the limits in either order
    assert kind == "Integer" and 1 <= int(text) <= 5


@pytest.mark.parametrize("strict", [True, False], ids=["strict", "compat"])
def test_random_number_text_that_is_no_number_is_an_error_in_both_modes(flows, strict):
    run = run_all(flows, [maths_flow("rnd_text_%s" % strict, "Action_Random_number", strict=strict,
                                     MinValue="abc", MaxValue=3)])[0]
    assert len(run.exceptions) == 1 and "abc" in run.exceptions[0], run.exceptions
    assert value(run) is None


# --- Action_Absolute_number -----------------------------------------------------------------------------------------
def test_absolute_number_of_negative_and_positive_numbers(flows):
    runs = run_all(flows, [
        maths_flow("abs_int", "Action_Absolute_number", VarValue="-2"),
        maths_flow("abs_float", "Action_Absolute_number", VarValue="-2.5"),
        maths_flow("abs_positive", "Action_Absolute_number", VarValue="3"),
        maths_flow("abs_expression", "Action_Absolute_number", VarValue="0 - 7"),
    ])
    assert value(runs[0]) == ("2", "Integer")
    assert value(runs[1]) == ("2.5", "Float")
    assert value(runs[2]) == ("3", "Integer")
    assert value(runs[3]) == ("7", "Integer")


@pytest.mark.parametrize("strict", [True, False], ids=["strict", "compat"])
def test_absolute_number_of_a_text_is_an_exception_with_the_v1_text(flows, strict):
    run = run_all(flows, [maths_flow("abs_text_%s" % strict, "Action_Absolute_number", strict=strict,
                                     VarValue='"abc"')])[0]
    assert run.exceptions == ["Value is not a number: abc"], run.exceptions


# --- Action_Square_Root ---------------------------------------------------------------------------------------------
def test_square_root_of_exact_and_other_numbers(flows):
    runs = run_all(flows, [
        maths_flow("sqrt_exact", "Action_Square_Root", VarValue=16),
        maths_flow("sqrt_zero", "Action_Square_Root", VarValue=0),
        maths_flow("sqrt_two", "Action_Square_Root", VarValue=2),
        maths_flow("sqrt_decimal", "Action_Square_Root", VarValue="2.25"),
    ])
    assert value(runs[0]) == ("4", "Integer")
    assert value(runs[1]) == ("0", "Integer")
    close(runs[2], math.sqrt(2))
    assert value(runs[2])[1] == "Float"
    close(runs[3], 1.5)


def test_square_root_of_a_negative_number_is_an_exception(flows):
    run = run_all(flows, [maths_flow("sqrt_negative", "Action_Square_Root", VarValue=-1)])[0]
    assert run.exceptions == ["Square root of a negative number is not defined: '-1'."], run.exceptions
    assert value(run) is None


# --- Action_Trigonometry --------------------------------------------------------------------------------------------
def trig(name, operation, unit, number):
    return maths_flow(name, "Action_Trigonometry", VarValue=number, Operation=operation, Unit=unit)


def test_trigonometry_in_radians_and_degrees(flows):
    runs = run_all(flows, [
        trig("trig_sine_deg", "Sine", "Degree", "90"),
        trig("trig_cos_rad", "Cosine", "Radian", "0"),
        trig("trig_tan_deg", "Tangent", "Degree", "45"),
        trig("trig_asin_deg", "Arcsine", "Degree", "1"),
        trig("trig_acos_rad", "Arccosine", "Radian", "0"),
        trig("trig_atan_deg", "Arctangent", "Degree", "1"),
        trig("trig_atan_rad", "Arctangent", "Radian", "1"),
        trig("trig_sine_rad", "Sine", "Radian", "0.5"),
    ])
    close(runs[0], 1.0)
    close(runs[1], 1.0)
    close(runs[2], 1.0)
    close(runs[3], 90.0)
    close(runs[4], 90.0 / 180 * math.pi)
    close(runs[5], 45.0)
    close(runs[6], math.pi / 4)
    close(runs[7], math.sin(0.5))


def test_arcsine_outside_minus_one_to_one_is_an_exception(flows):
    run = run_all(flows, [trig("trig_asin_out", "Arcsine", "Radian", "2")])[0]
    assert run.exceptions == ["Arcsine and arccosine need a value between -1 and 1: '2'."], run.exceptions


# --- Action_Rounding_A_Number ---------------------------------------------------------------------------------------
def rounding(name, number, places, kind):
    return maths_flow(name, "Action_Rounding_A_Number", VarValue=number, Places=places, Roundingtype=kind)


def test_rounding_normally_up_and_down(flows):
    runs = run_all(flows, [
        rounding("rnd_round", "1.2345", 2, "round"),
        rounding("rnd_up", "1.2345", 2, "roundUp"),
        rounding("rnd_down", "1.2345", 2, "roundDown"),
        rounding("rnd_up_exact", "1.2", 2, "roundUp"),
        rounding("rnd_neg_up", "-1.25", 1, "roundUp"),
        rounding("rnd_neg_down", "-1.25", 1, "roundDown"),
    ])
    assert value(runs[0])[0] == "1.23"
    assert value(runs[1])[0] == "1.24"
    assert value(runs[2])[0] == "1.23"
    assert value(runs[3])[0] == "1.2"           # already exact: no step
    assert value(runs[4])[0] == "-1.2"          # up: towards plus infinity
    assert value(runs[5])[0] == "-1.3"          # down: towards minus infinity


def test_rounding_with_zero_and_negative_places(flows):
    runs = run_all(flows, [
        rounding("rnd_zero_places", "1.5", 0, "round"),
        rounding("rnd_hundreds", "1234", -2, "round"),
        rounding("rnd_fraction_places", "1.2345", "1.7", "round"),   # the fraction is cut off
    ])
    assert value(runs[0]) == ("2", "Integer")
    assert value(runs[1]) == ("1200", "Integer")
    assert value(runs[2])[0] == "1.2"


# --- Action_Exponentiation ------------------------------------------------------------------------------------------
def power(name, base, exponent):
    return maths_flow(name, "Action_Exponentiation", VarValue=base, Exponent=exponent)


def test_exponentiation_of_whole_and_decimal_numbers(flows):
    runs = run_all(flows, [
        power("pow_int", 3, 2),
        power("pow_big", 10, 3),
        power("pow_negative", 2, -1),
        power("pow_root", 2, "0.5"),
    ])
    assert value(runs[0]) == ("9", "Integer")
    assert value(runs[1]) == ("1000", "Integer")
    assert value(runs[2]) == ("0.5", "Float")
    close(runs[3], math.sqrt(2))


@pytest.mark.parametrize("base, exponent", [(0, -1), (-8, "0.5")], ids=["zero_to_negative", "negative_to_fraction"])
def test_exponentiation_without_a_result_is_an_exception(flows, base, exponent):
    run = run_all(flows, [power("pow_undefined", base, exponent)])[0]
    assert len(run.exceptions) == 1 and "is not defined" in run.exceptions[0], run.exceptions
    assert value(run) is None


@pytest.mark.parametrize("strict", [True, False], ids=["strict", "compat"])
def test_exponentiation_text_that_is_no_number_is_an_error_in_both_modes(flows, strict):
    fb = maths_flow("pow_text_%s" % strict, "Action_Exponentiation", strict=strict, VarValue="abc", Exponent=2)
    run = run_all(flows, [fb])[0]
    assert len(run.exceptions) == 1 and "abc" in run.exceptions[0], run.exceptions
