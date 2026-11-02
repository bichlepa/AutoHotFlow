"""WI-0128: end-to-end tests of the dialog elements Action_Input_Box, Action_Select_file and Action_Select_Folder with the
flow builder, in real sessions (supervisor, storage, engine, worker). The windows are answered by the test provider from
the script (support/dialogs.py): the input window (kind InputWindow), FileSelect and DirSelect. Nothing opens a window here.
The real input box of the v1 "Dialog test" is a gui test (test_corpus.py, the owner runs it).

The results are read from the flow (the output variable and A_UserAction, probes), the errors from the exception of the run
and the requests from the log of the provider (kind, args, role).
"""

import json

import pytest

from support.coreflows import run_all
from support.dialogs import DialogScript, answer, no_answer
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def input_flow(name, **pars):
    """trigger -> Input_Box -> probes of the output variable Typed and A_UserAction -> DONE"""
    fb = FlowBuilder(name)
    box = fb.action("Action_Input_Box", Varname="Typed", **pars)
    probe = fb.probe("Typed", "A_UserAction", location="thread")
    done = fb.action("Action_Do_nothing", name="DONE")
    fb.chain(fb.trigger(), box, probe, done)
    return fb


def file_flow(name, **pars):
    """trigger -> Select_file -> probe of the output variable picked -> DONE"""
    fb = FlowBuilder(name)
    select = fb.action("Action_Select_file", Varname="picked", **pars)
    probe = fb.probe("picked")
    done = fb.action("Action_Do_nothing", name="DONE")
    fb.chain(fb.trigger(), select, probe, done)
    return fb


def folder_flow(name, **pars):
    """trigger -> Select_Folder -> probe of the output variable picked -> DONE"""
    fb = FlowBuilder(name)
    select = fb.action("Action_Select_Folder", Varname="picked", **pars)
    probe = fb.probe("picked")
    done = fb.action("Action_Do_nothing", name="DONE")
    fb.chain(fb.trigger(), select, probe, done)
    return fb


# --- Input box ---------------------------------------------------------------------------------------------------------
def test_ok_sets_the_variable_and_asks_for_the_text_and_the_layout(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer({"result": "OK", "value": "Paul"}, kind="InputWindow"))
    run = run_all(flows, [input_flow("ib-ok", title="Name?", message="Your name", defaultText="Max",
                                     ButtonLabel="Go", Width=320, Height=240)])[0]
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert run.seen["Typed"].text == "Paul"
    assert run.seen["A_UserAction"].text == "ok"
    request = dialogs.requests()[0]
    assert request["kind"] == "InputWindow" and request["role"] == "worker"
    assert request["args"] == {"title": "Name?", "text": "Your name", "default": "Max", "mask": "", "rows": 1,
                               "buttonLabel": "Go", "cancelLabel": "", "width": 320, "height": 240, "timeoutMs": 0}


@pytest.mark.parametrize("pars, mask, rows", [
    (dict(OnlyNumbers=1), "Number", 1),
    (dict(MaskUserInput=1), "Password", 1),
    (dict(MultilineEdit=1, MultilineEditRows=3), "", 3),
    # the settings exclude a mask with several lines; when both are set by hand the digits win, then the mask
    (dict(MultilineEdit=1, MultilineEditRows=3, MaskUserInput=1), "Password", 3),
], ids=["digits", "mask", "lines", "mask-and-lines"])
def test_the_edit_field_options_reach_the_window(flows, pars, mask, rows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer({"result": "OK", "value": "1"}, kind="InputWindow"))
    run = run_all(flows, [input_flow("ib-field", **pars)])[0]
    assert run.reason == "finished" and not run.exceptions, run.steps
    args = dialogs.requests()[0]["args"]
    assert (args["mask"], args["rows"]) == (mask, rows)


def test_cancel_button_has_its_label_only_when_shown(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer({"result": "OK", "value": "x"}, kind="InputWindow"),
                   answer({"result": "OK", "value": "x"}, kind="InputWindow"))
    run_all(flows, [input_flow("ib-cancel-shown", ShowCancelButton=1, ButtonLabelCancel="Later"),
                    input_flow("ib-cancel-hidden", ShowCancelButton=0, ButtonLabelCancel="Later")])
    shown, hidden = [request["args"]["cancelLabel"] for request in dialogs.requests()]
    assert (shown, hidden) == ("Later", "")


@pytest.mark.parametrize("result, option, action, expected, message", [
    ("Cancel", "IfDismiss", "cancel", "normal", None),
    ("Cancel", "IfDismiss", "cancel", "exception", "User cancelled the dialog"),
    ("Close", "IfClose", "close", "normal", None),
    ("Close", "IfClose", "close", "exception", "User closed the dialog"),
])
def test_cancel_and_close_clear_the_variable_and_follow_their_option(flows, result, option, action, expected, message):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer({"result": result, "value": "typed"}, kind="InputWindow"))
    run = run_all(flows, [input_flow("ib-%s-%s" % (result, expected), ShowCancelButton=1, ButtonLabelCancel="Later",
                                     **{option: "Normal" if expected == "normal" else "Exception"})])[0]
    if expected == "normal":
        assert run.reason == "finished" and not run.exceptions, run.steps
        assert run.seen["Typed"].text == "" and run.seen["A_UserAction"].text == action
    else:
        assert run.exceptions and message in run.exceptions[0], run.steps


@pytest.mark.parametrize("on_timeout, expected", [("Normal", "normal"), ("Exception", "exception")])
def test_timeout_ends_with_the_result_on_timeout(flows, on_timeout, expected):
    """The window answers "Timeout" after the time of the element; A_UserAction is "timeout" (the help of v1, MIGRATION
    M-0168)."""
    dialogs = DialogScript(flows.datadir)
    dialogs.script(no_answer(kind="InputWindow"))
    run = run_all(flows, [input_flow("ib-timeout-%s" % on_timeout, IsTimeout="Timeout", TimeoutUnits=1, Unit="Seconds",
                                     OnTimeout=on_timeout)])[0]
    assert dialogs.requests()[0]["args"]["timeoutMs"] == 1000
    if expected == "normal":
        assert run.reason == "finished" and not run.exceptions, run.steps
        assert run.seen["Typed"].text == "" and run.seen["A_UserAction"].text == "timeout"
    else:
        assert run.exceptions and "Timeout reached" in run.exceptions[0], run.steps


# --- Select file -------------------------------------------------------------------------------------------------------
def test_chosen_file_is_the_variable_and_the_options_reach_the_dialog(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("C:\\data\\a.txt", kind="FileSelect"))
    run = run_all(flows, [file_flow("sf-one", title="Pick", folder="C:\\data", filter="Text (*.txt)",
                                    fileMustExist=1, PathMustExist=1)])[0]
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert run.seen["picked"].text == "C:\\data\\a.txt"
    args = dialogs.requests()[0]["args"]
    assert args == {"options": "3", "root": "C:\\data", "title": "Pick", "filter": "Text (*.txt)"}


def test_several_files_are_a_list_and_the_multi_option_is_passed(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer(["C:\\data\\a.txt", "C:\\data\\b.txt"], kind="FileSelect"))
    run = run_all(flows, [file_flow("sf-multi", MultiSelect=1, SaveButton=0)])[0]
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert json.loads(run.seen["picked"].text) == ["C:\\data\\a.txt", "C:\\data\\b.txt"]
    assert dialogs.requests()[0]["args"]["options"] == "M0"


def test_a_cancelled_file_dialog_is_an_exception(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("", kind="FileSelect"))
    run = run_all(flows, [file_flow("sf-cancel")])[0]
    assert run.exceptions and "User dismissed the dialog" in run.exceptions[0], run.steps


# --- Select folder -----------------------------------------------------------------------------------------------------
def test_chosen_folder_is_the_variable_and_upward_navigation_is_an_asterisk(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("C:\\data\\sub", kind="DirSelect"))
    run = run_all(flows, [folder_flow("df-one", title="Where?", folder="C:\\data", AllowUpward=1,
                                      ButtonNewFolder=1, EditField=1)])[0]
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert run.seen["picked"].text == "C:\\data\\sub"
    assert dialogs.requests()[0]["args"] == {"root": "*C:\\data", "options": 3, "prompt": "Where?"}


def test_without_upward_navigation_the_root_has_no_asterisk(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("C:\\data", kind="DirSelect"))
    run = run_all(flows, [folder_flow("df-no-upward", folder="C:\\data", AllowUpward=0)])[0]
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert dialogs.requests()[0]["args"]["root"] == "C:\\data"


def test_a_cancelled_folder_dialog_is_an_exception(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("", kind="DirSelect"))
    run = run_all(flows, [folder_flow("df-cancel")])[0]
    assert run.exceptions and "User dismissed the dialog" in run.exceptions[0], run.steps
