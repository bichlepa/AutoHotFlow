"""WI-0092 (review of WI-0090, task 7; REQ-EDT-030, REQ-EDT-020, REQ-USE-090): the editor window with REAL mouse input and the
layout of its status bar, on a shown window. Gui tier: the tests open a real editor window and send real wheel and drag
events (SendInput) to it. Run them alone (doc/TEST-STRATEGY.md section 6); agents do not run them.

The editor is started by the supervisor (cmd.editor.open) without --headless, as the tray gui test does. The window is
found by its process (the editor's pid) and its class. The status bar text is read with SB_GETTEXTW, so the view is read
the way the owner reads it: zoom and offset in the status bar. Coordinates are physical pixels: the test process declares
itself DPI aware first, otherwise SetCursorPos and the window rectangles would differ by the scaling.

Not checked here: the look of the status bar text, the tooltip timing (manual check, doc/MANUAL-CHECKS.md section 9).
"""

import ctypes
import re
import time
from ctypes import wintypes

import pytest

from faultkit import SKELETON_FLOW, open_editor_as_manager, request_ok, wait_until
from support import inputlock
from support.timing import scaled
from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = [pytest.mark.fault, pytest.mark.gui]

READY_S = 20.0
WHEEL_DELTA = 120
MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_WHEEL = 0x0800
INPUT_MOUSE = 0
SB_GETTEXTW = 0x040D            # WM_USER + 13: text of a status bar part (part 0 is the first part)
STATUS_CLASS = "msctls_statusbar32"
ZOOM_RE = re.compile(r"Zoom: ([0-9.]+)")
OFFSET_RE = re.compile(r"Offset: x (-?\d+) y (-?\d+)")

user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
PROCESS_VM_OPERATION = 0x0008
PROCESS_VM_READ = 0x0010
PROCESS_VM_WRITE = 0x0020
PROCESS_QUERY_INFORMATION = 0x0400
MEM_COMMIT = 0x1000
MEM_RESERVE = 0x2000
MEM_RELEASE = 0x8000
PAGE_READWRITE = 0x04
TEXT_BYTES = 512 * 2            # the buffer of the status text: 512 UTF-16 characters
kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
kernel32.OpenProcess.restype = ctypes.c_void_p
kernel32.VirtualAllocEx.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, wintypes.DWORD, wintypes.DWORD]
kernel32.VirtualAllocEx.restype = ctypes.c_void_p
kernel32.VirtualFreeEx.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, wintypes.DWORD]
kernel32.ReadProcessMemory.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                       ctypes.POINTER(ctypes.c_size_t)]
kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
user32.SendInput.argtypes = [wintypes.UINT, ctypes.c_void_p, ctypes.c_int]
user32.SetCursorPos.argtypes = [ctypes.c_int, ctypes.c_int]
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, ctypes.c_void_p]
user32.SendMessageW.restype = wintypes.LPARAM
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]


class _MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", wintypes.LONG), ("dy", wintypes.LONG), ("mouseData", wintypes.DWORD),
                ("dwFlags", wintypes.DWORD), ("time", wintypes.DWORD), ("dwExtraInfo", ctypes.c_size_t)]


class _INPUTUNION(ctypes.Union):
    _fields_ = [("mi", _MOUSEINPUT), ("pad", ctypes.c_byte * 32)]


class _INPUT(ctypes.Structure):
    _fields_ = [("type", wintypes.DWORD), ("u", _INPUTUNION)]


def _send_mouse(flags, data=0):
    """One SendInput of a mouse event (no movement); returns the number of events accepted."""
    event = _INPUT(INPUT_MOUSE, _INPUTUNION(mi=_MOUSEINPUT(0, 0, data & 0xFFFFFFFF, flags, 0, 0)))
    return user32.SendInput(1, ctypes.byref(event), ctypes.sizeof(_INPUT))


def _enable_dpi_awareness():
    """Physical pixels for this process (the window rectangles and SetCursorPos then agree)."""
    user32.SetProcessDPIAware()


def _window_of_pid(pid):
    """The visible top-level window of the editor process: a Gui window of AutoHotkey, class AutoHotkeyGUI (the script's own
    main window, class AutoHotkey, is hidden and is not the editor window)."""
    found = []
    proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def visit(hwnd, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        cls = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(hwnd, cls, 64)
        if owner.value == pid and cls.value == "AutoHotkeyGUI" and user32.IsWindowVisible(hwnd):
            found.append(hwnd)
        return True

    user32.EnumWindows(proc(visit), 0)
    return found[0] if found else None


def _status_bar_of(hwnd):
    """The native status bar child of the editor window (class msctls_statusbar32), or None."""
    found = []
    proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def visit(child, _):
        cls = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(child, cls, 64)
        if cls.value == STATUS_CLASS:
            found.append(child)
        return True

    user32.EnumChildWindows(hwnd, proc(visit), 0)
    return found[0] if found else None


def _screen_rect(hwnd):
    rect = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    return rect.left, rect.top, rect.right, rect.bottom


class EditorWindowGeometry:
    """The editor window in screen pixels: the canvas is the client area above the status bar."""

    def __init__(self, hwnd, status):
        client = wintypes.RECT()
        user32.GetClientRect(hwnd, ctypes.byref(client))
        origin = wintypes.POINT(0, 0)
        user32.ClientToScreen(hwnd, ctypes.byref(origin))
        self.client_w = client.right - client.left
        self.client_h = client.bottom - client.top
        self.left, self.top = origin.x, origin.y
        self.status_rect = _screen_rect(status)
        self.bar_h = self.status_rect[3] - self.status_rect[1]
        self.canvas_bottom = self.top + self.client_h - self.bar_h

    def canvas_center(self):
        return self.left + self.client_w // 2, self.top + (self.canvas_bottom - self.top) // 2


def status_text(status):
    """The text of part 0. SB_GETTEXTW writes into the buffer whose address it gets, in the process of the status bar:
    the buffer is allocated there (VirtualAllocEx) and read back (ReadProcessMemory). A pointer of this process would be
    written into the editor's memory and crash or hang the editor."""
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(status, ctypes.byref(pid))
    proc = kernel32.OpenProcess(PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_QUERY_INFORMATION,
                                False, pid.value)
    assert proc, "OpenProcess of the editor failed: %d" % ctypes.get_last_error()
    try:
        remote = kernel32.VirtualAllocEx(proc, None, TEXT_BYTES, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE)
        assert remote, "VirtualAllocEx in the editor failed: %d" % ctypes.get_last_error()
        try:
            user32.SendMessageW(status, SB_GETTEXTW, 0, remote)
            buf = ctypes.create_string_buffer(TEXT_BYTES)
            read = ctypes.c_size_t()
            assert kernel32.ReadProcessMemory(proc, remote, buf, TEXT_BYTES, ctypes.byref(read)), "ReadProcessMemory failed"
            return buf.raw[:read.value].decode("utf-16-le", errors="replace").split("\x00")[0]
        finally:
            kernel32.VirtualFreeEx(proc, remote, 0, MEM_RELEASE)
    finally:
        kernel32.CloseHandle(proc)


def view_of(status):
    """(zoom, offsetX, offsetY) from the status bar text, or None while the text has no view yet."""
    text = status_text(status)
    z, o = ZOOM_RE.search(text), OFFSET_RE.search(text)
    if not (z and o):
        return None
    return float(z.group(1)), int(o.group(1)), int(o.group(2))


def _open_editor(chain):
    chain.wait_ready(["storage", "engine"], timeout=READY_S)
    open_editor_as_manager(chain, SKELETON_FLOW)
    name = "editor:" + SKELETON_FLOW
    pid = chain.wait_ready([name], timeout=READY_S)[name]
    hwnd = wait_until(lambda: _window_of_pid(pid), scaled(20))
    assert hwnd, "no visible window of the editor process %d" % pid
    status = wait_until(lambda: _status_bar_of(hwnd), scaled(5))
    assert status, "no status bar in the editor window"
    assert wait_until(lambda: view_of(status) is not None, scaled(10)), "the status bar shows no view"
    return name, pid, hwnd, status


def _skip_if_no_input():
    reason = inputlock.session_skip_reason(inputlock.input_desktop_open(), inputlock.logonui_running())
    if reason:
        pytest.skip(reason)


@pytest.mark.gui
def test_the_status_bar_lies_below_the_canvas_and_does_not_overlap_it(chains):
    """Layout on the shown window: the status bar takes the bottom of the client area, its width is the client width,
    and the canvas (the client area above it) does not reach into it."""
    _skip_if_no_input()
    _enable_dpi_awareness()
    chain = chains("storage,engine", [])
    name, pid, hwnd, status = _open_editor(chain)
    geo = EditorWindowGeometry(hwnd, status)
    left, top, right, bottom = geo.status_rect
    assert left == geo.left and right == geo.left + geo.client_w, (geo.status_rect, geo.left, geo.client_w)
    assert top >= geo.canvas_bottom, "the status bar starts above the canvas bottom: %r" % (geo.status_rect,)
    assert bottom == geo.top + geo.client_h, "the status bar does not end at the bottom of the client area: %r" % (
        geo.status_rect,)
    assert geo.bar_h > 0 and geo.client_h > geo.bar_h, geo.client_h
    assert view_of(status)[0] == pytest.approx(1.0), status_text(status)
    assert chain.states()[name]["pid"] == pid


@pytest.mark.gui
def test_real_wheel_and_drag_change_the_zoom_and_the_offset_of_the_shown_editor(chains):
    """REQ-EDT-030 with real mouse input: one wheel notch zooms in at the pointer (zoom 1.00 to 1.10 in the status bar), a
    left drag of (80, 40) pixels moves the content by the movement divided by the zoom (offset -= movement / zoom)."""
    _skip_if_no_input()
    _enable_dpi_awareness()
    chain = chains("storage,engine", [])
    name, pid, hwnd, status = _open_editor(chain)
    geo = EditorWindowGeometry(hwnd, status)
    cx, cy = geo.canvas_center()
    with inputlock.input_lock():
        user32.SetForegroundWindow(hwnd)                          # best effort: the wheel goes to the window under the pointer
        assert user32.SetCursorPos(cx, cy), "SetCursorPos refused"
        before = view_of(status)
        assert _send_mouse(MOUSEEVENTF_WHEEL, WHEEL_DELTA) == 1, "SendInput refused the wheel"
        assert wait_until(lambda: (view_of(status) or before)[0] != before[0], scaled(5)), (
            "the wheel did not zoom: %r" % (status_text(status),))
        zoomed = view_of(status)
        assert zoomed[0] == pytest.approx(before[0] * 1.1, abs=0.01), (before, zoomed)
        # left drag of (80, 40) physical pixels, in ten steps with the button down
        assert user32.SetCursorPos(cx, cy)
        assert _send_mouse(MOUSEEVENTF_LEFTDOWN) == 1, "SendInput refused the button down"
        for step in range(1, 11):
            user32.SetCursorPos(cx + 8 * step, cy + 4 * step)
            time.sleep(0.03)
        assert _send_mouse(MOUSEEVENTF_LEFTUP) == 1, "SendInput refused the button up"
        after_drag = (cx + 80, cy + 40)
        assert user32.SetCursorPos(*after_drag)
        time.sleep(0.2)
    now = view_of(status)
    zoom = now[0]
    assert zoom == pytest.approx(zoomed[0], abs=0.01), (zoomed, now)     # a drag does not zoom
    assert now[1] == pytest.approx(zoomed[1] - 80 / zoom, abs=2), (zoomed, now)
    assert now[2] == pytest.approx(zoomed[2] - 40 / zoom, abs=2), (zoomed, now)
    assert chain.states()[name]["pid"] == pid, "the editor was restarted by the mouse input"
