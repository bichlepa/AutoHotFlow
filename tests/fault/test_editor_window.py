"""WI-0088, REQ-EDT-010, REQ-EDT-020: the window of the editor (src/editor/EditorWindow.ahk) as the owner sees it. Gui tier:
the test opens a real window; run it alone (doc/TEST-STRATEGY.md section 6). Agents do not run it.

The supervisor runs storage and engine (no manager: the editor is started here, as the supervisor would start it, with
the same command line and the same hub). The window is found by its title, "AutoHotFlow Editor - Skeleton" (v1 title
with the flow name). The test closes it like the X button (WM_CLOSE): the editor ends as a planned end (exit 0).
"""

import ctypes
import subprocess
import sys
from pathlib import Path

import pytest

from faultkit import AHKRUN, Sup, connect, wait_until, write_flow
from support.timing import scaled

pytestmark = [pytest.mark.fault, pytest.mark.gui]

ROOT_ENTRY_EDITOR = Path(__file__).resolve().parents[2] / "src" / "entry" / "editor.ahk"   # the product entry
# The title is "AutoHotFlow <Editor> - <flow name>" (EditorWindow.Refresh); the flow name is the flow ID "skeleton" (the
# language of the test folder decides the word in the middle, so only the start and the end are matched).
FLOW = "skeleton"
TITLE_START = "AutoHotFlow "
TITLE_END = " - " + FLOW
WM_CLOSE = 0x0010

user32 = ctypes.WinDLL("user32")
user32.PostMessageW.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_size_t, ctypes.c_ssize_t]
user32.IsWindowVisible.argtypes = [ctypes.c_void_p]


def _text(hwnd):
    length = user32.GetWindowTextLengthW(hwnd)
    buf = ctypes.create_unicode_buffer(length + 1)
    user32.GetWindowTextW(hwnd, buf, length + 1)
    return buf.value


def windows_titled():
    """The visible top-level windows of the editor title (any process)."""
    found = []
    proc_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def visit(hwnd, _):
        text = _text(hwnd)
        if text.startswith(TITLE_START) and text.endswith(TITLE_END) and user32.IsWindowVisible(hwnd):
            found.append(hwnd)
        return True

    user32.EnumWindows(proc_type(visit), 0)
    return found


def storage_and_engine_ready(obs):
    procs = obs.request("supervisor", "cmd.process.list", {}, timeout=5)["payload"]["processes"]
    states = {p["name"]: p["state"] for p in procs}
    return states.get("storage") == "ready" and states.get("engine") == "ready"


def test_the_editor_window_opens_with_the_flow_and_closes_as_a_planned_end(procs, datadir, session_id):
    write_flow(datadir, FLOW)                                   # the flow ID is the file name: "skeleton"
    sup = Sup(procs, datadir, session_id, ["--start=storage,engine"])
    obs = connect(sup.pipe, "obs")
    try:
        assert wait_until(lambda: storage_and_engine_ready(obs), scaled(20)), "storage and engine not ready"
        # the command line the supervisor gives an editor (PROTOCOL 4.1, "Starting a role"), without the supervisor
        editor = procs.start([sys.executable, str(AHKRUN), "--timeout", "120", str(ROOT_ENTRY_EDITOR),
                              "--role=editor", "--flow=" + FLOW, "--session=" + session_id, "--hub=" + sup.pipe,
                              "--data=" + str(datadir)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        expected = "%s... %s" % (TITLE_START, TITLE_END)
        assert wait_until(lambda: len(windows_titled()) == 1, scaled(30)), "no editor window titled %r" % expected
        hwnd = windows_titled()[0]
        assert user32.IsWindowVisible(hwnd)
        user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)               # the X button
        code = editor.wait(timeout=scaled(30))
        assert code == 0, "the closed editor ends with exit %s" % code
        assert not windows_titled()
    finally:
        obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
        assert sup.wait_exit(20) == 0, sup.text()
        obs.close()
        sup.close()
