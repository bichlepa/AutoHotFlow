"""WI-0110 (REQ-EDT-130): the window assistant with the real window source and the real mouse (gui tier). Written in WI-0110
and NOT run by the agent: the project owner runs it (doc/TEST-STRATEGY.md section 6, the VS Code task "Test: window
assistant"). The headless tests of the assistants are tests/ahk/editor_assist.test.ahk (fake source, no window shown).

The probe (tests/ahk/helpers/assist_gui_probe.ahk) shows a target window and opens the window assistant. This test moves the
real mouse onto the target and waits: the assistant follows the window under the mouse (the mouse rests there), takes it,
and the probe writes the values into a result file. The test checks the window title and the class of the target.

Not checked here: the OK button with a real click, the mouse tracker and the colour dialog (they are the owner's manual
check at 100 % and 225 %, doc/MANUAL-CHECKS.md), and the look of the windows.
"""

import ctypes
import subprocess
import sys
import time
from ctypes import wintypes
from pathlib import Path

import pytest

pytestmark = [pytest.mark.fault, pytest.mark.gui]

REPO = Path(__file__).resolve().parents[2]
PROBE = REPO / "tests" / "ahk" / "helpers" / "assist_gui_probe.ahk"
TARGET_TITLE = "AHF assist target"

user32 = ctypes.WinDLL("user32", use_last_error=True)
user32.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.FindWindowW.restype = wintypes.HWND
user32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.SetCursorPos.argtypes = [ctypes.c_int, ctypes.c_int]


def _find_target(timeout):
    """The handle of the target window, or 0 when it does not show within timeout seconds."""
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        hwnd = user32.FindWindowW(None, TARGET_TITLE)
        if hwnd:
            return hwnd
        time.sleep(0.2)
    return 0


def _read_result(path):
    values = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            values[key] = value
    return values


@pytest.mark.gui
def test_the_window_assistant_takes_the_window_under_the_mouse(tmp_path):
    """The window the mouse rests on is taken by the window assistant: its title and class are the values of the window,
    the assistant lists the windows of the desktop (not its own window) and nothing times out."""
    result = tmp_path / "assist_result.txt"
    proc = subprocess.Popen([sys.executable, str(REPO / "tools" / "ahkrun.py"), "--timeout", "120", str(PROBE), str(result)],
                            cwd=str(REPO))
    try:
        hwnd = _find_target(30)
        assert hwnd, "the target window of the probe did not show"
        rect = wintypes.RECT()
        assert user32.GetWindowRect(hwnd, ctypes.byref(rect))
        cx, cy = (rect.left + rect.right) // 2, (rect.top + rect.bottom) // 2
        # the mouse moves onto the target and rests there (the assistant reads a rest of two ticks)
        for step in range(6):
            user32.SetCursorPos(cx - 5 + step, cy)
            time.sleep(0.15)
        code = proc.wait(timeout=150)
    finally:
        if proc.poll() is None:
            proc.kill()
    assert code == 0, f"the probe ended with exit code {code}"
    values = _read_result(result)
    assert "timeout" not in values, "the assistant did not take the target in time"
    assert values.get("Wintitle") == TARGET_TITLE, values
    assert values.get("ahk_class") == "AutoHotkeyGUI", values
    assert values.get("ahk_exe", "").lower().startswith("autohotkey"), values
    assert values.get("excludeTitle") == "" and values.get("ExcludeText") == "", values
    assert values.get("ahk_id") == "" and values.get("ahk_pid") == "", "the unique IDs are not taken without the checkbox"
    assert int(values.get("listed", "0")) >= 2, "the windows of the desktop are listed"
