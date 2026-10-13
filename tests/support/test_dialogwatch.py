"""Tests for tools/ahkrun.py and the dialog watcher: blocked scripts must not hang the run."""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))

import ahkrun  # noqa: E402
import pytest  # noqa: E402

from ahk import find_ahk_exe  # noqa: E402

pytestmark = pytest.mark.skipif(find_ahk_exe()[0] is None, reason="AutoHotkey v2 not installed")


def _script(tmp_path, body):
    p = tmp_path / "t.ahk"
    p.write_text("#Requires AutoHotkey v2.0\n" + body + "\n", encoding="utf-8")
    return str(p)


def test_ok_script_exit_zero(tmp_path):
    code, out, err, dialogs = ahkrun.run(_script(tmp_path, 'FileAppend("hi", "*")'), timeout=20)
    assert code == 0 and out == "hi" and not dialogs


def test_load_error_goes_to_stderr_without_dialog(tmp_path):
    code, out, err, dialogs = ahkrun.run(_script(tmp_path, "class TimeoutError extends Error {\n}"), timeout=20)
    assert code != 0 and not dialogs
    assert "conflicts with an existing Class" in err and "TimeoutError" in err


@pytest.mark.gui
def test_runtime_error_dialog_is_captured(tmp_path):
    code, out, err, dialogs = ahkrun.run(_script(tmp_path, 'x := Map()\nx["a"].foo()'), timeout=20)
    assert code == 97
    assert any("Item has no value" in " ".join(d.texts) for d in dialogs)
    assert dialogs[0].png_path and os.path.getsize(dialogs[0].png_path) > 1000


@pytest.mark.gui
def test_msgbox_is_captured_and_closed(tmp_path):
    code, out, err, dialogs = ahkrun.run(_script(tmp_path, 'MsgBox("blocking box")'), timeout=20)
    assert code == 97
    assert any("blocking box" in " ".join(d.texts) for d in dialogs)


def test_timeout_kills_tree(tmp_path):
    code, out, err, dialogs = ahkrun.run(_script(tmp_path, "Persistent()"), timeout=2)
    assert code == 98
