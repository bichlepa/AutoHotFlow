"""WI-0113, REQ-USE-080 (part 2): the window of an unhandled error, in the real manager (not --headless). Gui tier: the test
opens real windows; run it alone, serially (doc/TEST-STRATEGY.md section 6). Agents never run it; the owner does.

The test drives the window like a user: the button "Notices" opens the list, the row of the error is selected, the button
"Show variables" opens the window "Variables at the error", whose list shows the variables of the branch. Then the engine
still answers while the window is open: the window blocks nothing.
"""

import ctypes
import json
from ctypes import wintypes

import pytest

from faultkit import request_ok, wait_until

from faultfixtures import chains  # noqa: F401  (fixture)
from support.flowbuilder import FlowBuilder

pytestmark = [pytest.mark.fault, pytest.mark.gui]

READY_S = 20.0
WINDOW_TITLE = "Manager"
NOTICES_TITLE = "Notices"
NOTICES_BUTTON = "Notices"
ERROR_TITLE = "Variables at the error"
SHOW_BUTTON = "Show variables"
BM_CLICK = 0xF5
LVM_GETITEMCOUNT = 0x1004
LVM_SETITEMSTATE = 0x102B
LVIS_SELECTED = 0x2
LVIS_FOCUSED = 0x1
LVIF_STATE = 0x8

user32 = ctypes.WinDLL("user32")      # not windll.user32: other test modules set argtypes on that shared object
user32.SendMessageW.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_size_t, ctypes.c_void_p]
user32.SendMessageW.restype = ctypes.c_ssize_t
user32.IsWindowVisible.argtypes = [ctypes.c_void_p]


class LVITEMW(ctypes.Structure):
    """The first fields of LVITEMW: enough for LVM_SETITEMSTATE."""
    _fields_ = [("mask", wintypes.UINT), ("iItem", ctypes.c_int), ("iSubItem", ctypes.c_int),
                ("state", wintypes.UINT), ("stateMask", wintypes.UINT)]


def _text(hwnd):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(hwnd, buf, 256)
    return buf.value


def _classname(hwnd):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(hwnd, buf, 256)
    return buf.value


def _top_windows(pid, title):
    """Handles of the top-level windows of a process with the given title."""
    found = []
    proc_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def visit(hwnd, _):
        owner = ctypes.c_ulong(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid and _text(hwnd) == title:
            found.append(hwnd)
        return True

    user32.EnumWindows(proc_type(visit), 0)
    return found


def _children(hwnd):
    out = []
    child_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def visit(child, _):
        out.append(child)
        return True

    user32.EnumChildWindows(hwnd, child_type(visit), 0)
    return out


def _rows(window):
    views = [c for c in _children(window) if _classname(c) == "SysListView32"]
    return user32.SendMessageW(views[0], LVM_GETITEMCOUNT, 0, 0) if views else -1, (views[0] if views else None)


@pytest.fixture
def error_chain(chains, datadir):
    """The manager with its window, and a flow that sets two variables and then ends with an unhandled exception."""
    fb = FlowBuilder("gui-variables")
    setup = fb.action("Action_TestSetVar", Steps=json.dumps([{"op": "set", "name": "gui_x", "value": "seen"}]))
    fb.chain(fb.trigger(), setup, fb.action("Action_TestThrow"))
    flow_id = fb.write(datadir)
    chain = chains("storage,engine,manager", [])
    chain.wait_ready(["storage", "engine", "manager"], timeout=READY_S)
    chain.wait_flows(timeout=READY_S)
    pid = chain.pid("manager")
    hwnds = wait_until(lambda: [h for h in _top_windows(pid, WINDOW_TITLE)], 10.0)
    assert hwnds, "no window '%s' for pid %d" % (WINDOW_TITLE, pid)
    return chain, pid, hwnds[0], flow_id


def test_the_variables_of_an_error_open_in_a_window_that_blocks_nothing(error_chain):
    chain, pid, hwnd, flow_id = error_chain
    assert wait_until(lambda: user32.IsWindowVisible(hwnd), 10.0)
    request_ok(chain.obs, "engine", "cmd.flow.start", {"flowId": flow_id})

    def button_in(window, text):
        found = [c for c in _children(window) if _text(c) == text]
        return found[0] if found else None

    # The button "Notices" opens the list (once: the list is found by its title, then its rows are counted).
    main_button = button_in(hwnd, NOTICES_BUTTON)
    assert main_button, "no button '%s' in the manager window" % NOTICES_BUTTON
    user32.SendMessageW(main_button, BM_CLICK, 0, 0)

    def list_with_the_row():
        found = _top_windows(pid, NOTICES_TITLE)
        return found[0] if found and _rows(found[0])[0] == 1 else None

    notices = wait_until(list_with_the_row, 15.0)
    assert notices, "the list of notices has no row for the unhandled exception"

    # Select the row (the list has one row) and press "Show variables".
    _count, view = _rows(notices)
    item = LVITEMW(LVIF_STATE, 0, 0, LVIS_SELECTED | LVIS_FOCUSED, LVIS_SELECTED | LVIS_FOCUSED)
    user32.SendMessageW(view, LVM_SETITEMSTATE, 0, ctypes.addressof(item))
    show = button_in(notices, SHOW_BUTTON)
    assert show, "no button '%s' in the list of notices" % SHOW_BUTTON
    user32.SendMessageW(show, BM_CLICK, 0, 0)

    def window_with_rows():
        found = _top_windows(pid, ERROR_TITLE)
        return found[0] if found and _rows(found[0])[0] >= 2 else None

    error_window = wait_until(window_with_rows, 15.0)
    assert error_window, "the window '%s' has no rows for the variables of the branch" % ERROR_TITLE
    assert wait_until(lambda: user32.IsWindowVisible(error_window), 10.0)

    # The window blocks nothing: the engine still answers while it is open.
    snapshot = request_ok(chain.obs, "engine", "cmd.engine.snapshot", {})
    assert snapshot["ok"], snapshot
