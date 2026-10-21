"""WI-0101, REQ-EDT-080 (delete, cut, copy and paste), E0091 (the Windows clipboard in a format of AutoHotFlow only): the
editor's keys Del, Ctrl+X, Ctrl+C and Ctrl+V and the trash button under the real supervisor, headless. The keys go through
cmd.test.key, the trash button through cmd.test.mouse; the content is checked in the engine's definition (cmd.flow.get)
after the editor's patch has been answered (settled).

The clipboard is the real Windows clipboard, because the editor uses it (no test seam for it: the two editors of a test are
two processes). The fixture saves every format that holds plain memory and restores it after each test; the formats that
hold handles (bitmaps, metafiles, palettes) cannot be copied as memory and are not kept. All tests of this file share one
xdist group, so they never use the clipboard at the same time.

Deterministic: a test waits for a condition of the editor or of the engine (wait_until), never for a fixed time.
"""

import contextlib
import ctypes
import time
from ctypes import wintypes

import pytest

from support.timing import scaled
from test_manager import FLOW, wait_until
from test_manager_editor import edit_results, finish, start_manager
from test_editor import editor_state, open_editor, render, write_flow
from test_editor_draft import settled, step
from test_editor_select import ACTION, CONN_AL, CONN_TA, EMPTY, LAST, TRIGGER, canvas, click, selection, start

pytestmark = pytest.mark.xdist_group("clipboard")

EDITOR = "editor:" + FLOW
SECOND = "second"
SECOND_EDITOR = "editor:" + SECOND
CF_UNICODETEXT = 13
GMEM_MOVEABLE = 0x0002
# the formats that hold a handle, not memory: a fixture cannot copy them, so it does not keep them
HANDLE_FORMATS = {2, 3, 9, 14, 0x80, 0x82, 0x83, 0x8E}

user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
user32.OpenClipboard.argtypes = [wintypes.HWND]
user32.OpenClipboard.restype = wintypes.BOOL
user32.CloseClipboard.restype = wintypes.BOOL
user32.EmptyClipboard.restype = wintypes.BOOL
user32.EnumClipboardFormats.argtypes = [wintypes.UINT]
user32.EnumClipboardFormats.restype = wintypes.UINT
user32.GetClipboardData.argtypes = [wintypes.UINT]
user32.GetClipboardData.restype = ctypes.c_void_p
user32.SetClipboardData.argtypes = [wintypes.UINT, ctypes.c_void_p]
user32.SetClipboardData.restype = ctypes.c_void_p
user32.IsClipboardFormatAvailable.argtypes = [wintypes.UINT]
user32.IsClipboardFormatAvailable.restype = wintypes.BOOL
user32.RegisterClipboardFormatW.argtypes = [wintypes.LPCWSTR]
user32.RegisterClipboardFormatW.restype = wintypes.UINT
user32.CreateWindowExW.argtypes = [wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD, ctypes.c_int,
                                   ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.HWND, wintypes.HMENU,
                                   wintypes.HINSTANCE, wintypes.LPVOID]
user32.CreateWindowExW.restype = wintypes.HWND
user32.DestroyWindow.argtypes = [wintypes.HWND]
kernel32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
kernel32.GlobalAlloc.restype = ctypes.c_void_p
kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
kernel32.GlobalLock.restype = ctypes.c_void_p
kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
kernel32.GlobalSize.argtypes = [ctypes.c_void_p]
kernel32.GlobalSize.restype = ctypes.c_size_t
kernel32.GlobalFree.argtypes = [ctypes.c_void_p]


@contextlib.contextmanager
def open_clipboard(owner=None):
    """The clipboard open for this process (a bounded retry: the editor may hold it for a moment). owner: a window of this
    process; another process gets the clipboard busy while it is open (the editor's owner window, WinClipboard.Owner)."""
    for _ in range(100):
        if user32.OpenClipboard(owner):
            break
        time.sleep(0.01)
    else:
        raise AssertionError("the clipboard stays busy")
    try:
        yield
    finally:
        user32.CloseClipboard()


@contextlib.contextmanager
def clipboard_owner():
    """A hidden window of this process: the owner of the clipboard while a test holds it open."""
    hwnd = user32.CreateWindowExW(0, "Static", "test clipboard owner", 0, 0, 0, 0, 0, None, None, None, None)
    assert hwnd, "no window for the clipboard owner"
    try:
        yield hwnd
    finally:
        user32.DestroyWindow(hwnd)


def snapshot():
    """Every format that holds memory: [(format, bytes)]."""
    items = []
    with open_clipboard():
        fmt = 0
        while True:
            fmt = user32.EnumClipboardFormats(fmt)
            if fmt == 0:
                break
            if fmt in HANDLE_FORMATS:
                continue
            handle = user32.GetClipboardData(fmt)
            if not handle:
                continue
            size = kernel32.GlobalSize(handle)
            ptr = kernel32.GlobalLock(handle)
            data = ctypes.string_at(ptr, size) if ptr else None
            kernel32.GlobalUnlock(handle)
            if data is not None:
                items.append((fmt, data))
    return items


def restore(items):
    with open_clipboard():
        user32.EmptyClipboard()
        for fmt, data in items:
            handle = kernel32.GlobalAlloc(GMEM_MOVEABLE, max(len(data), 1))
            ptr = kernel32.GlobalLock(handle)
            ctypes.memmove(ptr, data, len(data))
            kernel32.GlobalUnlock(handle)
            if not user32.SetClipboardData(fmt, handle):
                kernel32.GlobalFree(handle)


def set_text(text):
    """Puts a text (UTF-16) into the clipboard, as another program would."""
    data = (text + "\0").encode("utf-16-le")
    with open_clipboard():
        user32.EmptyClipboard()
        handle = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(data))
        ctypes.memmove(kernel32.GlobalLock(handle), data, len(data))
        kernel32.GlobalUnlock(handle)
        user32.SetClipboardData(CF_UNICODETEXT, handle)


def set_format(fmt, data):
    """Puts raw bytes into the clipboard in one format, as another program would (WI-0104: the 2 MB limit of a paste)."""
    with open_clipboard():
        user32.EmptyClipboard()
        handle = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(data))
        ctypes.memmove(kernel32.GlobalLock(handle), data, len(data))
        kernel32.GlobalUnlock(handle)
        user32.SetClipboardData(fmt, handle)


def format_available(fmt):
    with open_clipboard():
        return bool(user32.IsClipboardFormatAvailable(fmt))


def our_format():
    return user32.RegisterClipboardFormatW("AutoHotFlow.Elements")


@pytest.fixture(autouse=True)
def clipboard_kept():
    """The clipboard of the owner is put back after every test of this file."""
    items = snapshot()
    yield
    restore(items)


# --- helpers -----------------------------------------------------------------------------------------------------------

def press(obs, name, ctrl=False, answer=None, at=None, editor=EDITOR):
    """A key of the editor window (cmd.test.key). answer: the answer to the question the key opens; at: the canvas pixel of
    the mouse (a paste goes there)."""
    payload = {"key": name, "ctrl": ctrl}
    if answer is not None:
        payload["answer"] = answer
    if at is not None:
        payload["x"], payload["y"] = at
    ans = obs.request(editor, "cmd.test.key", payload, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def trash_click(obs, answer):
    """The trash button of the selection, pressed and released (cmd.test.mouse with the answer of its question)."""
    buttons = [b for b in editor_state(obs)["buttons"] if b["name"] == "trash"]
    assert buttons, "no trash button: the selection has none"
    x, y = canvas(obs, buttons[0]["x"], buttons[0]["y"])
    for action in ("down", "up"):
        ans = obs.request(EDITOR, "cmd.test.mouse", {"button": "left", "action": action, "x": x, "y": y, "answer": answer},
                          timeout=scaled(5))
        assert ans["payload"]["ok"], ans


def definition(obs, flow=FLOW):
    ans = obs.request("engine", "cmd.flow.get", {"flowId": flow}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]["definition"]


def elements_of(obs, flow=FLOW):
    return set(definition(obs, flow)["allElements"])


def connections_of(obs, flow=FLOW):
    return set(definition(obs, flow)["allConnections"])


def wait_settled(obs, name=EDITOR):
    assert wait_until(lambda: settled(obs, name), scaled(10)), editor_state(obs, name)


def status_has(obs, text, name=EDITOR):
    return wait_until(lambda: text in (editor_state(obs, name) or {}).get("status", ""), scaled(10))


def select_action_and_last(obs):
    """The action and the last element, and the connection between them (copied with them)."""
    click(obs, (70, 262))
    click(obs, (70, 472), ctrl=True)
    assert selection(obs) == {ACTION, LAST}, editor_state(obs)["selection"]


def new_ids(before, after):
    return sorted(after - before)


# --- delete -------------------------------------------------------------------------------------------------------------

def test_del_asks_one_question_and_a_no_changes_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        select_action_and_last(obs)
        rev = editor_state(obs)["rev"]
        press(obs, "Del", answer="no")
        assert editor_state(obs)["asked"].count("selection") == 1, "one question for the selection"
        assert editor_state(obs)["rev"] == rev, "no is no change"
        assert {ACTION, LAST} <= elements_of(obs)
        press(obs, "Del", answer="yes")
        wait_settled(obs)
        assert ACTION not in elements_of(obs) and LAST not in elements_of(obs), "yes removes the selection"
        assert TRIGGER in elements_of(obs), "an element that was not selected stays"
        assert not connections_of(obs) & {CONN_TA, CONN_AL}, "their connections go with them"
        assert editor_state(obs)["selection"] == [], "nothing stays selected"
    finally:
        finish(sup, obs)


def test_the_trash_button_asks_and_removes_the_selection(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        click(obs, (70, 262))
        assert "trash" in [b["name"] for b in editor_state(obs)["buttons"]], "the selection has a trash button"
        trash_click(obs, answer="no")
        assert ACTION in elements_of(obs), "no keeps the element"
        trash_click(obs, answer="yes")
        wait_settled(obs)
        assert ACTION not in elements_of(obs), "yes removes it"
    finally:
        finish(sup, obs)


def test_del_without_a_selection_says_so_and_asks_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        press(obs, "Del", answer="yes")
        assert editor_state(obs)["asked"] == [], "nothing to delete, no question"
        assert "No elements selected" in editor_state(obs)["status"]
    finally:
        finish(sup, obs)


def test_a_connection_alone_is_deleted_and_the_elements_stay(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        click(obs, (70, 185))                       # the connection trigger -> action
        assert selection(obs) == {CONN_TA}
        press(obs, "Del", answer="yes")
        wait_settled(obs)
        assert CONN_TA not in connections_of(obs)
        assert {TRIGGER, ACTION, LAST} <= elements_of(obs)
    finally:
        finish(sup, obs)


# --- copy, cut and paste --------------------------------------------------------------------------------------------------

def test_ctrl_c_puts_the_selection_on_the_clipboard_in_our_format_only(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        select_action_and_last(obs)
        rev = editor_state(obs)["rev"]
        press(obs, "C", ctrl=True)
        assert "Saved 2 elements to clipboard" in editor_state(obs)["status"], editor_state(obs)["status"]
        assert editor_state(obs)["rev"] == rev, "a copy changes no flow"
        assert format_available(our_format()), "the content is in the format of AutoHotFlow"
        assert not format_available(CF_UNICODETEXT), "no text is written (E0091)"
    finally:
        finish(sup, obs)


def test_ctrl_v_pastes_new_elements_under_the_mouse_selected_and_as_one_undo_step(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        select_action_and_last(obs)
        press(obs, "C", ctrl=True)
        wait_settled(obs)
        before = elements_of(obs)
        connections_before = connections_of(obs)
        under = EMPTY                                # the mouse is over this empty flow point (the canvas pixel)
        press(obs, "V", ctrl=True, at=canvas(obs, *under))
        wait_settled(obs)
        added = new_ids(before, elements_of(obs))
        added_connections = new_ids(connections_before, connections_of(obs))
        assert len(added) == 2, added
        assert len(added_connections) == 1, "the connection between the two copies is pasted too"
        assert set(editor_state(obs)["selection"]) == set(added) | set(added_connections), "the pasted items are selected"
        d = definition(obs)
        ends = {d["allConnections"][added_connections[0]]["from"], d["allConnections"][added_connections[0]]["to"]}
        assert ends == set(added), "the pasted connection joins the pasted elements"
        # the top left element of the copy (the action, at y 210) is centred on the pointer (500, 500): its top left goes to
        # (500 - 70, 500 - 52.5), snapped to the grid of 35 with the offset of the copy: x 420, y 455 (as the unit test)
        anchor = min((d["allElements"][e] for e in added), key=lambda el: (float(el["y"]), float(el["x"])))
        assert (float(anchor["x"]), float(anchor["y"])) == (420, 455), anchor
        step(obs, "undo")
        wait_settled(obs)
        assert elements_of(obs) == before, "one undo step takes the whole paste back"
    finally:
        finish(sup, obs)


def test_ctrl_v_without_a_mouse_in_the_canvas_pastes_in_the_middle_of_the_view(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        click(obs, (70, 52))                          # the trigger
        press(obs, "C", ctrl=True)
        wait_settled(obs)
        before = elements_of(obs)
        press(obs, "V", ctrl=True)                    # no pixel: the middle of the view
        wait_settled(obs)
        added = new_ids(before, elements_of(obs))
        assert len(added) == 1, added
        view = editor_state(obs)["view"]
        scale = view["zoom"] * view["dpi"] / 96
        mid_x = view["offsetX"] + view["width"] / 2 / scale
        mid_y = view["offsetY"] + view["height"] / 2 / scale
        el = definition(obs)["allElements"][added[0]]
        assert abs(float(el["x"]) + 70 - mid_x) < 40 and abs(float(el["y"]) + 52 - mid_y) < 40, (el, mid_x, mid_y)
        assert editor_state(obs)["selection"] == added
    finally:
        finish(sup, obs)


def test_ctrl_x_copies_and_deletes_without_a_question(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        select_action_and_last(obs)
        press(obs, "X", ctrl=True)
        wait_settled(obs)
        assert editor_state(obs)["asked"] == [], "a cut asks nothing"
        assert ACTION not in elements_of(obs) and LAST not in elements_of(obs), "the cut elements are gone"
        assert format_available(our_format()), "and they are on the clipboard"
        before = elements_of(obs)
        press(obs, "V", ctrl=True, at=canvas(obs, *EMPTY))
        wait_settled(obs)
        assert len(new_ids(before, elements_of(obs))) == 2, "the cut content comes back by paste"
    finally:
        finish(sup, obs)


def test_a_pasted_manual_trigger_is_no_default_when_the_flow_has_one(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        click(obs, (70, 52))                          # the default manual trigger
        press(obs, "C", ctrl=True)
        wait_settled(obs)
        before = elements_of(obs)
        press(obs, "V", ctrl=True, at=canvas(obs, *EMPTY))
        wait_settled(obs)
        added = new_ids(before, elements_of(obs))
        d = definition(obs)
        assert len(added) == 1
        assert "DefaultTrigger" not in d["allElements"][added[0]], "a second default would be wrong"
        assert d["allElements"][TRIGGER].get("DefaultTrigger") in (1, True, "1", "true"), "the default stays"
    finally:
        finish(sup, obs)


def test_a_clipboard_without_our_format_pastes_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        set_text("some text from another program")
        rev = editor_state(obs)["rev"]
        press(obs, "V", ctrl=True, at=canvas(obs, *EMPTY))
        assert status_has(obs, "No elements found in clipboard")
        assert editor_state(obs)["rev"] == rev, "nothing is pasted"
    finally:
        finish(sup, obs)


def test_a_clipboard_of_our_format_above_2_mb_is_refused_and_nothing_is_pasted(procs, datadir, session_id):
    """WI-0104: the limit of a paste is 2 MB (WinClipboard.MAX_BYTES); a bigger copy of our format is not parsed."""
    sup, obs = start(procs, datadir, session_id)
    try:
        set_format(our_format(), b"x" * (3 * 1024 * 1024))
        rev = editor_state(obs)["rev"]
        press(obs, "V", ctrl=True, at=canvas(obs, *EMPTY))
        assert status_has(obs, "The clipboard could not be used")
        assert editor_state(obs)["rev"] == rev, "nothing is pasted"
    finally:
        finish(sup, obs)


def test_a_busy_clipboard_is_said_in_the_status_bar_and_nothing_is_lost(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        select_action_and_last(obs)
        rev = editor_state(obs)["rev"]
        with clipboard_owner() as owner, open_clipboard(owner):      # another program holds the clipboard open
            press(obs, "C", ctrl=True)
            assert status_has(obs, "The clipboard is in use by another program")
        assert editor_state(obs)["rev"] == rev and ACTION in elements_of(obs), "a busy clipboard changes nothing"
        press(obs, "C", ctrl=True)
        assert status_has(obs, "Saved 2 elements to clipboard"), "the copy goes in once the clipboard is free"
    finally:
        finish(sup, obs)


def test_ctrl_c_without_a_selection_says_so(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        press(obs, "C", ctrl=True)
        assert "No elements selected" in editor_state(obs)["status"]
    finally:
        finish(sup, obs)


# --- two flows ----------------------------------------------------------------------------------------------------------

def test_a_copy_in_one_editor_is_pasted_in_the_editor_of_another_flow(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=lambda d: write_flow(d, SECOND))
    try:
        open_editor(obs)
        open_editor(obs, SECOND)
        render(obs)
        render(obs, name=SECOND_EDITOR)
        click(obs, (70, 262))                         # the action of the first flow
        press(obs, "C", ctrl=True)
        wait_settled(obs)
        before = elements_of(obs, SECOND)
        press(obs, "V", ctrl=True, editor=SECOND_EDITOR)     # the middle of the second editor's view
        assert wait_until(lambda: len(elements_of(obs, SECOND)) == len(before) + 1, scaled(15)), "the copy arrived"
        assert len(elements_of(obs)) == 3, "the first flow is unchanged"
    finally:
        finish(sup, obs)


def test_a_copy_survives_the_editor_that_made_it(procs, datadir, session_id):
    """E0091: the clipboard belongs to the session, not to the editor: the copy is pasted after its editor has closed."""
    sup, obs = start_manager(procs, datadir, session_id, prepare=lambda d: write_flow(d, SECOND))
    try:
        results = edit_results(obs, flowIds=[FLOW, SECOND])
        assert [r[3] for r in results] == [True, True], results
        open_editor(obs)
        open_editor(obs, SECOND)
        render(obs)
        click(obs, (70, 262))                         # the action of the first flow
        press(obs, "C", ctrl=True)
        wait_settled(obs)
        obs.request(EDITOR, "cmd.test.close", {}, timeout=scaled(5))      # the planned end of the first editor
        assert wait_until(lambda: editor_state(obs) is None, scaled(10)), "the first editor ended"
        before = elements_of(obs, SECOND)
        press(obs, "V", ctrl=True, editor=SECOND_EDITOR)
        assert wait_until(lambda: len(elements_of(obs, SECOND)) == len(before) + 1, scaled(15)), "the copy arrived"
    finally:
        finish(sup, obs)
