"""WI-0106 (REQ-EDT-120, REQ-USE-090): the settings window of an element in a real editor window, with real mouse input
(gui tier). Written in WI-0106 and NOT run by the agent: the project owner runs it (doc/TEST-STRATEGY.md section 6). The same
calls are tested headless in tests/e2e/test_editor_settings.py (through cmd.test.form) and the window is built headless in
tests/ahk/editor_settings_window.test.ahk.

The test double-clicks the action of the skeleton flow on the canvas (its centre in flow units is (70, 262): the element is
at (0, 210), 140 by 105), finds the settings window of the editor process by its title ("Settings - ...") and closes it with
Esc, which is Cancel: nothing is changed. The geometry is the one of tests/fault/test_editor_menus_gui.py: the canvas is the
client area above the status bar, a flow point maps to the canvas by the view of the status bar (zoom, offset) and the DPI
of the window.

Not checked here: the change of a field and OK with real keys, the look of the window (fonts, the spacing), and the window at
225 % (the owner sets the display scaling to 225 % and runs this test again: doc/MANUAL-CHECKS.md section 9).
"""

import ctypes
from ctypes import wintypes

import pytest

from faultkit import wait_until
from support import inputlock
from support.timing import scaled
from faultfixtures import chains  # noqa: F401  (fixture)
from test_editor_mouse_gui import (EditorWindowGeometry, MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, _enable_dpi_awareness,
                                   _open_editor, _send_mouse, _skip_if_no_input, view_of)

pytestmark = [pytest.mark.fault, pytest.mark.gui]

user32 = ctypes.WinDLL("user32", use_last_error=True)
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetDpiForWindow.argtypes = [wintypes.HWND]
user32.GetDpiForWindow.restype = ctypes.c_uint
user32.keybd_event.argtypes = [wintypes.BYTE, wintypes.BYTE, wintypes.DWORD, ctypes.c_void_p]

VK_ESCAPE = 0x1B
KEYEVENTF_KEYUP = 0x0002
ACTION_CENTRE = (70, 262)          # flow units: the action of the skeleton flow (0, 210), 140 by 105


def _settings_window_of(pid):
    """The visible top-level window of the process pid whose title begins with "Settings - ", or 0."""
    found = []
    proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def visit(hwnd, _):
        owner = wintypes.DWORD(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value != pid or not user32.IsWindowVisible(hwnd):
            return True
        title = ctypes.create_unicode_buffer(256)
        user32.GetWindowTextW(hwnd, title, 256)
        if title.value.startswith("Settings - "):
            found.append(hwnd)
        return True

    user32.EnumWindows(proc(visit), 0)
    return found[0] if found else 0


def _click_at(hwnd_geo, x, y, count):
    """Moves the real mouse to the screen point and clicks the left button count times."""
    assert user32.SetCursorPos(x, y), "SetCursorPos refused"
    for _ in range(count):
        assert _send_mouse(MOUSEEVENTF_LEFTDOWN) == 1, "SendInput refused the button down"
        assert _send_mouse(MOUSEEVENTF_LEFTUP) == 1, "SendInput refused the button up"


@pytest.mark.gui
def test_a_double_click_opens_the_settings_window_and_esc_cancels_it(chains):
    """A double click on the action opens its settings in a window of their own (owned by the editor's process); Esc cancels
    them and the window goes; the editor is not restarted and the flow is not changed."""
    _skip_if_no_input()
    _enable_dpi_awareness()
    chain = chains("storage,engine", [])
    name, pid, hwnd, status = _open_editor(chain)
    geo = EditorWindowGeometry(hwnd, status)
    zoom, off_x, off_y = view_of(status)
    dpi = user32.GetDpiForWindow(hwnd) or 96
    scale = zoom * dpi / 96
    x = geo.left + round((ACTION_CENTRE[0] - off_x) * scale)
    y = geo.top + round((ACTION_CENTRE[1] - off_y) * scale)
    with inputlock.input_lock():
        user32.SetForegroundWindow(hwnd)               # best effort: the clicks go to the window under the pointer
        _click_at(geo, x, y, 2)
        assert wait_until(lambda: _settings_window_of(pid), scaled(5)), "no settings window after the double click"
        settings = _settings_window_of(pid)
        user32.SetForegroundWindow(settings)
        user32.keybd_event(VK_ESCAPE, 0, 0, 0)         # Esc is Cancel of the settings window
        user32.keybd_event(VK_ESCAPE, 0, KEYEVENTF_KEYUP, 0)
    assert wait_until(lambda: not _settings_window_of(pid), scaled(5)), "Esc did not close the settings window"
    assert chain.states()[name]["pid"] == pid, "the editor was restarted by the mouse input"
