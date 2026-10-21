"""WI-0102 (REQ-EDT-110, REQ-EDT-080, REQ-TRG-030): the menu bar and a context menu of a real editor window, with real mouse
input (gui tier). Written in WI-0102 and NOT run by the agent: the project owner runs it (doc/TEST-STRATEGY.md section 6). The
same entries and actions are tested headless in tests/e2e/test_editor_menus.py.

The window is found and the mouse is driven the way tests/fault/test_editor_mouse_gui.py does it (the helpers are imported
from there). The menu bar has seven entries (Save, Run, Stop, Enable or Disable, Edit, Settings, Exit). A right click on an
empty place without a movement opens a standard popup menu (class #32768); the editor must answer while it is open
(E0077, HOW-TO gui-and-hotkeys: an open menu stops the threads of its process, so the test only checks the menu and its close).

Not checked here: the shortcuts Ctrl+Z, Ctrl+Y and Ctrl+S with real keys (headless in tests/e2e/test_editor_menus.py), the
items of the menus (the headless tests run them), the look of the menu texts.
"""

import ctypes
from ctypes import wintypes

import pytest

from faultkit import wait_until
from support import inputlock
from support.timing import scaled
from faultfixtures import chains  # noqa: F401  (fixture)
from test_editor_mouse_gui import (EditorWindowGeometry, MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP, _enable_dpi_awareness,
                                   _open_editor, _send_mouse, _skip_if_no_input)

pytestmark = pytest.mark.fault

user32 = ctypes.WinDLL("user32", use_last_error=True)
user32.GetMenu.argtypes = [wintypes.HWND]
user32.GetMenu.restype = ctypes.c_void_p
user32.GetMenuItemCount.argtypes = [ctypes.c_void_p]
user32.GetMenuItemCount.restype = ctypes.c_int
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.keybd_event.argtypes = [wintypes.BYTE, wintypes.BYTE, wintypes.DWORD, ctypes.c_void_p]

MENU_CLASS = "#32768"              # the class of a standard popup menu of Windows
VK_ESCAPE = 0x1B
KEYEVENTF_KEYUP = 0x0002
BAR_ITEMS = 7                      # Save, Run, Stop, Enable or Disable, Edit, Settings, Exit (REQ-EDT-110)


def _popup_menu_of(pid):
    """The visible popup menu window of the process pid, or 0."""
    found = []
    proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def visit(hwnd, _):
        cls = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(hwnd, cls, 64)
        owner = wintypes.DWORD(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if cls.value == MENU_CLASS and owner.value == pid and user32.IsWindowVisible(hwnd):
            found.append(hwnd)
        return True

    user32.EnumWindows(proc(visit), 0)
    return found[0] if found else 0


@pytest.mark.gui
def test_the_editor_window_has_the_menu_bar_and_a_right_click_opens_a_context_menu(chains):
    _skip_if_no_input()
    _enable_dpi_awareness()
    chain = chains("storage,engine", [])
    name, pid, hwnd, status = _open_editor(chain)
    menu = user32.GetMenu(hwnd)
    assert menu, "the window has no menu bar"
    assert user32.GetMenuItemCount(menu) == BAR_ITEMS, "Save, Run, Stop, Enable or Disable, Edit, Settings, Exit"
    geo = EditorWindowGeometry(hwnd, status)
    cx, cy = geo.canvas_center()
    with inputlock.input_lock():
        user32.SetForegroundWindow(hwnd)                  # best effort: the click goes to the window under the pointer
        assert user32.SetCursorPos(cx, cy), "SetCursorPos refused"
        assert _send_mouse(MOUSEEVENTF_RIGHTDOWN) == 1, "SendInput refused the button down"
        assert _send_mouse(MOUSEEVENTF_RIGHTUP) == 1, "SendInput refused the button up"
        assert wait_until(lambda: _popup_menu_of(pid), scaled(5)), "no context menu appeared"
        user32.keybd_event(VK_ESCAPE, 0, 0, 0)            # Esc closes the menu
        user32.keybd_event(VK_ESCAPE, 0, KEYEVENTF_KEYUP, 0)
    assert wait_until(lambda: not _popup_menu_of(pid), scaled(5)), "Esc did not close the context menu"
    assert chain.states()[name]["pid"] == pid, "the editor was restarted by the mouse input"
