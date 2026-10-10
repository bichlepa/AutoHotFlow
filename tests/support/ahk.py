"""Locating the AutoHotkey v2 interpreter for the tests."""

import os

DEFAULT_EXE = r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
ENV_VAR = "AHF_AHK2_EXE"


def find_ahk_exe():
    """Returns (path, None) if an interpreter exists, else (None, reason).

    Environment variable AHF_AHK2_EXE wins over the default install path. It is not
    falling back silently: if it is set but missing, the reason says so.
    """
    override = os.environ.get(ENV_VAR)
    if override:
        if os.path.isfile(override):
            return override, None
        return None, "%s points to a missing file: %s" % (ENV_VAR, override)
    if os.path.isfile(DEFAULT_EXE):
        return DEFAULT_EXE, None
    return None, "AutoHotkey v2 not found at %s (set %s to override)" % (DEFAULT_EXE, ENV_VAR)
