"""Machine-wide input lock and keyboard helpers for the input tests (WI-0064, E0059).

The input tests send real keys to the desktop. Two test runs must never send keys at the same time, so each input test
holds one lock file next to the admission files (admission.runs_dir()). A lock older than INPUT_LOCK_STALE_S was left
behind by a crashed process and is taken over. Nothing here blocks forever: the wait for the lock has a limit.

Helpers: the input desktop (a locked workstation or a UAC prompt has none), SendInput of a key with modifiers, the
foreground window, and the modifiers that the user holds (a test waits for them to be released).
"""

import contextlib
import ctypes
import os
import time
from ctypes import wintypes

from support import admission

LOCK_NAME = "input.lock"
INPUT_LOCK_STALE_S = 120.0      # a lock file older than this belongs to a crashed run
INPUT_LOCK_WAIT_S = 240.0       # longest wait for the lock before the test fails

INPUT_KEYBOARD = 1
KEYEVENTF_KEYUP = 0x0002
GENERIC_READ = 0x80000000

VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN = 0x10, 0x11, 0x12, 0x5B, 0x5C
MODIFIERS = (VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN)

_user32 = ctypes.windll.user32


class _KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wintypes.WORD), ("wScan", wintypes.WORD), ("dwFlags", wintypes.DWORD),
                ("time", wintypes.DWORD), ("dwExtraInfo", ctypes.c_size_t)]


class _INPUTUNION(ctypes.Union):
    _fields_ = [("ki", _KEYBDINPUT), ("pad", ctypes.c_byte * 32)]


class _INPUT(ctypes.Structure):
    _fields_ = [("type", wintypes.DWORD), ("u", _INPUTUNION)]


def lock_path():
    return admission.runs_dir() / LOCK_NAME


@contextlib.contextmanager
def input_lock(wait_s=INPUT_LOCK_WAIT_S):
    """Holds the machine-wide input lock for the block. Fails with TimeoutError when another run holds it too long."""
    path = lock_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + wait_s
    while True:
        try:
            fd = os.open(str(path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            try:
                if time.time() - path.stat().st_mtime > INPUT_LOCK_STALE_S:
                    path.unlink()                  # left behind by a crashed run
                    continue
            except FileNotFoundError:
                continue                           # released meanwhile
            if time.monotonic() > deadline:
                raise TimeoutError("input lock %s is held by another run (waited %.0f s)" % (path, wait_s))
            time.sleep(0.2)
            continue
        os.write(fd, ("pid %d since %.0f\n" % (os.getpid(), time.time())).encode("ascii"))
        os.close(fd)
        break
    try:
        yield path
    finally:
        try:
            path.unlink()
        except FileNotFoundError:
            pass


def input_desktop_open():
    """True when the input desktop can be opened (not on a locked workstation or a secure desktop)."""
    handle = _user32.OpenInputDesktop(0, False, GENERIC_READ)
    if not handle:
        return False
    _user32.CloseDesktop(handle)
    return True


def _key(vk, up):
    return _INPUT(INPUT_KEYBOARD, _INPUTUNION(ki=_KEYBDINPUT(vk, 0, KEYEVENTF_KEYUP if up else 0, 0, 0)))


def send_key(vk, with_modifiers=()):
    """Presses vk (down and up) with the modifiers held around it. Returns the number of events SendInput accepted;
    0 means the input was refused (no input desktop, or blocked by the system)."""
    events = [_key(m, False) for m in with_modifiers] + [_key(vk, False), _key(vk, True)]
    events += [_key(m, True) for m in reversed(with_modifiers)]
    arr = (_INPUT * len(events))(*events)
    return _user32.SendInput(len(events), arr, ctypes.sizeof(_INPUT))


def foreground_window():
    return _user32.GetForegroundWindow()


def held_modifiers():
    """The modifiers that are down now (GetAsyncKeyState high bit)."""
    return [vk for vk in MODIFIERS if _user32.GetAsyncKeyState(vk) & 0x8000]


def wait_modifiers_released(wait_s=1.0):
    """The modifiers held by the user, after one short wait and one more try: [] when none is held any more."""
    held = held_modifiers()
    if held:
        time.sleep(wait_s)
        held = held_modifiers()
    return held


def baseline_skip_reason():
    """After a baseline key did not arrive: why that is the desktop's fault (a reason text), or None when the desktop is
    usable. Only the reasons named here may skip a test; any other miss is a failure of the hotkey path."""
    if not input_desktop_open():
        return "the input desktop was lost (locked workstation or a secure desktop in front)"
    held = held_modifiers()
    if held:
        return "a modifier is held by the user (VK %s)" % held
    return None


def baseline_missed(what):
    """Call when a baseline key did not arrive: skips for a desktop reason, otherwise fails (never a silent skip)."""
    import pytest
    reason = baseline_skip_reason()
    if reason:
        pytest.skip("%s did not arrive and %s" % (what, reason))
    pytest.fail("%s did not arrive although the input desktop is usable and no modifier is held: "
                "hotkey path, not the desktop" % what)
