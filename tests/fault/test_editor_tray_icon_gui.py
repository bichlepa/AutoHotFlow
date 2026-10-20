"""WI-0091, REQ-EDT-230, PROTOCOL 4.11: the tray icon of an editor, shown for real (not headless). Only the gui test is here;
the entries, the states and the questions are tested headless in tests/e2e/test_editor_tray.py.

The editor is started by the supervisor (cmd.editor.open, sent as the manager) without --headless, so it has its own
icon. The menu of the icon is opened with the tray message to the script window of the editor process, held longer than
the pong timeout and closed with Esc: a menu that is open pauses only this editor, so the editor must not be judged hung
(E0077). The test needs the input desktop and skips on a locked PC. An agent runs it only when the project owner allows
it (doc/TEST-STRATEGY.md section 6).
"""

import ctypes
import time
from ctypes import wintypes

import pytest

from faultkit import SKELETON_FLOW, event, open_editor_as_manager, request_ok, wait_until
from support import inputlock
from support.timing import scaled
from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

READY_S = 20.0
MENU_HOLD_S = 8.0                   # longer than Heartbeat.PONG_TIMEOUT_MS (6 s): a menu open this long must not make the editor hung
WM_RBUTTONUP = 0x0205
AHK_NOTIFYICON = 0x404              # the tray callback message of an AutoHotkey script


@pytest.mark.gui
def test_the_real_icon_of_an_editor_opens_its_menu_and_a_menu_open_for_8_seconds_does_not_make_the_editor_hung(chains):
    reason = inputlock.session_skip_reason(inputlock.input_desktop_open(), inputlock.logonui_running())
    if reason:
        pytest.skip(reason)
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    user32.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
    user32.FindWindowW.restype = wintypes.HWND
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    enum_proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows.argtypes = [enum_proc, wintypes.LPARAM]
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]

    chain = chains("storage,engine", [])          # not headless: the editor shows its icon and its window
    chain.wait_ready(["storage", "engine"], timeout=READY_S)
    open_editor_as_manager(chain, SKELETON_FLOW)
    name = "editor:" + SKELETON_FLOW
    pid = chain.wait_ready([name], timeout=READY_S)[name]
    snap = request_ok(chain.obs, name, "cmd.diag.snapshot", {})["snapshot"]
    assert snap["info"]["tray"]["iconHidden"] is False, snap["info"]["tray"]

    found = []

    def cb(hwnd, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        cls = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(hwnd, cls, 64)
        if owner.value == pid and cls.value == "AutoHotkey":
            found.append(hwnd)
        return True

    user32.EnumWindows(enum_proc(cb), 0)
    assert found, "no main window of the editor process"
    with inputlock.input_lock():
        user32.PostMessageW(found[0], AHK_NOTIFYICON, 1, WM_RBUTTONUP)
        assert wait_until(lambda: user32.FindWindowW("#32768", None), scaled(5)), "the menu did not open"
        t0 = time.monotonic()
        while time.monotonic() - t0 < MENU_HOLD_S:
            assert chain.states()[name]["state"] == "ready", chain.states()[name]     # still answers pings
            time.sleep(0.5)
        assert not chain.rec.find(event("evt.process.hung", name=name))
        inputlock.send_key(0x1B)                  # Esc closes the menu
        assert wait_until(lambda: not user32.FindWindowW("#32768", None), scaled(5)), "Esc did not close the menu"
    assert chain.states()[name]["pid"] == pid, "the editor was restarted while its menu was open"
