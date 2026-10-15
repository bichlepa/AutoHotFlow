"""WI-0051 (E0038): dialogs of elements go through the indirection Dialogs.*; the test entries answer them from a script.

A real session (flow runner): a worker element shows a dialog and exports the answer. Nothing opens a window.
"""

import pytest

from support.dialogs import DialogScript, answer, no_answer
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def _dialog_flow(*steps):
    """A flow with one test element per step (a dict of its parameters), run one after the other."""
    fb = FlowBuilder("dialogs")
    elements = [fb.action("Action_TestDialogWorker", **step) for step in steps]
    fb.chain(fb.trigger(), *elements)
    return fb


def _export(flows, tag, name="result"):
    pair = flows.wait_var("global_dialog_%s_%s" % (tag, name))
    assert pair is not None, "the element %s exported no %s" % (tag, name)
    return pair[1]


def test_a_worker_element_gets_the_scripted_answer_and_the_request_is_logged(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("Yes"), answer({"result": "OK", "value": "typed"}), answer(["C:\a.txt", "C:\b.txt"]),
                   answer("C:\folder"))
    flow = _dialog_flow(
        dict(Tag="m", Kind="MsgBox", Text="Really?", Title="Question", Options="YesNo"),
        dict(Tag="i", Kind="InputBox", Text="Name?", Title="Input"),
        dict(Tag="f", Kind="FileSelect", Title="Pick", Options="M"),
        dict(Tag="d", Kind="DirSelect", Text="Folder?"),
        dict(Tag="t", Kind="ToolTip", Text="hint"))
    run = flows.run(flows.add(flow), timeout=30)
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert _export(flows, "m") == "Yes"
    assert (_export(flows, "i"), _export(flows, "i", "value")) == ("OK", "typed")
    assert _export(flows, "f") == "C:\a.txt|C:\b.txt"
    assert _export(flows, "d") == "C:\folder"
    assert _export(flows, "t") == "shown"
    requests = dialogs.requests()
    assert [r["kind"] for r in requests] == ["MsgBox", "InputBox", "FileSelect", "DirSelect", "ToolTip"]
    assert requests[0]["args"] == {"text": "Really?", "title": "Question", "options": "YesNo"}
    assert [r["scripted"] for r in requests] == [True, True, True, True, False], "a ToolTip takes no entry"
    assert {r["role"] for r in requests} == {"worker"}, "the dialogs ran in a worker, not in the engine"


def test_a_dialog_without_an_answer_returns_timeout_after_its_time_option(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(no_answer(), no_answer())
    flow = _dialog_flow(dict(Tag="m", Kind="MsgBox", Text="anyone?", Options="T1"),
                        dict(Tag="i", Kind="InputBox", Text="anyone?", Options="T1"))
    run = flows.run(flows.add(flow), timeout=30)
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert _export(flows, "m") == "Timeout"
    assert _export(flows, "i") == "Timeout"


def test_a_dialog_the_script_did_not_expect_fails_the_element_instead_of_blocking(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("OK", kind="InputBox"))       # the script waits for an InputBox, a MsgBox comes
    flow = _dialog_flow(dict(Tag="a", Kind="MsgBox", Text="wrong"))
    run = flows.run(flows.add(flow), timeout=30)
    assert run.exceptions and "script has InputBox" in run.exceptions[0], run.steps

    # no entry left at all
    flow2 = _dialog_flow(dict(Tag="b", Kind="MsgBox", Text="nobody scripted this"))
    run2 = flows.run(flows.add(flow2), timeout=30)
    assert run2.exceptions and "no answer scripted" in run2.exceptions[0], run2.steps
    assert [r["scripted"] for r in dialogs.requests()] == [True, False]


@pytest.mark.slow
def test_a_pending_dialog_is_ended_by_the_stop_of_the_flow(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(no_answer())
    flow = _dialog_flow(dict(Tag="m", Kind="MsgBox", Text="never answered"))
    run = flows.begin(flow)
    flows.request_ok("engine", "cmd.flow.stop", {"flowId": run.flow_id})
    flows.wait(run, timeout=10)
    assert run.reason == "flow.stop"


@pytest.mark.gui
def test_the_product_path_opens_the_real_dialog(tmp_path):
    """Only the project owner runs this (a window appears for a moment). The product has no provider, so
    Dialogs.MsgBox opens the real MsgBox; the dialog guard of ahkrun catches it."""
    import os
    import sys
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
    import ahkrun
    seam = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "elements", "base", "Dialogs.ahk")
    script = tmp_path / "product_dialog.ahk"
    script.write_text('#Requires AutoHotkey v2.0\n#Include %s\nDialogs.MsgBox("real dialog of the product", "WI-0051")\n'
                      % os.path.abspath(seam), encoding="utf-8")
    code, out, err, dialogs = ahkrun.run(str(script), timeout=20)
    assert code == 97
    assert any("real dialog of the product" in " ".join(d.texts) for d in dialogs)
