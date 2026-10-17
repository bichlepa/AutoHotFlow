"""The input lock: a live holder keeps it past the stale limit, a dead holder's lock is taken over (pure Python)."""

import os
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


def test_the_session_check_skips_with_the_desktop_reason_only_without_a_usable_desktop():
    assert inputlock.session_skip_reason(True) is None
    assert inputlock.session_skip_reason(False) == inputlock.DESKTOP_UNUSABLE_REASON
    assert "input desktop" in inputlock.DESKTOP_UNUSABLE_REASON and "secure desktop" in inputlock.DESKTOP_UNUSABLE_REASON


def test_release_leaves_a_lock_of_someone_else(lockfile):
    with inputlock.input_lock(stale_s=STALE_S):
        lockfile.write_text("pid 1 since 0\n", encoding="ascii")      # replaced behind our back
    assert lockfile.exists()
