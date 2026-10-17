"""Machine-wide input lock and keyboard helpers for the input tests (WI-0064, E0059).

The input tests send real keys to the desktop. Two test runs must never send keys at the same time, so each input test
holds one lock file next to the admission files (admission.runs_dir()). A lock older than INPUT_LOCK_STALE_S was left
behind by a dead process and is taken over; the holder refreshes the file while it holds the lock.
Nothing here blocks forever: the wait for the lock has a limit.

Helpers: the input desktop (a locked workstation or a UAC prompt has none), SendInput of a key with modifiers, the
foreground window, and the modifiers that the user holds (a test waits for them to be released).
"""

import contextlib
import ctypes
import os
import threading
import time
from ctypes import wintypes

from support import admission

LOCK_NAME = "input.lock"
INPUT_LOCK_STALE_S = 120.0      # a lock file not refreshed for this long belongs to a dead run
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


def _take_over(path, stale_s):
    """Removes the lock file when it is stale. The file is first renamed to a name of our own (atomic), so an unlink
    can never hit a lock that another process created in the meantime; if the renamed file turns out to be fresh
    (it was replaced between our stat and our rename), it is put back with os.link, which fails if the name is taken."""
    mine = path.with_name("%s.stale.%d.%d" % (LOCK_NAME, os.getpid(), time.time_ns()))
    try:
        os.rename(str(path), str(mine))
    except FileNotFoundError:
        return                                     # released meanwhile
    try:
        if time.time() - mine.stat().st_mtime <= stale_s:
            try:
                os.link(str(mine), str(path))      # not stale after all: give it back
            except FileExistsError:
                pass                               # a third process has created a new lock already
    finally:
        try:
            mine.unlink()
        except FileNotFoundError:
            pass


def _heartbeat(path, stale_s, stop):
    """Refreshes the mtime of our lock file while it is held, so the stale limit only applies to a dead holder."""
    while not stop.wait(stale_s / 4.0):
        try:
            os.utime(str(path), None)
        except OSError:
            pass


@contextlib.contextmanager
def input_lock(wait_s=INPUT_LOCK_WAIT_S, stale_s=None):
    """Holds the machine-wide input lock for the block. Fails with TimeoutError when another run holds it too long.
    The holder refreshes the mtime of the lock file (every stale_s / 4); a lock that was not refreshed for stale_s
    seconds belongs to a dead holder and is taken over. stale_s defaults to INPUT_LOCK_STALE_S."""
    stale_s = INPUT_LOCK_STALE_S if stale_s is None else stale_s
    path = lock_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + wait_s
    token = "pid %d since %.6f\n" % (os.getpid(), time.time())
    while True:
        try:
            fd = os.open(str(path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            try:
                if time.time() - path.stat().st_mtime > stale_s:
                    _take_over(path, stale_s)      # left behind by a dead run
                    continue
            except FileNotFoundError:
                continue                           # released meanwhile
            if time.monotonic() > deadline:
                raise TimeoutError("input lock %s is held by another run (waited %.0f s)" % (path, wait_s))
            time.sleep(min(0.2, stale_s / 4.0))
            continue
        os.write(fd, token.encode("ascii"))
        os.close(fd)
        break
    stop = threading.Event()
    beat = threading.Thread(target=_heartbeat, args=(path, stale_s, stop), daemon=True)
    beat.start()
    try:
        yield path
    finally:
        stop.set()
        beat.join()
        try:
            if path.read_text(encoding="ascii") == token:      # never remove a lock that is not ours
                path.unlink()
        except (FileNotFoundError, OSError):
            pass


def input_desktop_open():
    """True when the input desktop can be opened (not on a locked workstation or a secure desktop)."""
    handle = _user32.OpenInputDesktop(0, False, GENERIC_READ)
    if not handle:
        return False
    _user32.CloseDesktop(handle)
    return True


DESKTOP_UNUSABLE_REASON = "the input desktop is not usable (locked workstation or secure desktop)"


def session_skip_reason(desktop_open):
    """The skip reason for all input tests of a session, decided once at its start from input_desktop_open(); None when
    the input desktop is usable. Pure, so the decision can be tested without a desktop."""
    return None if desktop_open else DESKTOP_UNUSABLE_REASON


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
