"""WI-0103, REQ-ROB-120, E0093: the balloon of an editor notice, shown for real (not headless). Only the gui test is here;
the notice, the link of the balloon and the reopen are tested headless in tests/e2e/test_editor_crash_notice.py.

The tray role runs without --headless, so it has its icon and shows the balloon (TrayTip). The balloon click is the
message NIN_BALLOONUSERCLICK (1029) to the icon's callback, 0x404, sent to the script window of the tray process: that is
the message the shell sends for a click (the TrayTip docs). The test sends it with PostMessage, because a click on a real
balloon cannot be made from a test without a desktop; the click on the real balloon is the owner's manual check. The test
needs the input desktop and skips on a locked PC. An agent never runs it (doc/TEST-STRATEGY.md section 6).
"""

import ctypes
from ctypes import wintypes

import psutil
import pytest

from faultkit import SKELETON_FLOW, open_editor_as_manager, request_ok, wait_until
from support import inputlock
from support.timing import scaled
from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

READY_S = 20.0
AHK_NOTIFYICON = 0x404              # the tray callback message of an AutoHotkey script
NIN_BALLOONUSERCLICK = 1029


@pytest.mark.gui
def test_a_click_on_the_balloon_of_an_editor_notice_opens_the_editor_again(chains):
    reason = inputlock.session_skip_reason(inputlock.input_desktop_open(), inputlock.logonui_running())
    if reason:
        pytest.skip(reason)
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    enum_proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows.argtypes = [enum_proc, wintypes.LPARAM]

    chain = chains("storage,engine", ["--tray"])      # not headless: the tray shows its icon and its balloons
    chain.wait_ready(["storage", "engine"], timeout=READY_S)
    open_editor_as_manager(chain, SKELETON_FLOW)
    name = "editor:" + SKELETON_FLOW
    old = chain.wait_ready([name], timeout=READY_S)[name]
    tray_pid = chain.wait_ready(["tray"], timeout=READY_S)["tray"]

    def tray_info():
        return request_ok(chain.obs, "tray", "cmd.diag.snapshot", {})["snapshot"]["info"]

    psutil.Process(old).kill()
    assert wait_until(lambda: chain.states()[name]["state"] == "crashed", scaled(15)), chain.states()[name]
    assert wait_until(lambda: tray_info().get("editorFlow") == SKELETON_FLOW, scaled(15)), tray_info()

    found = []

    def cb(hwnd, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        cls = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(hwnd, cls, 64)
        if owner.value == tray_pid and cls.value == "AutoHotkey":
            found.append(hwnd)
        return True

    user32.EnumWindows(enum_proc(cb), 0)
    assert found, "no main window of the tray process"
    with inputlock.input_lock():
        user32.PostMessageW(found[0], AHK_NOTIFYICON, 1, NIN_BALLOONUSERCLICK)
    assert wait_until(lambda: chain.states()[name]["state"] == "ready"
                      and chain.states()[name]["pid"] not in (None, old), scaled(30)), chain.states()[name]
