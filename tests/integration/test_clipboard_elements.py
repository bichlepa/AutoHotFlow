"""WI-0123: end-to-end tests of the clipboard elements of the package Default: Get clipboard and Set clipboard, on the real
Windows clipboard (no seam: other programs use it too). The fixture saves the text of the clipboard of the user before each
test and puts it back after it. All tests of this file share the xdist group `clipboard`, so they never use the clipboard
at the same time.

The busy-clipboard test holds the clipboard open in this test process (the owner's copy of the clipboard is kept the same
way, the content is restored at the end). A clipboard that another program holds is not touched by the tests.
"""

import contextlib
import ctypes
import time
from ctypes import wintypes

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)

pytestmark = pytest.mark.xdist_group("clipboard")

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


@pytest.fixture(autouse=True)
def clipboard_kept():
    """The clipboard of the user is put back after every test of this file."""
    items = snapshot()
    yield
    restore(items)


def element_flow(name, cls, probe=None, **pars):
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    parts = [fb.trigger(), el]
    if probe:
        parts.append(fb.probe(probe))
    fb.chain(*parts)
    return fb


def test_get_clipboard_reads_the_text_into_a_variable(flows):
    set_text("Hallo Welt, äöü")
    runs = run_all(flows, [element_flow("get_clipboard", "Action_Get_Clipboard", probe="x", Varname="x")])
    assert not runs[0].exceptions, runs[0].steps
    assert runs[0].seen["x"].text == "Hallo Welt, äöü"


def test_set_clipboard_puts_the_text_on_the_clipboard(flows):
    runs = run_all(flows, [element_flow("set_clipboard", "Action_Set_Clipboard", text="AHF clipboard 123")])
    assert not runs[0].exceptions, runs[0].steps
    assert read_text() == "AHF clipboard 123"


def test_set_clipboard_with_an_empty_text_clears_it(flows):
    set_text("to be cleared")
    runs = run_all(flows, [element_flow("clear_clipboard", "Action_Set_Clipboard", text="")])
    assert not runs[0].exceptions, runs[0].steps
    assert read_text() is None


def test_a_busy_clipboard_is_an_exception_and_nothing_changes(flows):
    """MIGRATION M-0122: this process holds the clipboard open while the element runs."""
    set_text("keep")
    with open_clipboard():
        runs = run_all(flows, [element_flow("busy_clipboard", "Action_Set_Clipboard", text="new")])
    assert runs[0].exceptions and "could not be used" in runs[0].exceptions[0], runs[0].steps
    assert read_text() == "keep"
