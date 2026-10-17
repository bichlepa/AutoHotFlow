"""The input lock: a live holder keeps it past the stale limit, a dead holder's lock is taken over (pure Python)."""

import os
import subprocess
import threading
import time

import pytest

from support import inputlock

STALE_S = 0.6


@pytest.fixture
def lockfile(tmp_path, monkeypatch):
    path = tmp_path / inputlock.LOCK_NAME
    monkeypatch.setattr(inputlock, "lock_path", lambda: path)
    return path


def test_a_refreshed_lock_is_not_taken_over_after_the_stale_limit(lockfile):
    acquired = threading.Event()
    release = threading.Event()

    def holder():
        with inputlock.input_lock(stale_s=STALE_S):
            acquired.set()
            release.wait(10)

    thread = threading.Thread(target=holder)
    thread.start()
    try:
        assert acquired.wait(5)
        time.sleep(STALE_S * 3)                    # well past the stale limit; the heartbeat keeps the file young
        with pytest.raises(TimeoutError):
            with inputlock.input_lock(wait_s=STALE_S * 2, stale_s=STALE_S):
                pytest.fail("the lock of a living holder was taken over")
    finally:
        release.set()
        thread.join()
    assert not lockfile.exists()
    with inputlock.input_lock(wait_s=1, stale_s=STALE_S):    # free again after the release
        pass


def test_the_lock_of_a_dead_holder_is_taken_over(lockfile):
    lockfile.write_text("pid 1 since 0\n", encoding="ascii")
    old = time.time() - STALE_S * 10
    os.utime(str(lockfile), (old, old))
    with inputlock.input_lock(wait_s=2, stale_s=STALE_S):
        assert lockfile.read_text(encoding="ascii").startswith("pid %d " % os.getpid())
    assert not lockfile.exists()
    assert not list(lockfile.parent.glob(inputlock.LOCK_NAME + ".stale.*"))      # no renamed leftovers


def test_a_fresh_lock_that_is_renamed_by_mistake_is_given_back(lockfile):
    lockfile.write_text("pid 1 since 0\n", encoding="ascii")          # fresh: mtime is now
    inputlock._take_over(lockfile, STALE_S)
    assert lockfile.exists()
    assert not list(lockfile.parent.glob(inputlock.LOCK_NAME + ".stale.*"))


@pytest.mark.parametrize("desktop_open, logonui, expected", [
    (False, False, inputlock.DESKTOP_UNUSABLE_REASON),     # desktop closed
    (True, True, inputlock.DESKTOP_UNUSABLE_REASON),       # LogonUI running (locked; the desktop still opens)
    (True, False, None),                                   # both fine
])
def test_the_session_check_skips_when_the_desktop_is_closed_or_locked(desktop_open, logonui, expected):
    assert inputlock.session_skip_reason(desktop_open, logonui) == expected


def test_logonui_check_treats_a_failed_tasklist_as_not_locked(monkeypatch):
    def broken(*args, **kwargs):
        raise subprocess.TimeoutExpired(cmd="tasklist", timeout=5)
    monkeypatch.setattr(inputlock.subprocess, "run", broken)
    assert inputlock.logonui_running() is False


@pytest.mark.parametrize("stdout, expected", [
    (b"LogonUI.exe  21524 Console  1  50.000 K\r\n", True),
    (b"\x81\x9a non-ASCII OEM text, no lock screen\r\n", False),    # the OEM code page is not cp1252: no decode error
    (b"INFO: No tasks are running which match the specified criteria.\r\n", False),
    (None, False),                                                  # no output at all: not locked
])
def test_logonui_check_reads_the_output_as_bytes(monkeypatch, stdout, expected):
    fake = subprocess.CompletedProcess(args=["tasklist"], returncode=0, stdout=stdout, stderr=b"")
    monkeypatch.setattr(inputlock.subprocess, "run", lambda *a, **k: fake)
    assert inputlock.logonui_running() is expected


def test_release_leaves_a_lock_of_someone_else(lockfile):
    with inputlock.input_lock(stale_s=STALE_S):
        lockfile.write_text("pid 1 since 0\n", encoding="ascii")      # replaced behind our back
    assert lockfile.exists()
