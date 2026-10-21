"""WI-0109 (REQ-EDT-140): the flow settings window of a real editor window (gui tier). Written in WI-0109 and NOT run by the agent:
the project owner runs it (doc/TEST-STRATEGY.md section 6). The calls of the dialog are tested headless in
tests/e2e/test_editor_flow_settings.py, the window is built headless in tests/ahk/editor_flow_settings_window.test.ahk.

The entry Settings of the menu bar is the sixth entry (Save, Run, Stop, Enable or Disable, Edit, Settings). The test opens the
menu with F10 (the first entry is selected), moves right five times and presses Enter: the dialog must open as a window with the
title "Flow settings - ..." of the editor process. Esc is Cancel: the window closes and the editor keeps running.

Not checked here: the look of the window (fonts, spacing), the folder dialog, and a change with the mouse (the owner's manual check).
"""

import ctypes
from ctypes import wintypes

import pytest

from faultkit import wait_until
from support import inputlock
from support.timing import scaled
from faultfixtures import chains  # noqa: F401  (fixture)
from test_editor_mouse_gui import _enable_dpi_awareness, _open_editor, _skip_if_no_input

pytestmark = [pytest.mark.fault, pytest.mark.gui]

user32 = ctypes.WinDLL("user32", use_last_error=True)
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.keybd_event.argtypes = [wintypes.BYTE, wintypes.BYTE, wintypes.DWORD, ctypes.c_void_p]

VK_RETURN = 0x0D
VK_ESCAPE = 0x1B
VK_F10 = 0x79
VK_RIGHT = 0x27
KEYEVENTF_KEYUP = 0x0002
SETTINGS_INDEX = 5          # Save, Run, Stop, Enable or Disable, Edit, Settings: moved to from the first entry by five steps


def _flow_settings_window_of(pid):
    """The visible top-level window of the process pid whose title begins with "Flow settings - ", or 0."""
    found = []
    proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def visit(hwnd, _):
        owner = wintypes.DWORD(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value != pid or not user32.IsWindowVisible(hwnd):
            return True
        title = ctypes.create_unicode_buffer(256)
        user32.GetWindowTextW(hwnd, title, 256)
        if title.value.startswith("Flow settings - "):
            found.append(hwnd)
        return True

    user32.EnumWindows(proc(visit), 0)
    return found[0] if found else 0


def _key(vk):
    user32.keybd_event(vk, 0, 0, 0)
    user32.keybd_event(vk, 0, KEYEVENTF_KEYUP, 0)


def test_the_settings_entry_opens_the_flow_settings_window_and_esc_cancels_it(chains):
    _skip_if_no_input()
    _enable_dpi_awareness()
    chain = chains("storage,engine", [])
    name, pid, hwnd, status = _open_editor(chain)
    with inputlock.input_lock():
        user32.SetForegroundWindow(hwnd)            # best effort: the keys go to the foreground window
        _key(VK_F10)                                # the menu bar: the first entry is selected
        for _ in range(SETTINGS_INDEX):
            _key(VK_RIGHT)
        _key(VK_RETURN)                             # Settings
    assert wait_until(lambda: _flow_settings_window_of(pid), scaled(10)), "no flow settings window appeared"
    with inputlock.input_lock():
        _key(VK_ESCAPE)                             # Cancel: nothing is changed
    assert wait_until(lambda: not _flow_settings_window_of(pid), scaled(5)), "Esc did not close the window"
    assert chain.states()[name]["pid"] == pid, "the editor was restarted by the keys"
