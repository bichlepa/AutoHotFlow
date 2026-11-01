"""WI-0126: end-to-end tests of the mouse and keyboard elements of the package Default: Click, Move mouse, Drag with mouse,
Get mouse position, Send keystrokes, Send keystrokes to control, Set lock key, Block user input and the condition Key is down.

The mouse, key, lock and input calls go through SystemOps (E0103): the test provider records each call with its arguments
and answers from a script, so the tests send no key, move no mouse, change no lock and block no input. Get mouse position
reads a fixed position of the script. Key is down reads the state of a key that a helper holds down (under the input
lock, as the input tests do). Send keystrokes to control sends its keys to an own test window (ControlSend, no focus).
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
from support.coreflows import answer, condition_flow, run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.system import SystemScript, value
from support.timing import scaled

# The key states of this module share one key (vk88) with the held-key test: one xdist group runs them one after another.
pytestmark = pytest.mark.xdist_group("input")

ROOT = Path(__file__).resolve().parents[2]
HELPERS = ROOT / "tests" / "integration" / "helpers"
AHKRUN = ROOT / "tools" / "ahkrun.py"
CREATE_NO_WINDOW = 0x08000000
VK_SCROLL = 0x91
UNASSIGNED_KEY = "vk88"                 # no window reacts to it (the key of the input tests)

user32 = ctypes.WinDLL("user32", use_last_error=True)
user32.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.FindWindowW.restype = wintypes.HWND
user32.FindWindowExW.argtypes = [wintypes.HWND, wintypes.HWND, wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.FindWindowExW.restype = wintypes.HWND
user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, ctypes.c_void_p]
user32.SendMessageW.restype = ctypes.c_ssize_t
user32.GetKeyState.argtypes = [ctypes.c_int]
user32.GetKeyState.restype = ctypes.c_short
WM_GETTEXT, WM_GETTEXTLENGTH = 0x000D, 0x000E


# --- helpers ----------------------------------------------------------------------------------------------------------
@pytest.fixture
def system(flows):
    """The script of the system provider: no answers, so every call returns the empty value and is only recorded."""
    script = SystemScript(flows.datadir)
    script.script({})
    return script


def element_flow(name, cls, probes=(), **pars):
    """trigger -> the element -> [a probe of variables]."""
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    parts = [fb.trigger(), el]
    if probes:
        parts.append(fb.probe(*probes))
    fb.chain(*parts)
    return fb


def calls(system, function):
    return [c for c in system.requests() if c["function"] == function]


def last_args(system, function):
    found = calls(system, function)
    assert found, system.requests()
    return found[-1]["args"]


def run_one(flows, fb, timeout=20):
    flow_id = flows.add(fb)
    return flows.run(flow_id, timeout=scaled(timeout))


class OwnWindow:
    """An own window of this test (helpers/own_window.ahk): its title, process and the two edit controls."""

    def __init__(self, title, proc, stop):
        self.title = title
        self.proc = proc
        self.stop = stop

    @property
    def hwnd(self):
        return user32.FindWindowW(None, self.title)

    def second_edit(self):
        first = user32.FindWindowExW(self.hwnd, None, "Edit", None)
        return user32.FindWindowExW(self.hwnd, first, "Edit", None)

    def text_of(self, hwnd):
        """The text of a control as its own window gives it (WM_GETTEXT), as the window tests read it."""
        length = user32.SendMessageW(hwnd, WM_GETTEXTLENGTH, 0, None)
        buffer = ctypes.create_unicode_buffer(length + 2)
        user32.SendMessageW(hwnd, WM_GETTEXT, length + 1, ctypes.cast(buffer, ctypes.c_void_p))
        return buffer.value

    def end(self):
        self.stop.write_text("stop", encoding="ascii")
        try:
            self.proc.wait(timeout=scaled(10))
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=scaled(10))


def start_window(tmp_path):
    """Starts an own window (helpers/own_window.ahk) and waits until it is shown; the test ends it."""
    title = "AhfMouseKeyTest-" + uuid.uuid4().hex
    ready, stop = tmp_path / ("ready-%s.txt" % title), tmp_path / ("stop-%s.txt" % title)
    args = [sys.executable, str(AHKRUN), "--timeout", "120", str(HELPERS / "own_window.ahk"), title, str(ready), str(stop)]
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
    own = start_window(tmp_path)
    yield own
    own.end()


def start_key_holder(tmp_path, key):
    """Holds the key down until end() (helpers/key_holder.ahk). The caller holds the input lock."""
    tag = uuid.uuid4().hex
    ready, stop = tmp_path / ("held-%s.txt" % tag), tmp_path / ("release-%s.txt" % tag)
    args = [sys.executable, str(AHKRUN), "--timeout", "120", str(HELPERS / "key_holder.ahk"), key, str(ready), str(stop)]
    proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                            creationflags=CREATE_NO_WINDOW)
    deadline = time.monotonic() + scaled(10)
    while not ready.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    assert ready.exists(), "the key holder did not start: %s" % proc.stderr.read()

    class Holder:
        def end(self):
            stop.write_text("release", encoding="ascii")
            try:
                proc.wait(timeout=scaled(10))
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=scaled(10))

    return Holder()


# --- Click ------------------------------------------------------------------------------------------------------------
def test_click_without_moving_clicks_at_the_mouse(flows, system):
    runs = run_all(flows, [element_flow("click", "Action_Click")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "Click") == ["Left 1"]


def test_click_at_coordinates_with_button_count_and_hold(flows, system):
    runs = run_all(flows, [element_flow("click_at", "Action_Click", Button="Right", ClickCount=2, DownUp="D",
                                        changePosition=1, CoordMode="Window", Xpos=10, Ypos=20, speed=2, delay=10,
                                        SendMode="Input")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "Click") == ["10 20 Right 2 D"]


def test_click_relative_to_the_current_mouse_position_adds_the_option_r(flows, system):
    runs = run_all(flows, [element_flow("click_rel", "Action_Click", changePosition=1, CoordMode="Relative", Xpos=3,
                                        Ypos=4, speed=2, delay=10, SendMode="Input")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "Click") == ["3 4 Left 1 R"]


def test_click_wheel_up_with_a_count_and_release_only(flows, system):
    runs = run_all(flows, [element_flow("wheel", "Action_Click", Button="WheelUp", ClickCount=3, DownUp="U")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "Click") == ["WheelUp 3 U"]


def test_click_with_a_count_that_is_no_number_is_an_exception(flows, system):
    runs = run_all(flows, [element_flow("click_bad", "Action_Click", ClickCount="1 +")])
    assert runs[0].exceptions, runs[0].steps
    assert not calls(system, "Click")


def test_a_failing_click_call_is_an_exception(flows, system):
    system.script({"Click": [{"error": "no mouse"}]})
    runs = run_all(flows, [element_flow("click_fails", "Action_Click")])
    assert runs[0].exceptions, runs[0].steps


# --- Move mouse and Drag with mouse -----------------------------------------------------------------------------------
def test_move_mouse_moves_to_the_absolute_coordinates_with_the_speed(flows, system):
    runs = run_all(flows, [element_flow("move", "Action_Move_Mouse", CoordMode="Screen", Xpos=100, Ypos=200, speed=2,
                                        delay=10, SendMode="Input")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "MouseMove") == [100, 200, 2]


def test_move_mouse_relative_adds_the_option_r(flows, system):
    runs = run_all(flows, [element_flow("move_rel", "Action_Move_Mouse", CoordMode="Relative", Xpos=5, Ypos=6, speed=50,
                                        delay=10, SendMode="Event")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "MouseMove") == [5, 6, 50, "R"]


def test_move_mouse_with_a_coordinate_that_is_no_number_is_an_exception(flows, system):
    runs = run_all(flows, [element_flow("move_bad", "Action_Move_Mouse", CoordMode="Screen", Xpos="1 +", Ypos=6,
                                        speed=2, delay=10, SendMode="Input")])
    assert runs[0].exceptions, runs[0].steps
    assert not calls(system, "MouseMove")


def test_drag_with_mouse_passes_the_start_and_the_end(flows, system):
    runs = run_all(flows, [element_flow("drag", "Action_Drag_With_Mouse", Button="Left", CoordMode="Screen",
                                        XposFrom=1, YposFrom=2, Xpos=3, Ypos=4, speed=2, delay=10, SendMode="Input")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "MouseClickDrag") == ["Left", 1, 2, 3, 4, 2]


def test_drag_relative_adds_the_option_r(flows, system):
    runs = run_all(flows, [element_flow("drag_rel", "Action_Drag_With_Mouse", Button="X2", CoordMode="Relative",
                                        XposFrom=1, YposFrom=2, Xpos=3, Ypos=4, speed=2, delay=10, SendMode="Play")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "MouseClickDrag") == ["X2", 1, 2, 3, 4, 2, "R"]


# --- Get mouse position -----------------------------------------------------------------------------------------------
def test_get_mouse_position_stores_the_window_and_the_control_of_the_fixed_position(flows, system):
    system.script({"MouseGetPos": [value([100, 200, 4242, 777])]})
    fb = element_flow("pos", "Action_Get_Mouse_Position", probes=["posX", "posY", "windowID", "controlID"],
                      WhetherGetWindowID=1, WhetherGetControlID=1, CoordMode="Screen")
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert {name: runs[0].seen[name].text for name in ["posX", "posY", "windowID", "controlID"]} == {
        "posX": "100", "posY": "200", "windowID": "4242", "controlID": "777"}
    assert last_args(system, "MouseGetPos") == [2], "the control is asked for its handle (flag 2)"


def test_get_mouse_position_without_ids_asks_for_the_position_only(flows, system):
    system.script({"MouseGetPos": [value([7, 8, 0, 0])]})
    fb = element_flow("pos_xy", "Action_Get_Mouse_Position", probes=["posX", "posY"], CoordMode="Client")
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert (runs[0].seen["posX"].text, runs[0].seen["posY"].text) == ("7", "8")
    assert last_args(system, "MouseGetPos") == [0]


# --- Send keystrokes --------------------------------------------------------------------------------------------------
def test_send_keystrokes_sends_the_text_with_the_send_mode(flows, system):
    runs = run_all(flows, [element_flow("send", "Action_Send_Keystrokes", KeysToSend="abc{Enter}", RawMode=0,
                                        SendMode="Play")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "Send") == ["abc{Enter}", "Play"]


def test_send_keystrokes_in_raw_mode_prefixes_the_raw_mode_key(flows, system):
    runs = run_all(flows, [element_flow("send_raw", "Action_Send_Keystrokes", KeysToSend="^a", RawMode=1,
                                        SendMode="Input")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "Send") == ["{Raw}^a", "Input"]


def test_a_failing_send_call_is_an_exception(flows, system):
    system.script({"Send": [{"error": "blocked"}]})
    runs = run_all(flows, [element_flow("send_fails", "Action_Send_Keystrokes", KeysToSend="a", RawMode=0,
                                        SendMode="Event")])
    assert runs[0].exceptions, runs[0].steps


# --- Set lock key -----------------------------------------------------------------------------------------------------
def test_set_caps_lock_on_calls_the_seam_with_the_state(flows, system):
    runs = run_all(flows, [element_flow("caps", "Action_Set_Lock_Key", WhichKey="CapsLock", Status="On")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "SetCapsLockState") == ["On"]


def test_set_num_lock_always_off_passes_the_forced_state(flows, system):
    runs = run_all(flows, [element_flow("num", "Action_Set_Lock_Key", WhichKey="NumLock", Status="AlwaysOff")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "SetNumLockState") == ["AlwaysOff"]


def test_toggle_scroll_lock_passes_the_opposite_of_the_current_state(flows, system):
    current = bool(user32.GetKeyState(VK_SCROLL) & 1)
    runs = run_all(flows, [element_flow("scroll", "Action_Set_Lock_Key", WhichKey="ScrollLock", Status="Toggle")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "SetScrollLockState") == [0 if current else 1]


# --- Block user input -------------------------------------------------------------------------------------------------
def test_block_user_input_blocks_and_unblocks_through_the_seam(flows, system):
    runs = run_all(flows, [element_flow("block", "Action_Block_User_Input", blockState="Block"),
                           element_flow("unblock", "Action_Block_User_Input", blockState="Unblock")])
    assert [bool(r.exceptions) for r in runs] == [False, False], [r.steps for r in runs]
    assert [c["args"] for c in calls(system, "BlockInput")] == [["On"], ["Off"]]


def test_the_block_is_released_when_the_worker_shuts_down(flows, system):
    runs = run_all(flows, [element_flow("block_keep", "Action_Block_User_Input", blockState="Block")])
    assert not runs[0].exceptions, runs[0].steps
    assert last_args(system, "BlockInput") == ["On"]
    flows.stop()                         # an orderly end: the worker gets sys.shutdown and releases the input (WI-0126)
    releases = [c for c in calls(system, "BlockInput") if c["args"] == ["Off"]]
    assert releases and releases[-1]["role"] == "worker", system.requests()


# --- Key is down (conditions) -----------------------------------------------------------------------------------------
def test_key_is_down_is_no_for_a_key_that_is_up(flows):
    runs = run_all(flows, [condition_flow("up", "Condition_Key_Is_Down", key=UNASSIGNED_KEY)])
    assert answer(runs[0]) == "NO", runs[0].steps


def test_key_is_down_physical_is_no_for_a_key_that_is_up(flows):
    runs = run_all(flows, [condition_flow("up_phys", "Condition_Key_Is_Down", key=UNASSIGNED_KEY,
                                          WhichKeyState="physical")])
    assert answer(runs[0]) == "NO", runs[0].steps


def test_key_is_down_physical_is_yes_while_another_process_holds_the_key(flows, tmp_path):
    """The logical state of a key is the state of the worker's own input queue: a key that another process sends is
    not seen there (measured: no). The physical state (GetKeyState "P") reads the state of the keyboard, which the
    holder changes, so this is the case that is tested. The logical state while held is not checked."""
    reason = inputlock.session_skip_reason(inputlock.input_desktop_open(), inputlock.logonui_running())
    if reason:
        pytest.skip(reason)
    with inputlock.input_lock():
        holder = start_key_holder(tmp_path, UNASSIGNED_KEY)
        try:
            runs = run_all(flows, [condition_flow("down", "Condition_Key_Is_Down", key=UNASSIGNED_KEY,
                                                  WhichKeyState="physical")])
        finally:
            holder.end()
    assert answer(runs[0]) == "YES", runs[0].steps


def test_a_key_name_that_does_not_exist_is_an_exception(flows):
    runs = run_all(flows, [condition_flow("bad_key", "Condition_Key_Is_Down", key="NoSuchKeyName")])
    assert answer(runs[0]) == "EXCEPTION", runs[0].steps


# --- Send keystrokes to control (own window, ControlSend) -------------------------------------------------------------
def window_pars(title, **extra):
    pars = {"Wintitle": title, "TitleMatchMode": 3, "IdentifyControlBy": "Class"}
    pars.update(extra)
    return pars


def test_send_keystrokes_to_control_types_into_the_control_of_the_own_window(flows, window):
    fb = element_flow("to_control", "Action_Send_Keystrokes_To_Control", probes=["A_ControlID"], KeysToSend="xyz",
                      RawMode=0, Control_identifier="Edit2", **window_pars(window.title))
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert "xyz" in window.text_of(window.second_edit()), "the keys reached the second edit control"
    assert runs[0].seen["A_ControlID"].text == str(window.second_edit())


def test_send_keystrokes_to_control_in_raw_mode_sends_the_text_as_it_is(flows, window):
    fb = element_flow("to_control_raw", "Action_Send_Keystrokes_To_Control", KeysToSend="{Enter}", RawMode=1,
                      Control_identifier="Edit2", **window_pars(window.title))
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert "{Enter}" in window.text_of(window.second_edit()), "raw mode sends the braces as text"


def test_send_keystrokes_to_a_missing_control_is_the_v1_exception(flows, window):
    fb = element_flow("to_missing", "Action_Send_Keystrokes_To_Control", KeysToSend="x", RawMode=0,
                      Control_identifier="Edit9", **window_pars(window.title))
    runs = run_all(flows, [fb])
    assert runs[0].exceptions == ["Error! Seeked control does not exist in the specified window"], runs[0].steps
