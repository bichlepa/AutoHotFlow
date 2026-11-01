"""The Windows clipboard for the tests (WI-0123, WI-0131): reads, writes and saves the clipboard of the user. The tests of
the clipboard elements and of the clipboard trigger use it; all of them share the xdist group `clipboard`."""

import contextlib
import ctypes
import time
from ctypes import wintypes

CF_UNICODETEXT = 13
GMEM_MOVEABLE = 0x0002
user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
user32.OpenClipboard.argtypes = [wintypes.HWND]
user32.OpenClipboard.restype = wintypes.BOOL
user32.GetClipboardData.argtypes = [wintypes.UINT]
user32.GetClipboardData.restype = wintypes.HANDLE
user32.IsClipboardFormatAvailable.argtypes = [wintypes.UINT]
user32.IsClipboardFormatAvailable.restype = wintypes.BOOL
user32.EnumClipboardFormats.argtypes = [wintypes.UINT]
user32.EnumClipboardFormats.restype = wintypes.UINT
user32.SetClipboardData.argtypes = [wintypes.UINT, wintypes.HANDLE]
user32.SetClipboardData.restype = wintypes.HANDLE
user32.EmptyClipboard.restype = wintypes.BOOL
user32.CloseClipboard.restype = wintypes.BOOL
kernel32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
kernel32.GlobalAlloc.restype = wintypes.HGLOBAL
kernel32.GlobalLock.argtypes = [wintypes.HGLOBAL]
kernel32.GlobalLock.restype = ctypes.c_void_p
kernel32.GlobalUnlock.argtypes = [wintypes.HGLOBAL]
kernel32.GlobalSize.argtypes = [wintypes.HGLOBAL]
kernel32.GlobalSize.restype = ctypes.c_size_t
kernel32.GlobalFree.argtypes = [wintypes.HGLOBAL]


@contextlib.contextmanager
def open_clipboard():
    """The clipboard open for this process, with a bounded retry (another program may hold it for a moment)."""
    for _ in range(100):
        if user32.OpenClipboard(None):
            break
        time.sleep(0.01)
    else:
        raise AssertionError("the clipboard stays busy")
    try:
        yield
    finally:
        user32.CloseClipboard()


def snapshot():
    """Every format that holds memory (the formats that hold a handle are not copied): [(format, bytes)]."""
    items = []
    with open_clipboard():
        fmt = 0
        while True:
            fmt = user32.EnumClipboardFormats(fmt)
            if fmt == 0:
                break
            handle = user32.GetClipboardData(fmt)
            if not handle or fmt in (2, 3, 9, 14):      # bitmap, metafile, palette, enhanced metafile
                continue
            size = kernel32.GlobalSize(handle)
            ptr = kernel32.GlobalLock(handle)
            if ptr:
                items.append((fmt, ctypes.string_at(ptr, size)))
                kernel32.GlobalUnlock(handle)
    return items


def restore(items):
    with open_clipboard():
        user32.EmptyClipboard()
        for fmt, data in items:
            handle = kernel32.GlobalAlloc(GMEM_MOVEABLE, max(len(data), 1))
            ctypes.memmove(kernel32.GlobalLock(handle), data, len(data))
            kernel32.GlobalUnlock(handle)
            if not user32.SetClipboardData(fmt, handle):
                kernel32.GlobalFree(handle)


def set_text(text):
    data = (text + "\0").encode("utf-16-le")
    with open_clipboard():
        user32.EmptyClipboard()
        handle = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(data))
        ctypes.memmove(kernel32.GlobalLock(handle), data, len(data))
        kernel32.GlobalUnlock(handle)
        user32.SetClipboardData(CF_UNICODETEXT, handle)


def read_text():
    """The text of the clipboard, or None when it holds no text."""
    with open_clipboard():
        if not user32.IsClipboardFormatAvailable(CF_UNICODETEXT):
            return None
        handle = user32.GetClipboardData(CF_UNICODETEXT)
        return ctypes.wstring_at(kernel32.GlobalLock(handle))
