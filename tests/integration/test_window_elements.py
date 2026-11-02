"""WI-0125: end-to-end tests of the window and control elements of the package Default: Activate, Show, Hide, Close and
Move window, Minimize all windows, Get and Set control text, and the conditions Window active and Window exists.

Every window a test acts on is its own: a Gui of helpers/own_window.ahk with a unique title (two edit controls and a
button), started by the test and ended by the test. No window of the user is found, moved, closed or killed. Only the
test provider of SystemOps answers Minimize all windows (the real desktop is the owner's check). The flows run in a real
session (support/flowrun.py). Tests that take the focus hold the machine-wide input lock (doc/TEST-STRATEGY.md).
"""

import ctypes
import subprocess
import sys
import time
import uuid
from ctypes import wintypes
from pathlib import Path

import pytest

from support import inputlock
from support.coreflows import answer, branch, run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.system import SystemScript
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
HELPERS = ROOT / "tests" / "integration" / "helpers"
AHKRUN = ROOT / "tools" / "ahkrun.py"

user32 = ctypes.WinDLL("user32", use_last_error=True)
user32.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.FindWindowW.restype = wintypes.HWND
user32.FindWindowExW.argtypes = [wintypes.HWND, wintypes.HWND, wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.FindWindowExW.restype = wintypes.HWND
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetWindowTextW.restype = ctypes.c_int
user32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.GetWindowRect.restype = wintypes.BOOL
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.IsIconic.argtypes = [wintypes.HWND]
user32.IsZoomed.argtypes = [wintypes.HWND]
user32.GetForegroundWindow.restype = wintypes.HWND

user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, ctypes.c_void_p]
user32.SendMessageW.restype = ctypes.c_ssize_t
WM_GETTEXT, WM_GETTEXTLENGTH = 0x000D, 0x000E
CREATE_NO_WINDOW = 0x08000000
ERROR_NO_WINDOW = "Error! Seeked window does not exist"
ERROR_NO_CONTROL_IN_WINDOW = "Error! Seeked control does not exist in the specified window"
ERROR_NO_CONTROL = "Error! Seeked control does not exist"


class OwnWindow:
    """A window of this test: the helper process, its title and its handle (found by the title)."""

    def __init__(self, title, proc, stop):
        self.title = title
        self.proc = proc
        self.stop = stop

    @property
    def hwnd(self):
        return user32.FindWindowW(None, self.title)

    def edits(self):
        first = user32.FindWindowExW(self.hwnd, None, "Edit", None)
        second = user32.FindWindowExW(self.hwnd, first, "Edit", None)
        return first, second

    def text_of(self, hwnd):
        """The text of a control as its own window gives it (WM_GETTEXT). GetWindowTextW of another process gave the
        text from before a change in the test (HOW-TO, gui-and-hotkeys)."""
        length = user32.SendMessageW(hwnd, WM_GETTEXTLENGTH, 0, None)
        buffer = ctypes.create_unicode_buffer(length + 2)
        user32.SendMessageW(hwnd, WM_GETTEXT, length + 1, ctypes.cast(buffer, ctypes.c_void_p))
        return buffer.value

    def wait_gone(self):
        """True when the window and its process are gone (a bounded wait)."""
        deadline = time.monotonic() + scaled(20)
        while time.monotonic() < deadline:
            if not user32.FindWindowW(None, self.title) and self.proc.poll() is not None:
                return True
            time.sleep(0.05)
        return False

    def end(self):
        self.stop.write_text("stop", encoding="ascii")
        try:
            self.proc.wait(timeout=scaled(10))
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=scaled(10))


def start_window(tmp_path, noactivate=False):
    """Starts an own window (helpers/own_window.ahk) and waits until it is shown."""
    title = "AhfWindowTest-" + uuid.uuid4().hex
    ready, stop = tmp_path / ("ready-%s.txt" % title), tmp_path / ("stop-%s.txt" % title)
    args = [sys.executable, str(AHKRUN), "--timeout", "120", str(HELPERS / "own_window.ahk"), title, str(ready), str(stop)]
    if noactivate:
        args.append("noactivate")
    proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                            creationflags=CREATE_NO_WINDOW)
    window = OwnWindow(title, proc, stop)
    deadline = time.monotonic() + scaled(10)
    while not ready.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    if not ready.exists():
        window.end()
        raise AssertionError("the own window did not start: %s" % proc.stderr.read())
    return window


@pytest.fixture
def window(tmp_path):
    """One own window, shown without the focus (it does not take the focus from the user); ended at the end of the test.
    Only test_activate_brings_the_own_window_to_the_front needs the focus, and takes it under the input lock."""
    own = start_window(tmp_path, noactivate=True)
    yield own
    own.end()


@pytest.fixture
def window_inactive(tmp_path):
    """One own window shown without the focus (so the window is not the active one)."""
    own = start_window(tmp_path, noactivate=True)
    yield own
    own.end()


def window_pars(title, **extra):
    """The window identification of an own window: the title, exact, and the rest as the defaults of the setting."""
    pars = {"Wintitle": title, "TitleMatchMode": 3}
    pars.update(extra)
    return pars


def element_flow(name, steps, cond=None, probes=(), **cond_pars):
    """trigger -> the steps (class, parameters) -> [probes] -> [a condition with the markers YES and NO]."""
    fb = FlowBuilder(name)
    elements = [fb.action(cls, **pars) for cls, pars in steps]
    chain = [fb.trigger()] + elements
    if probes:
        chain.append(fb.probe(*probes))
    fb.chain(*chain)
    if cond:
        condition = fb.condition(cond, **cond_pars)
        fb.connect(chain[-1], condition)
        branch(fb, condition)
    return fb


def run_one(flows, fb, timeout=20):
    flow_id = flows.add(fb)
    return flows.run(flow_id, timeout=scaled(timeout))


def message_of(run):
    assert run.exceptions, run.steps
    return run.exceptions[0]


# --- visibility, state and position -------------------------------------------------------------------------------------

def test_hide_and_show_change_the_visibility_of_the_own_window(flows, window):
    run = run_one(flows, element_flow("hide", [("Action_Hide_Window", window_pars(window.title))]))
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert not user32.IsWindowVisible(window.hwnd), "the window is hidden"

    # a hidden window is found only with detect hidden window (v1 FindHiddenWindow)
    run = run_one(flows, element_flow("show", [("Action_Show_Window", window_pars(window.title, FindHiddenWindow=1))],
                                      probes=["A_WindowID"]))
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert user32.IsWindowVisible(window.hwnd), "the window is shown again"
    assert int(run.probe("A_WindowID").text) == window.hwnd, "A_WindowID is the window"


def test_a_hidden_window_is_found_only_with_detect_hidden_window(flows, window):
    hide = [("Action_Hide_Window", window_pars(window.title))]
    first = element_flow("hidden not detected", hide, cond="Condition_Window_Exists",
                         **window_pars(window.title, FindHiddenWindow=0))
    second = element_flow("hidden detected", [], cond="Condition_Window_Exists",
                          **window_pars(window.title, FindHiddenWindow=1))
    assert answer(run_one(flows, first)) == "NO", "a hidden window is not found by default"
    assert answer(run_one(flows, second)) == "YES", "with detect hidden window it is found"


def test_close_sends_the_close_message_and_kill_ends_the_process(flows, tmp_path):
    closing = start_window(tmp_path)
    try:
        run = run_one(flows, element_flow("close", [("Action_Close_Window",
                                                     window_pars(closing.title, WinCloseMethod="close"))]))
        assert run.reason == "finished" and not run.exceptions, run.steps
        assert closing.wait_gone(), "the window closed (its program ends with it)"
    finally:
        closing.end()

    killed = start_window(tmp_path)
    try:
        run = run_one(flows, element_flow("kill", [("Action_Close_Window",
                                                    window_pars(killed.title, WinCloseMethod="kill"))]))
        assert run.reason == "finished" and not run.exceptions, run.steps
        assert killed.wait_gone(), "kill ended the process of the window"
    finally:
        killed.end()


def test_move_sets_the_position_size_and_state_of_the_own_window(flows, window):
    if user32.GetDpiForSystem() != 96:
        pytest.skip("the desktop is not at 100 %: the coordinates are checked by the owner (DPI, not checked here)")
    move = {"WinMoveEvent": "Move", "Xpos": "10", "Ypos": "20", "Width": "300", "Height": "200"}
    run = run_one(flows, element_flow("move", [("Action_Move_Window", window_pars(window.title, **move))]))
    assert run.reason == "finished" and not run.exceptions, run.steps
    rect = wintypes.RECT()
    user32.GetWindowRect(window.hwnd, ctypes.byref(rect))
    assert (rect.left, rect.top, rect.right, rect.bottom) == (10, 20, 310, 220), "the window has the given rectangle"

    for event, check in [("Minimize", lambda h: user32.IsIconic(h)), ("Maximize", lambda h: user32.IsZoomed(h)),
                         ("Restore", lambda h: not user32.IsIconic(h) and not user32.IsZoomed(h))]:
        run = run_one(flows, element_flow(event, [("Action_Move_Window", window_pars(window.title,
                                                                                    WinMoveEvent=event))]))
        assert run.reason == "finished" and not run.exceptions, (event, run.steps)
        assert check(window.hwnd), event


def test_move_checks_the_size_only_for_the_move_event(flows, window):
    """An empty coordinate is no exception for Maximize (v1 evaluates the coordinates for Move only), and an exception for Move."""
    run = run_one(flows, element_flow("maximize empty", [("Action_Move_Window", window_pars(
        window.title, WinMoveEvent="Maximize", Xpos="", Ypos="", Width="", Height=""))]))
    assert run.reason == "finished" and not run.exceptions, run.steps
    run = run_one(flows, element_flow("move empty", [("Action_Move_Window", window_pars(
        window.title, WinMoveEvent="Move", Xpos="", Ypos="0", Width="1", Height="1"))]))
    assert "is not a number" in message_of(run), run.exceptions


def test_minimize_all_windows_is_recorded_by_the_provider(flows):
    system = SystemScript(flows.datadir)
    system.script({})
    fb = element_flow("minimize", [("Action_Minimize_all_windows", {"WinMinimizeAllEvent": "Minimize"}),
                                   ("Action_Minimize_all_windows", {"WinMinimizeAllEvent": "Undo"})])
    run = run_one(flows, fb)
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert [c["function"] for c in system.requests()] == ["WinMinimizeAll", "WinMinimizeAllUndo"]


# --- the focus: the input lock is held (doc/TEST-STRATEGY.md) -------------------------------------------------------

@pytest.mark.xdist_group("input")
def test_activate_brings_the_own_window_to_the_front(flows, window_inactive):
    reason = inputlock.session_skip_reason(inputlock.input_desktop_open(), inputlock.logonui_running())
    if reason:
        pytest.skip(reason)
    with inputlock.input_lock():
        before = element_flow("active before", [], cond="Condition_Window_Active",
                              **window_pars(window_inactive.title))
        assert answer(run_one(flows, before)) == "NO", "the window was shown without the focus"
        activate = element_flow("activate", [("Action_Activate_Window", window_pars(window_inactive.title))],
                                cond="Condition_Window_Active", **window_pars(window_inactive.title))
        assert answer(run_one(flows, activate)) == "YES", "the element waited for the window to become active"
        assert user32.GetForegroundWindow() == window_inactive.hwnd


# --- missing windows and the identification -------------------------------------------------------------------------

def test_a_missing_window_is_no_for_the_conditions_and_an_exception_for_the_actions(flows):
    missing = window_pars("AhfNoSuchWindow-" + uuid.uuid4().hex)
    builders = [
        element_flow("exists", [], cond="Condition_Window_Exists", **missing),
        element_flow("active", [], cond="Condition_Window_Active", **missing),
        element_flow("activate", [("Action_Activate_Window", missing)]),
        element_flow("hide", [("Action_Hide_Window", missing)]),
        element_flow("close", [("Action_Close_Window", missing)]),
    ]
    results = run_all(flows, builders)
    assert [answer(results[0]), answer(results[1])] == ["NO", "NO"]
    for run in results[2:]:
        assert message_of(run) == ERROR_NO_WINDOW, run.exceptions


def test_an_empty_window_identification_is_an_exception(flows):
    run = run_one(flows, element_flow("empty", [], cond="Condition_Window_Exists", Wintitle="", winText=""))
    assert message_of(run) == "No window specified", run.exceptions


# --- controls -------------------------------------------------------------------------------------------------------

def control_pars(window, by, identifier, **extra):
    pars = window_pars(window.title, IdentifyControlBy=by, Control_identifier=identifier)
    pars.update(extra)
    return pars


def test_get_control_text_finds_the_control_by_class_text_and_handle(flows, window):
    first, second = window.edits()
    builders = [
        element_flow("class", [("Action_Get_Control_Text", control_pars(window, "Class", "Edit1", Varname="ControlText"))],
                     probes=["ControlText", "A_ControlID", "A_WindowID"]),
        element_flow("text", [("Action_Get_Control_Text", control_pars(window, "Text", "second", ControlTextMatchMode=3,
                                                                       Varname="ControlText"))],
                     probes=["ControlText", "A_ControlID"]),
        element_flow("handle", [("Action_Get_Control_Text", {"IdentifyControlBy": "ID", "Control_identifier": str(second),
                                                             "Varname": "ControlText"})],
                     probes=["ControlText", "A_ControlID"]),
    ]
    results = run_all(flows, builders)
    for run in results:
        assert run.reason == "finished" and not run.exceptions, run.steps
    assert results[0].seen["ControlText"].text == "AHF own text"
    assert results[0].seen["A_ControlID"].text == str(first)
    assert results[0].seen["A_WindowID"].text == str(window.hwnd)
    assert results[1].seen["ControlText"].text == "second"
    assert results[2].seen["ControlText"].text == "second"
    assert results[2].seen["A_ControlID"].text == str(second)


def test_the_text_of_a_control_uses_the_match_mode_of_the_setting(flows, window):
    builders = [
        element_flow("contains", [("Action_Get_Control_Text", control_pars(window, "Text", "ond", ControlTextMatchMode=2,
                                                                          Varname="ControlText"))],
                     probes=["ControlText"]),
        element_flow("exact", [("Action_Get_Control_Text", control_pars(window, "Text", "ond", ControlTextMatchMode=3,
                                                                       Varname="ControlText"))]),
    ]
    contains, exact = run_all(flows, builders)
    assert contains.reason == "finished" and not contains.exceptions, contains.steps
    assert contains.seen["ControlText"].text == "second"
    assert message_of(exact) == ERROR_NO_CONTROL_IN_WINDOW, exact.exceptions


def test_set_control_text_changes_the_edit_control(flows, window):
    first, _second = window.edits()
    run = run_one(flows, element_flow("set", [("Action_Set_control_text", control_pars(
        window, "Class", "Edit1", Text="changed by the test"))]))
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert window.text_of(first) == "changed by the test"


def test_control_errors_are_the_v1_texts(flows, window):
    builders = [
        element_flow("no control", [("Action_Get_Control_Text", control_pars(window, "Class", "Edit9",
                                                                             Varname="ControlText"))]),
        element_flow("no window", [("Action_Get_Control_Text", control_pars(
            window, "Class", "Edit1", Wintitle="AhfNoSuchWindow-" + uuid.uuid4().hex, Varname="ControlText"))]),
        element_flow("no handle", [("Action_Set_control_text", {"IdentifyControlBy": "ID", "Control_identifier": "0",
                                                                "Text": "x"})]),
        element_flow("no identification", [("Action_Set_control_text", {"IdentifyControlBy": "Class",
                                                                        "Control_identifier": "Edit1", "Text": "x"})]),
    ]
    results = run_all(flows, builders)
    assert message_of(results[0]) == ERROR_NO_CONTROL_IN_WINDOW
    assert message_of(results[1]) == ERROR_NO_WINDOW
    assert message_of(results[2]) == ERROR_NO_CONTROL
    assert message_of(results[3]) == "No window specified"
