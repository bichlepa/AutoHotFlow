"""WI-0118 (REQ-ELM-280): end-to-end tests of the time elements of the package Default: New time, Time calculation and
Time difference. Each flow runs the element and probes the variable `x`; an error is the exception of the run.

Time stamps have the form YYYYMMDDHH24MISS; a shorter form is a valid time stamp too (IsTime, MIGRATION M-0053). A time
stamp that is not valid ends the element with exception, it never gives an empty result.
"""

import re

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def time_flow(name, cls, strict=True, **pars):
    """trigger -> the element (its output variable is `x`) -> probe of `x`."""
    fb = FlowBuilder(name, strict_types=strict)
    el = fb.action(cls, Varname="x", **pars)
    fb.chain(fb.trigger(), el, fb.probe("x"))
    return fb


def value(run):
    probe = run.seen.get("x") if run.seen else None
    return None if probe is None else (probe.text, probe.type)


# --- Action_New_Time ----------------------------------------------------------------------------------------------
def test_new_time_current_and_specified(flows):
    runs = run_all(flows, [
        time_flow("nt_current", "Action_New_Time", WhichTime="Current"),
        time_flow("nt_full", "Action_New_Time", WhichTime="Specified", Time="20210528165541"),
        time_flow("nt_year", "Action_New_Time", WhichTime="Specified", Time="2015"),
        time_flow("nt_date", "Action_New_Time", WhichTime="Specified", Time="20150101"),
    ])
    text, kind = value(runs[0])
    assert kind == "String" and re.fullmatch(r"\d{14}", text), text       # A_Now: YYYYMMDDHH24MISS
    assert value(runs[1]) == ("20210528165541", "String")
    assert value(runs[2]) == ("2015", "String")
    assert value(runs[3]) == ("20150101", "String")


@pytest.mark.parametrize("stamp", ["2015023", "20231340000000", "abc", ""], ids=["odd", "month13", "text", "empty"])
def test_new_time_of_an_invalid_time_stamp_is_an_exception(flows, stamp):
    run = run_all(flows, [time_flow("nt_bad_%s" % len(stamp), "Action_New_Time", WhichTime="Specified", Time=stamp)])[0]
    assert run.exceptions == ["Value '%s' is not valid." % stamp], run.exceptions
    assert value(run) is None


# --- Action_Time_Calculation --------------------------------------------------------------------------------------
def add_time(name, input_time, units, unit=None, strict=True):
    pars = dict(InputTime=input_time, Units=units)
    if unit is not None:
        pars["Unit"] = unit
    return time_flow(name, "Action_Time_Calculation", strict=strict, **pars)


def test_time_calculation_in_each_unit(flows):
    runs = run_all(flows, [
        add_time("tc_days", "2010", 1826, "Days"),
        add_time("tc_days_back", "2010", -1, "Days"),
        add_time("tc_hours", "2010", 1, "Hours"),
        add_time("tc_minutes_back", "2010", -1, "Minutes"),
        add_time("tc_seconds", "20210528165541", 1, "Seconds"),
        add_time("tc_default_unit", "2010", 10),              # no Unit in the flow: the default is Minutes
    ])
    assert value(runs[0]) == ("20150101000000", "String")
    assert value(runs[1]) == ("20091231000000", "String")
    assert value(runs[2]) == ("20100101010000", "String")
    assert value(runs[3]) == ("20091231235900", "String")
    assert value(runs[4]) == ("20210528165542", "String")
    assert value(runs[5]) == ("20100101001000", "String")


def test_time_calculation_of_an_invalid_time_is_an_exception(flows):
    run = run_all(flows, [add_time("tc_bad", '"abc"', 1, "Days")])[0]
    assert run.exceptions == ["Input time is not a time: 'abc'."], run.exceptions
    assert value(run) is None


@pytest.mark.parametrize("strict", [True, False], ids=["strict", "compat"])
def test_time_calculation_text_amount_is_an_error_in_both_modes(flows, strict):
    run = run_all(flows, [add_time("tc_text_%s" % strict, "2010", "abc", "Days", strict=strict)])[0]
    assert len(run.exceptions) == 1 and "abc" in run.exceptions[0], run.exceptions


# --- Action_Time_Difference ---------------------------------------------------------------------------------------
def diff(name, first, second, unit=None):
    pars = dict(InputTime=first, InputTime2=second)
    if unit is not None:
        pars["Unit"] = unit
    return time_flow(name, "Action_Time_Difference", **pars)


def test_time_difference_in_each_unit(flows):
    runs = run_all(flows, [
        diff("td_days", "2015", "2010", "Days"),
        diff("td_seconds", "20210528165541", "20210528165440", "Seconds"),
        diff("td_negative", "2010", "2015", "Days"),
        diff("td_minutes_default", "2010", "2009"),           # no Unit in the flow: the default is Minutes
    ])
    assert value(runs[0]) == ("1826", "Integer")
    assert value(runs[1]) == ("61", "Integer")
    assert value(runs[2]) == ("-1826", "Integer")
    assert value(runs[3]) == ("525600", "Integer")


def test_time_difference_default_first_time_is_now(flows):
    run = run_all(flows, [time_flow("td_now", "Action_Time_Difference", InputTime2="2010", Unit="Days",
                                    InputTime="a_now")])[0]
    text, kind = value(run)
    assert kind == "Integer" and int(text) > 4000, text             # more than eleven years after 2010


@pytest.mark.parametrize("first, second, message", [
    ('"abc"', "2010", "First input time does not contain a time: 'abc'."),
    ("2010", '"abc"', "Second input time does not contain a time: 'abc'."),
], ids=["first", "second"])
def test_time_difference_of_an_invalid_time_is_an_exception(flows, first, second, message):
    run = run_all(flows, [diff("td_bad_%d" % len(first + second), first, second, "Days")])[0]
    assert run.exceptions == [message], run.exceptions
    assert value(run) is None
