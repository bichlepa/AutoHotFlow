"""WI-0073: the window of the real manager (src/manager/ManagerWindow.ahk), without --headless. Gui tier: the tests open a
real window; run them one at a time, serially (doc/TEST-STRATEGY.md section 6).

The window is found by its process and its title and driven like a user would: WM_CLOSE (the X button), a click on the
button "Exit" (BM_CLICK). What is checked: closing only hides the window and the application runs on (E0014, REQ-MGR-080),
`cmd.manager.show` shows it again, "Exit" ends the application cleanly, a crash of the manager leaves the rest running
(REQ-ROB-120 for the manager), and the tree holds the categories and the flows.
"""

import ctypes
import time

import psutil
import pytest

from faultkit import event, request_ok, wait_until

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = [pytest.mark.fault, pytest.mark.gui]

READY_S = 20.0
WINDOW_TITLE = "Manager"
WM_CLOSE = 0x10
BM_CLICK = 0xF5
TVM_GETCOUNT = 0x1105

user32 = ctypes.WinDLL("user32")      # not windll.user32: other test modules set argtypes on that shared object
user32.SendMessageW.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_size_t, ctypes.c_ssize_t]
user32.SendMessageW.restype = ctypes.c_ssize_t
user32.PostMessageW.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_size_t, ctypes.c_ssize_t]
user32.IsWindowVisible.argtypes = [ctypes.c_void_p]


def _text(hwnd):
    length = user32.GetWindowTextLengthW(hwnd)
    buf = ctypes.create_unicode_buffer(length + 1)
    user32.GetWindowTextW(hwnd, buf, length + 1)
    return buf.value


def _classname(hwnd):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(hwnd, buf, 256)
    return buf.value


def window_of(pid):
    """Handles of the top-level windows of a process with the title of the manager."""
    found = []
    proc_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def visit(hwnd, _):
        owner = ctypes.c_ulong(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid and _text(hwnd) == WINDOW_TITLE:
            found.append(hwnd)
        return True

    user32.EnumWindows(proc_type(visit), 0)
    return found


def children_of(hwnd):
    found = []
    proc_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def visit(child, _):
        found.append(child)
        return True

    user32.EnumChildWindows(hwnd, proc_type(visit), 0)
    return found


def visible(hwnd):
    return bool(user32.IsWindowVisible(hwnd))


@pytest.fixture
def window_chain(chains):
    chain = chains("storage,engine,manager", [])
    chain.wait_ready(["storage", "engine", "manager"], timeout=READY_S)
    chain.wait_flows(timeout=READY_S)
    pid = chain.pid("manager")
    hwnds = wait_until(lambda: window_of(pid), 10.0)
    assert hwnds, "no window '%s' for pid %d" % (WINDOW_TITLE, pid)
    return chain, pid, hwnds[0]


def test_the_window_opens_visible_and_the_tree_holds_the_categories_and_the_flow(window_chain):
    chain, pid, hwnd = window_chain
    assert wait_until(lambda: visible(hwnd), 10.0)
    tree = [c for c in children_of(hwnd) if _classname(c) == "SysTreeView32"]
    assert len(tree) == 1
    # the group of the flow and the flow (skeleton): the tree is filled by a timer after the snapshot
    assert wait_until(lambda: user32.SendMessageW(tree[0], TVM_GETCOUNT, 0, 0) >= 2, 10.0)
    snap = request_ok(chain.obs, "manager", "cmd.diag.snapshot", {})["snapshot"]
    assert snap["info"]["windowVisible"] == 1 and snap["info"]["flows"] == 1, snap["info"]
    assert snap["errors"]["count"] == 0, snap["errors"]


def test_closing_the_window_only_hides_it_and_the_application_runs_on(window_chain):
    chain, pid, hwnd = window_chain
    assert wait_until(lambda: visible(hwnd), 10.0)
    user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)               # the user clicks the X button
    assert wait_until(lambda: not visible(hwnd), 10.0), "the window is still visible: " + str(
        request_ok(chain.obs, "manager", "cmd.diag.snapshot", {})["snapshot"]["errors"])
    time.sleep(1.0)
    info = request_ok(chain.obs, "manager", "cmd.diag.snapshot", {})["snapshot"]["info"]
    assert info["windowVisible"] == 0 and info["redrawTimer"] == 0, info      # the redraw timer is off while hidden
    states = chain.states()
    assert states["manager"]["pid"] == pid and states["manager"]["state"] == "ready", states["manager"]
    assert states["engine"]["state"] == "ready" and states["storage"]["state"] == "ready"
    assert chain.rec.find(event("evt.process.exited", name="manager")) == []
    assert chain.rec.find(event("evt.process.crashed", name="manager")) == []
    assert chain.sup.proc.poll() is None, "the application ended"
    # flows still run while the window is hidden
    assert request_ok(chain.obs, "engine", "cmd.flow.start", {"flowId": "skeleton"})
    # the window comes back with cmd.manager.show (a second start, the tray menu)
    request_ok(chain.obs, "manager", "cmd.manager.show", {})
    assert wait_until(lambda: visible(hwnd), 10.0), "cmd.manager.show did not show the window"
    snap = request_ok(chain.obs, "manager", "cmd.diag.snapshot", {})["snapshot"]
    assert snap["info"]["windowVisible"] == 1 and snap["info"]["redrawTimer"] == 1, snap["info"]


def test_the_exit_button_ends_the_application_cleanly(window_chain):
    chain, pid, hwnd = window_chain
    assert wait_until(lambda: visible(hwnd), 10.0)
    buttons = [c for c in children_of(hwnd) if _classname(c) == "Button" and _text(c) == "Exit"]
    assert len(buttons) == 1, [(_classname(c), _text(c)) for c in children_of(hwnd)]
    user32.SendMessageW(buttons[0], BM_CLICK, 0, 0)
    code = chain.sup.wait_exit(timeout=25)
    assert code is not None, "the application did not end: " + chain.sup.text()
    assert code == 0, code


def test_a_crash_of_the_manager_leaves_the_rest_running_and_it_is_not_restarted(window_chain):
    chain, pid, hwnd = window_chain
    psutil.Process(pid).kill()
    crashed = chain.rec.wait(event("evt.process.crashed", name="manager"), timeout=10)
    assert crashed is not None and crashed[1]["payload"]["restart"] is False, crashed
    time.sleep(1.5)
    states = chain.states()
    assert states["engine"]["state"] == "ready" and states["storage"]["state"] == "ready", states
    assert states["manager"]["state"] != "ready"
    assert chain.sup.proc.poll() is None
    assert request_ok(chain.obs, "engine", "cmd.flow.start", {"flowId": "skeleton"})
