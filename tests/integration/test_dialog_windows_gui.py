"""WI-0056, gui tier: the real windows of the dialog elements. Only the project owner runs these (`-m gui`, VS Code task
"Test: gui"): windows appear for a moment, and the owner looks at the size and the sharpness above 100 % scaling
(REQ-USE-090). Agents do not run them.

Each test starts one AutoHotkey script that calls the product path (DialogWindow, no test provider) and prints what the
window returned. The windows end by their own timeout, so nothing is clicked.
"""

import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

SEAM = ROOT / "src" / "elements" / "base" / "Dialogs.ahk"


def _run(tmp_path, body, timeout=20):
    import ahkrun

    script = tmp_path / "window_check.ahk"
    script.write_text('#Requires AutoHotkey v2.0\n#Include %s\n%s\n' % (os.path.abspath(SEAM), body), encoding="utf-8")
    return ahkrun.run(str(script), timeout=timeout)


@pytest.mark.gui
def test_message_box_window_shows_and_times_out(tmp_path):
    """Action_Message_Box and Condition_Confirmation_Dialog: the window with two buttons ends by its timeout."""
    body = ('spec := Map("title", "WI-0056 gui check", "text", "This window closes by itself after 3 seconds. Check the '
            'size and the sharpness.", "buttons", [Map("id", "yes", "label", "Yes"), Map("id", "no", "label", "No")], '
            '"width", 360, "height", 200, "timeoutMs", 3000, "defaultId", "no")\n'
            'FileAppend(Dialogs.Window(spec), "*", "UTF-8")\n')
    code, out, err, dialogs = _run(tmp_path, body)
    assert code == 0, (code, out, err)
    assert "timeout" in out


@pytest.mark.gui
def test_debug_window_stays_open_for_the_owner_to_look_at(tmp_path):
    """Condition_Debug_Dialog: the window has no timeout. It must still be open when the check ends (exit 98 by the
    guard's timeout); the owner closes it by hand to see the layout. The read-only view shows one variable."""
    body = ('class GuiView {\n'
            '    ReadOnly := false\n'
            '    Rows() => [Map("text", "--- Instance variables ---", "name", "", "scope", ""), '
            'Map("text", "Foo", "name", "Foo", "scope", "instance")]\n'
            '    Text(name, convert := false) => "bar"\n'
            '    Type(name) => "normal"\n'
            '    Write(name, text, asObject := false, convert := false) => ""\n'
            '    Delete(name) => 1\n'
            '}\n'
            'FileAppend("opened", A_ScriptDir "\\opened.txt", "UTF-8")\n'
            'FileAppend(Dialogs.DebugWindow(GuiView()), "*", "UTF-8")\n')
    code, out, err, dialogs = _run(tmp_path, body, timeout=8)
    assert (tmp_path / "opened.txt").exists(), (code, out, err)
    assert code == 98, "the window was closed by the guard, not by a user: %s" % ((code, out, err),)


@pytest.mark.gui
def test_tooltip_is_shown_and_removed(tmp_path):
    """Action_Tooltip: a real tooltip for one second, then removed (exit 0, no window to close)."""
    body = ('Dialogs.ToolTip("WI-0056 gui check: tooltip", , , 13)\nSleep(1000)\nDialogs.ToolTip("", , , 13)\n'
            'FileAppend("removed", "*", "UTF-8")\n')
    code, out, err, dialogs = _run(tmp_path, body, timeout=20)
    assert code == 0 and "removed" in out, (code, out, err)
