"""Runs an AutoHotkey v2 script headless and never hangs on error dialogs.

Usage:
    python tools/ahkrun.py [--timeout SECONDS] script.ahk [script args...]

What it does for the caller (humans and agents):
  * passes /ErrorStdOut=UTF-8, so load-time errors (syntax errors, class conflicts, ...)
    are printed to stderr instead of opening a dialog,
  * watches for any dialog that still appears (runtime errors, MsgBox): saves its text and a
    PNG screenshot to %TEMP%\\ahf_dialogs, closes it, kills the script, and prints the text,
  * kills the whole process tree after the timeout (default 60 s).

Exit codes: the script's own exit code; 97 = a dialog was caught; 98 = timeout; 99 = no interpreter.
Never call the interpreter directly with unknown flags: AHK v2 has no --version, it would try
to load a script of that name and show a dialog.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "tests", "support"))

from ahf_dialogwatch import shared_watcher  # noqa: E402
from ahk import find_ahk_exe  # noqa: E402

CREATE_NO_WINDOW = 0x08000000


def run(script, args=(), timeout=60.0, cwd=None):
    """Returns (returncode, stdout, stderr, dialogs). returncode 97/98 as documented above."""
    exe, reason = find_ahk_exe()
    if not exe:
        return 99, "", reason, []
    script = os.path.abspath(script)
    watcher = shared_watcher()
    proc = subprocess.Popen([exe, "/ErrorStdOut=UTF-8", script, *map(str, args)],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL,
                            cwd=cwd or os.path.dirname(os.path.abspath(script)),
                            creationflags=CREATE_NO_WINDOW)
    watcher.watch(proc.pid)
    try:
        out, err = proc.communicate(timeout=timeout)
        code = proc.returncode
    except subprocess.TimeoutExpired:
        import psutil
        try:
            parent = psutil.Process(proc.pid)
            for p in parent.children(recursive=True) + [parent]:
                p.kill()
        except psutil.Error:
            pass
        out, err = proc.communicate()
        code = 98
    dialogs = watcher.events(proc.pid)
    if dialogs and code != 98:
        code = 97
    return code, out.decode("utf-8", "replace"), err.decode("utf-8", "replace"), dialogs


def main(argv):
    timeout = 60.0
    if argv and argv[0] == "--timeout":
        timeout = float(argv[1])
        argv = argv[2:]
    if not argv:
        print(__doc__)
        return 2
    code, out, err, dialogs = run(argv[0], argv[1:], timeout)
    if out:
        sys.stdout.write(out)
    if err:
        sys.stderr.write(err)
    for d in dialogs:
        sys.stderr.write(d.summary() + "\n")
    if code == 98:
        sys.stderr.write("TIMEOUT after %.0f s, process tree killed\n" % timeout)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
