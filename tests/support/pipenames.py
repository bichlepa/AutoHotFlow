"""Name of the hub pipe of a supervisor (WI-0022 point 5, doc/PROTOCOL.md section 1).

Python twin of src/core/PipeNames.ahk: ahf.s<windows session id>.u<8 hex digits of the FNV-1a hash of the user SID>.<session>.hub
Tests ask this function instead of building the name themselves, so there is one place to change.
"""

import ctypes
from ctypes import wintypes

_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
_advapi32 = ctypes.WinDLL("advapi32", use_last_error=True)

_kernel32.GetCurrentProcess.restype = wintypes.HANDLE
_kernel32.GetCurrentProcessId.restype = wintypes.DWORD
_kernel32.LocalFree.argtypes = [ctypes.c_void_p]
_kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
_advapi32.OpenProcessToken.argtypes = [wintypes.HANDLE, wintypes.DWORD, ctypes.POINTER(wintypes.HANDLE)]
_advapi32.GetTokenInformation.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD,
                                          ctypes.POINTER(wintypes.DWORD)]
_advapi32.ConvertSidToStringSidW.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]

TOKEN_QUERY = 0x8
TOKEN_USER = 1


def windows_session_id():
    sid = wintypes.DWORD(0)
    if not _kernel32.ProcessIdToSessionId(_kernel32.GetCurrentProcessId(), ctypes.byref(sid)):
        raise OSError(ctypes.get_last_error(), "ProcessIdToSessionId failed")
    return sid.value


def user_sid_text():
    token = wintypes.HANDLE()
    if not _advapi32.OpenProcessToken(_kernel32.GetCurrentProcess(), TOKEN_QUERY, ctypes.byref(token)):
        raise OSError(ctypes.get_last_error(), "OpenProcessToken failed")
    try:
        need = wintypes.DWORD(0)
        _advapi32.GetTokenInformation(token, TOKEN_USER, None, 0, ctypes.byref(need))
        buf = ctypes.create_string_buffer(need.value)
        if not _advapi32.GetTokenInformation(token, TOKEN_USER, buf, need, ctypes.byref(need)):
            raise OSError(ctypes.get_last_error(), "GetTokenInformation failed")
        sid_ptr = ctypes.c_void_p.from_buffer(buf).value      # TOKEN_USER starts with the SID pointer
        text = ctypes.c_void_p()
        if not _advapi32.ConvertSidToStringSidW(sid_ptr, ctypes.byref(text)):
            raise OSError(ctypes.get_last_error(), "ConvertSidToStringSidW failed")
        try:
            return ctypes.wstring_at(text.value)
        finally:
            _kernel32.LocalFree(text)
    finally:
        _kernel32.CloseHandle(token)


def fnv1a32(text):
    h = 0x811C9DC5
    for ch in text:
        h = ((h ^ ord(ch)) * 0x01000193) & 0xFFFFFFFF
    return h


def user_tag():
    return "%08x" % fnv1a32(user_sid_text())


def hub_pipe(session):
    """Pipe name (without the pipe namespace prefix) of the hub of this session id for the current Windows user and session."""
    return "ahf.s%d.u%s.%s.hub" % (windows_session_id(), user_tag(), session)


def legacy_hub_pipe(session):
    """The name before WI-0022 (no Windows session, no user). Only for the test that a squatter on it is harmless."""
    return "ahf.%s.hub" % session
