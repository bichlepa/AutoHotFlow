"""Overlapped Win32 named pipes for the test support code (client and hub side).

Overlapped I/O is required: a synchronous pipe handle serializes read and write,
so a reader thread would block the writer. Each direction has its own OVERLAPPED
structure and event. Writes are serialized by a lock.
"""

import ctypes
import threading
from ctypes import wintypes

PIPE_PREFIX = "\\\\.\\pipe\\"

GENERIC_READ = 0x80000000
GENERIC_WRITE = 0x40000000
OPEN_EXISTING = 3
FILE_FLAG_OVERLAPPED = 0x40000000
PIPE_ACCESS_DUPLEX = 0x00000003
PIPE_TYPE_BYTE = 0x00000000
PIPE_READMODE_BYTE = 0x00000000
PIPE_WAIT = 0x00000000
PIPE_REJECT_REMOTE_CLIENTS = 0x00000008
PIPE_UNLIMITED_INSTANCES = 255
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value

ERROR_FILE_NOT_FOUND = 2
ERROR_OPERATION_ABORTED = 995
ERROR_IO_PENDING = 997
ERROR_PIPE_CONNECTED = 535
ERROR_PIPE_BUSY = 231
ERROR_BROKEN_PIPE = 109
ERROR_NO_DATA = 232
WAIT_OBJECT_0 = 0
WAIT_TIMEOUT = 258

CHUNK = 65536

_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)


class OVERLAPPED(ctypes.Structure):
    _fields_ = [
        ("Internal", ctypes.c_size_t),
        ("InternalHigh", ctypes.c_size_t),
        ("Offset", wintypes.DWORD),
        ("OffsetHigh", wintypes.DWORD),
        ("hEvent", wintypes.HANDLE),
    ]


def _bind(name, restype, *argtypes):
    fn = getattr(_kernel32, name)
    fn.restype = restype
    fn.argtypes = list(argtypes)
    return fn


_CreateNamedPipeW = _bind("CreateNamedPipeW", wintypes.HANDLE, wintypes.LPCWSTR, wintypes.DWORD,
                          wintypes.DWORD, wintypes.DWORD, wintypes.DWORD, wintypes.DWORD,
                          wintypes.DWORD, ctypes.c_void_p)
_CreateFileW = _bind("CreateFileW", wintypes.HANDLE, wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                     ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE)
_ConnectNamedPipe = _bind("ConnectNamedPipe", wintypes.BOOL, wintypes.HANDLE, ctypes.c_void_p)
_DisconnectNamedPipe = _bind("DisconnectNamedPipe", wintypes.BOOL, wintypes.HANDLE)
_ReadFile = _bind("ReadFile", wintypes.BOOL, wintypes.HANDLE, ctypes.c_void_p, wintypes.DWORD,
                  ctypes.POINTER(wintypes.DWORD), ctypes.POINTER(OVERLAPPED))
_WriteFile = _bind("WriteFile", wintypes.BOOL, wintypes.HANDLE, ctypes.c_void_p, wintypes.DWORD,
                   ctypes.POINTER(wintypes.DWORD), ctypes.POINTER(OVERLAPPED))
_GetOverlappedResult = _bind("GetOverlappedResult", wintypes.BOOL, wintypes.HANDLE,
                             ctypes.POINTER(OVERLAPPED), ctypes.POINTER(wintypes.DWORD), wintypes.BOOL)
_CreateEventW = _bind("CreateEventW", wintypes.HANDLE, ctypes.c_void_p, wintypes.BOOL, wintypes.BOOL,
                      wintypes.LPCWSTR)
_ResetEvent = _bind("ResetEvent", wintypes.BOOL, wintypes.HANDLE)
_WaitForSingleObject = _bind("WaitForSingleObject", wintypes.DWORD, wintypes.HANDLE, wintypes.DWORD)
_CancelIoEx = _bind("CancelIoEx", wintypes.BOOL, wintypes.HANDLE, ctypes.POINTER(OVERLAPPED))
_CloseHandle = _bind("CloseHandle", wintypes.BOOL, wintypes.HANDLE)


class PipeClosed(Exception):
    """The other end is gone (broken pipe)."""


def _last_error():
    return ctypes.get_last_error()


def full_name(name):
    """Pipe name without prefix -> \\\\.\\pipe\\<name>."""
    return PIPE_PREFIX + name


class OverlappedPipe:
    """One overlapped pipe handle. read_some() is used by one reader thread, write_all() by any thread."""

    def __init__(self, handle):
        if handle is None or handle == INVALID_HANDLE_VALUE:
            raise OSError("invalid pipe handle")
        self._h = handle
        self._rbuf = (ctypes.c_char * CHUNK)()
        self._rov = OVERLAPPED()
        self._rev = _CreateEventW(None, True, False, None)
        self._rov.hEvent = self._rev
        self._wov = OVERLAPPED()
        self._wev = _CreateEventW(None, True, False, None)
        self._wov.hEvent = self._wev
        self._cov = OVERLAPPED()
        self._cev = _CreateEventW(None, True, False, None)
        self._cov.hEvent = self._cev
        self._wlock = threading.Lock()
        self._closed = False

    # --- server side -------------------------------------------------------
    @classmethod
    def create_server(cls, name):
        """Creates one listening pipe instance (not yet connected)."""
        mode = PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED
        pipe_mode = PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS
        h = _CreateNamedPipeW(full_name(name), mode, pipe_mode, PIPE_UNLIMITED_INSTANCES,
                              CHUNK, CHUNK, 0, None)
        if h is None or h == INVALID_HANDLE_VALUE:
            raise OSError(_last_error(), "CreateNamedPipeW failed")
        return cls(h)

    def wait_connect(self, timeout_s):
        """Waits up to timeout_s for a client. Returns True if connected, False on timeout."""
        _ResetEvent(self._cev)
        ok = _ConnectNamedPipe(self._h, ctypes.byref(self._cov))
        if ok:
            return True
        err = _last_error()
        if err == ERROR_PIPE_CONNECTED:
            return True
        if err != ERROR_IO_PENDING:
            raise OSError(err, "ConnectNamedPipe failed")
        if _WaitForSingleObject(self._cev, int(timeout_s * 1000)) == WAIT_TIMEOUT:
            _CancelIoEx(self._h, ctypes.byref(self._cov))
            n = wintypes.DWORD()
            _GetOverlappedResult(self._h, ctypes.byref(self._cov), ctypes.byref(n), True)
            return False
        return True

    # --- client side -------------------------------------------------------
    @classmethod
    def connect_client(cls, name, timeout_s):
        """Opens the pipe as a client, retrying while no server instance exists yet."""
        import time

        deadline = time.monotonic() + timeout_s
        while True:
            h = _CreateFileW(full_name(name), GENERIC_READ | GENERIC_WRITE, 0, None, OPEN_EXISTING,
                             FILE_FLAG_OVERLAPPED, None)
            if h is not None and h != INVALID_HANDLE_VALUE:
                return cls(h)
            err = _last_error()
            if err not in (ERROR_FILE_NOT_FOUND, ERROR_PIPE_BUSY):
                raise OSError(err, "CreateFileW failed for pipe " + name)
            if time.monotonic() >= deadline:
                raise TimeoutError("pipe " + name + " not available after %.1f s" % timeout_s)
            time.sleep(0.02)

    def disconnect(self):
        _DisconnectNamedPipe(self._h)

    # --- I/O ---------------------------------------------------------------
    def read_some(self, timeout_s):
        """Returns the bytes available (at most CHUNK), or None on timeout. Raises PipeClosed."""
        if self._closed:
            raise PipeClosed("closed")
        _ResetEvent(self._rev)
        n = wintypes.DWORD()
        ok = _ReadFile(self._h, ctypes.addressof(self._rbuf), CHUNK, ctypes.byref(n), ctypes.byref(self._rov))
        if not ok:
            err = _last_error()
            if err in (ERROR_BROKEN_PIPE, ERROR_NO_DATA):
                raise PipeClosed("broken pipe")
            if err != ERROR_IO_PENDING:
                raise OSError(err, "ReadFile failed")
            if _WaitForSingleObject(self._rev, int(timeout_s * 1000)) == WAIT_TIMEOUT:
                _CancelIoEx(self._h, ctypes.byref(self._rov))
                # The read may have completed between the wait and the cancel (the thread can be
                # descheduled there): then the cancel does nothing and the bytes are in `n`.
                # Returning None would drop them silently.
                if _GetOverlappedResult(self._h, ctypes.byref(self._rov), ctypes.byref(n), True) and n.value > 0:
                    return bytes(self._rbuf[: n.value])
                return None
            if not _GetOverlappedResult(self._h, ctypes.byref(self._rov), ctypes.byref(n), False):
                err = _last_error()
                if err in (ERROR_BROKEN_PIPE, ERROR_NO_DATA):
                    raise PipeClosed("broken pipe")
                if err == ERROR_OPERATION_ABORTED:
                    return None
                raise OSError(err, "GetOverlappedResult (read) failed")
        if n.value == 0:
            raise PipeClosed("end of stream")
        return bytes(self._rbuf[: n.value])

    def write_all(self, data, timeout_s=5.0):
        """Writes all bytes. Raises PipeClosed if the peer is gone, TimeoutError if the write stalls."""
        if self._closed:
            raise PipeClosed("closed")
        with self._wlock:
            view = (ctypes.c_char * len(data)).from_buffer_copy(data)
            written = 0
            while written < len(data):
                n = wintypes.DWORD()
                _ResetEvent(self._wev)
                address = ctypes.addressof(view) + written
                ok = _WriteFile(self._h, address, len(data) - written, ctypes.byref(n), ctypes.byref(self._wov))
                if not ok:
                    err = _last_error()
                    if err in (ERROR_BROKEN_PIPE, ERROR_NO_DATA):
                        raise PipeClosed("broken pipe")
                    if err != ERROR_IO_PENDING:
                        raise OSError(err, "WriteFile failed")
                    if _WaitForSingleObject(self._wev, int(timeout_s * 1000)) == WAIT_TIMEOUT:
                        _CancelIoEx(self._h, ctypes.byref(self._wov))
                        _GetOverlappedResult(self._h, ctypes.byref(self._wov), ctypes.byref(n), True)
                        raise TimeoutError("write stalled for %.1f s" % timeout_s)
                    if not _GetOverlappedResult(self._h, ctypes.byref(self._wov), ctypes.byref(n), False):
                        err = _last_error()
                        if err in (ERROR_BROKEN_PIPE, ERROR_NO_DATA):
                            raise PipeClosed("broken pipe")
                        raise OSError(err, "GetOverlappedResult (write) failed")
                written += n.value
            return True

    def close(self):
        """Cancels pending I/O and closes the pipe handle. Safe to call more than once.

        The event handles are left open on purpose: a reader thread may still wait on
        them for a moment after the cancel. They are released with the process.
        """
        if self._closed:
            return
        self._closed = True
        _CancelIoEx(self._h, None)
        _CloseHandle(self._h)
