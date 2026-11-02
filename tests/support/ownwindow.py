"""WI-0132: an own window for the tests of the window triggers. A Gui of tests/integration/helpers/own_window.ahk with a
title the test chooses (unique), started by the test and ended by the test. The window is found by its title; no window
of the user is touched. Only the window tests of the trigger (test_window_triggers.py) use it; the element tests keep
their own copy (test_window_elements.py) until both are moved here.
"""

import ctypes
import subprocess
import sys
import time
import uuid
from ctypes import wintypes
from pathlib import Path

from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
HELPERS = ROOT / "tests" / "integration" / "helpers"
AHKRUN = ROOT / "tools" / "ahkrun.py"
CREATE_NO_WINDOW = 0x08000000

user32 = ctypes.WinDLL("user32", use_last_error=True)
user32.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.FindWindowW.restype = wintypes.HWND
user32.GetForegroundWindow.restype = wintypes.HWND


class OwnWindow:
    """One window of a test: its helper process, its title and the ready and stop files."""

    def __init__(self, title, proc, stop):
        self.title = title
        self.proc = proc
        self.stop = stop

    @property
    def hwnd(self):
        return user32.FindWindowW(None, self.title)

    def is_active(self):
        return user32.GetForegroundWindow() == self.hwnd

    def end(self):
        """Ends the window by its stop file (the helper closes itself); killed when it does not end in time."""
        self.stop.write_text("stop", encoding="ascii")
        try:
            self.proc.wait(timeout=scaled(10))
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=scaled(10))


def start(tmp_path, noactivate=True, title=None):
    """Starts an own window and waits until it is shown (the ready file). By default it is shown without the focus, so
    it does not take the focus from the user; noactivate=False (the tests of the active window, under the focus fixture)
    gives it the focus."""
    title = title or "AhfTriggerWindow-" + uuid.uuid4().hex
    ready, stop = tmp_path / ("ready-%s.txt" % uuid.uuid4().hex), tmp_path / ("stop-%s.txt" % uuid.uuid4().hex)
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
