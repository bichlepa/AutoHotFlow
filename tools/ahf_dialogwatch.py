"""Watches for blocking dialogs (AHK error dialogs, MsgBox, ...) of started processes.

An unhandled AutoHotkey error or a stray MsgBox blocks a headless test run forever. This
module polls for visible dialog windows (class #32770) that belong to a watched process
tree, saves what a human would have seen (window title, readable control texts and a PNG
screenshot) into %TEMP%\\ahf_dialogs, closes the dialog and kills the owning process.

Windows only. Uses ctypes, no third-party packages besides psutil.
"""

import ctypes
import os
import struct
import tempfile
import threading
import time
import zlib
from ctypes import wintypes

import psutil

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32

WM_CLOSE = 0x0010
PW_RENDERFULLCONTENT = 0x2
DIALOG_CLASS = "#32770"
OUT_DIR = os.path.join(tempfile.gettempdir(), "ahf_dialogs")

WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
user32.SendMessageTimeoutW.argtypes = [wintypes.HWND, wintypes.UINT, ctypes.c_size_t, ctypes.c_size_t,
                                       wintypes.UINT, wintypes.UINT, ctypes.POINTER(ctypes.c_size_t)]
user32.SendMessageTimeoutW.restype = ctypes.c_size_t
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.PrintWindow.argtypes = [wintypes.HWND, wintypes.HDC, wintypes.UINT]
user32.GetDC.argtypes = [wintypes.HWND]
user32.GetDC.restype = wintypes.HDC
user32.ReleaseDC.argtypes = [wintypes.HWND, wintypes.HDC]
gdi32.CreateCompatibleDC.argtypes = [wintypes.HDC]
gdi32.CreateCompatibleDC.restype = wintypes.HDC
gdi32.CreateCompatibleBitmap.argtypes = [wintypes.HDC, ctypes.c_int, ctypes.c_int]
gdi32.CreateCompatibleBitmap.restype = wintypes.HBITMAP
gdi32.SelectObject.argtypes = [wintypes.HDC, wintypes.HGDIOBJ]
gdi32.SelectObject.restype = wintypes.HGDIOBJ
gdi32.DeleteObject.argtypes = [wintypes.HGDIOBJ]
gdi32.DeleteDC.argtypes = [wintypes.HDC]


class _BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG), ("biHeight", wintypes.LONG),
                ("biPlanes", wintypes.WORD), ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
                ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", wintypes.LONG),
                ("biYPelsPerMeter", wintypes.LONG), ("biClrUsed", wintypes.DWORD),
                ("biClrImportant", wintypes.DWORD)]


def _text(hwnd):
    buf = ctypes.create_unicode_buffer(4096)
    user32.GetWindowTextW(hwnd, buf, 4096)
    return buf.value


def _class(hwnd):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(hwnd, buf, 256)
    return buf.value


def _pid(hwnd):
    pid = wintypes.DWORD(0)
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    return pid.value


def _top_windows():
    found = []

    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            found.append(hwnd)
        return True

    user32.EnumWindows(WNDENUMPROC(cb), 0)
    return found


def _wm_text(hwnd):
    """Reads control text with WM_GETTEXT (works for RichEdit of another process)."""
    length = ctypes.c_size_t(0)
    ok = user32.SendMessageTimeoutW(hwnd, 0x000E, 0, 0, 0x2, 300, ctypes.byref(length))  # WM_GETTEXTLENGTH
    if not ok or length.value == 0 or length.value > 100000:
        return ""
    buf = ctypes.create_unicode_buffer(length.value + 1)
    res = ctypes.c_size_t(0)
    ok = user32.SendMessageTimeoutW(hwnd, 0x000D, length.value + 1, ctypes.addressof(buf), 0x2, 300,
                                    ctypes.byref(res))  # WM_GETTEXT
    return buf.value if ok else ""


def _child_texts(hwnd):
    items = []

    def cb(child, _):
        t = _text(child) or _wm_text(child)
        if t and _class(child).lower().startswith("richedit"):
            t = t.replace("\r", "\n")
        if t:
            items.append("[%s] %s" % (_class(child), t))
        return True

    user32.EnumChildWindows(hwnd, WNDENUMPROC(cb), 0)
    return items


def _screenshot_png(hwnd, path):
    """Renders the window with PrintWindow and writes a PNG. Returns True on success."""
    rect = wintypes.RECT()
    if not user32.GetWindowRect(hwnd, ctypes.byref(rect)):
        return False
    w, h = rect.right - rect.left, rect.bottom - rect.top
    if w <= 0 or h <= 0 or w > 4000 or h > 4000:
        return False
    screen_dc = user32.GetDC(None)
    mem_dc = gdi32.CreateCompatibleDC(screen_dc)
    bmp = gdi32.CreateCompatibleBitmap(screen_dc, w, h)
    old = gdi32.SelectObject(mem_dc, bmp)
    try:
        user32.PrintWindow(hwnd, mem_dc, PW_RENDERFULLCONTENT)
        hdr = _BITMAPINFOHEADER(ctypes.sizeof(_BITMAPINFOHEADER), w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
        pixels = ctypes.create_string_buffer(w * h * 4)
        got = gdi32.GetDIBits(mem_dc, bmp, 0, h, pixels, ctypes.byref(hdr), 0)
        if not got:
            return False
    finally:
        gdi32.SelectObject(mem_dc, old)
        gdi32.DeleteObject(bmp)
        gdi32.DeleteDC(mem_dc)
        user32.ReleaseDC(None, screen_dc)
    raw = bytearray()
    data = pixels.raw
    for y in range(h):
        raw.append(0)  # PNG filter type none
        row = data[y * w * 4:(y + 1) * w * 4]
        rgb = bytearray(w * 3)
        rgb[0::3], rgb[1::3], rgb[2::3] = row[2::4], row[1::4], row[0::4]  # BGRA -> RGB
        raw += rgb

    def chunk(tag, body):
        c = struct.pack(">I", len(body)) + tag + body
        return c + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    return True


class DialogEvent:
    def __init__(self, pid, process, title, texts, txt_path, png_path):
        self.pid, self.process, self.title, self.texts = pid, process, title, texts
        self.txt_path, self.png_path = txt_path, png_path

    def summary(self):
        body = " | ".join(self.texts) if self.texts else "(no readable text, see screenshot)"
        return "BLOCKING DIALOG of %s (pid %d): title=%r text=%s [files: %s]" % (
            self.process, self.pid, self.title, body, self.txt_path)


class DialogWatcher:
    """Background thread. Register root pids with watch(); their process trees are observed."""

    def __init__(self, poll_interval=0.15, kill_process=True):
        self._roots = set()
        self._events = []
        self._lock = threading.Lock()
        self._poll = poll_interval
        self._kill = kill_process
        self._stop = threading.Event()
        self._counter = 0
        self._thread = threading.Thread(target=self._run, name="ahf-dialogwatch", daemon=True)
        self._thread.start()

    def watch(self, pid):
        with self._lock:
            self._roots.add(pid)

    def events(self, pid=None):
        """Events seen so far (for the process tree of pid, or all)."""
        with self._lock:
            ev = list(self._events)
        if pid is None:
            return ev
        tree = self._tree({pid})
        return [e for e in ev if e.pid in tree]

    def stop(self):
        self._stop.set()

    def _tree(self, roots):
        pids = set(roots)
        for r in roots:
            try:
                pids.update(c.pid for c in psutil.Process(r).children(recursive=True))
            except psutil.Error:
                pass
        return pids

    def _run(self):
        while not self._stop.is_set():
            try:
                with self._lock:
                    roots = set(self._roots)
                if roots:
                    pids = self._tree(roots)
                    for hwnd in _top_windows():
                        pid = _pid(hwnd)
                        if pid in pids and _class(hwnd) == DIALOG_CLASS:
                            self._handle(hwnd, pid)
            except Exception:  # the watcher must never die
                pass
            self._stop.wait(self._poll)

    def _handle(self, hwnd, pid):
        os.makedirs(OUT_DIR, exist_ok=True)
        self._counter += 1
        base = os.path.join(OUT_DIR, "%s_pid%d_%d" % (time.strftime("%Y%m%d-%H%M%S"), pid, self._counter))
        try:
            pname = psutil.Process(pid).name()
        except psutil.Error:
            pname = "?"
        title, texts = _text(hwnd), _child_texts(hwnd)
        png = base + ".png"
        if not _screenshot_png(hwnd, png):
            png = ""
        txt = base + ".txt"
        with open(txt, "w", encoding="utf-8") as f:
            f.write("process: %s (pid %d)\ntitle: %s\n" % (pname, pid, title))
            f.write("\n".join(texts) + "\n")
            f.write("screenshot: %s\n" % (png or "(failed)"))
        ev = DialogEvent(pid, pname, title, texts, txt, png)
        with self._lock:
            self._events.append(ev)
        user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)
        if self._kill:
            time.sleep(0.2)
            try:
                p = psutil.Process(pid)
                if p.is_running():
                    p.kill()
            except psutil.Error:
                pass


_shared = None
_shared_lock = threading.Lock()


def shared_watcher():
    """Process-wide watcher (created on first use)."""
    global _shared
    with _shared_lock:
        if _shared is None:
            _shared = DialogWatcher()
        return _shared
