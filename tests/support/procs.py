"""Process helpers: start, tree kill, suspend/resume, and a cleanup guarantee.

Every process started through ProcessTracker is killed together with its children when
the tracker is closed. An atexit hook closes all live trackers, so processes do not survive
Ctrl+C or an interpreter exit either.
"""

import atexit
import subprocess
import threading

import psutil

CREATE_NO_WINDOW = 0x08000000

_live = set()
_live_lock = threading.Lock()


def _kill_tree(pid, timeout=5.0):
    """Kills pid and all its descendants. Returns the list of processes that are still alive."""
    try:
        parent = psutil.Process(pid)
    except psutil.NoSuchProcess:
        return []
    family = parent.children(recursive=True) + [parent]
    for p in family:
        try:
            p.kill()
        except psutil.NoSuchProcess:
            pass
    _, alive = psutil.wait_procs(family, timeout=timeout)
    return alive


class ProcessTracker:
    """Starts processes and remembers them until close()."""

    def __init__(self):
        self._procs = []
        self._closed = False
        with _live_lock:
            _live.add(self)

    def start(self, args, stdout=None, stderr=None, cwd=None):
        """Starts a process without a console window. stdout/stderr are file objects or None."""
        if self._closed:
            raise RuntimeError("ProcessTracker is closed")
        proc = subprocess.Popen(
            args,
            stdin=subprocess.DEVNULL,
            stdout=stdout,
            stderr=stderr,
            cwd=cwd,
            creationflags=CREATE_NO_WINDOW,
        )
        self._procs.append(proc)
        return proc

    def kill(self, proc, timeout=5.0):
        """Kills a process and its children. Returns True if nothing of the tree is left."""
        return not _kill_tree(proc.pid, timeout)

    def suspend(self, proc):
        psutil.Process(proc.pid).suspend()

    def resume(self, proc):
        psutil.Process(proc.pid).resume()

    def alive(self, proc):
        try:
            return psutil.Process(proc.pid).is_running() and psutil.Process(proc.pid).status() != psutil.STATUS_ZOMBIE
        except psutil.NoSuchProcess:
            return False

    def close(self):
        """Kills every tracked process tree. Returns the pids that survived (should be empty)."""
        if self._closed:
            return []
        self._closed = True
        survivors = []
        for proc in self._procs:
            if proc.poll() is not None:
                continue  # already exited; its pid may have been reused, do not touch it
            survivors.extend(p.pid for p in _kill_tree(proc.pid))
        self._procs = []
        with _live_lock:
            _live.discard(self)
        return survivors


@atexit.register
def _close_all_at_exit():
    with _live_lock:
        trackers = list(_live)
    for tracker in trackers:
        tracker.close()
