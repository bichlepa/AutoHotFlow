"""WI-0095: automatic saving and backups of the flows in the engine (E0065, PROTOCOL 4.2 and 4.6, ARCHITECTURE 6.3).

A committed revision is written about 3 s after the last commit (at the latest 10 s after the first one). cmd.flow.save
writes at once. Shutdown writes what is pending. A backup is asked at the first write of an editing session (the field
`session` of cmd.flow.patch) and then at most every backup interval; a view patch never asks. A pending write of a flow
that is deleted is dropped.

The engine runs as in test_engine.py (a real process). The storage stand-in here records every cmd.storage.flow.write
with its backup flag and can hold or fail writes. Options of the engine that shorten the intervals are passed as
arguments (--backup-interval-ms is the clock of the backup rule: the tests do not change the system clock).
"""

import json
import time

import psutil
import pytest

from support.timing import scaled
from test_engine import (SLEEP, StorageStub, ask, collect_until, is_type, observer, pipe, flowdir, hub, runs,  # noqa: F401
                         wait_ready)
from test_role import RoleRun

FLOW = "skeleton"
FILE = "Flows/" + FLOW + ".json"
X_SAVED = 77


class RecordingStorage(StorageStub):
    """Records cmd.storage.flow.write (time, path, backup flag) and cmd.storage.flow.delete. A held write is answered by
    release(); `fail` writes are answered with an error first."""

    def __init__(self, pipe, datadir):
        super().__init__(pipe, datadir)
        self.writes = []
        self.deletes = []
        self.hold = False
        self.held = []
        self.fail = 0

    def _handle(self, msg):
        type_ = msg.get("type")
        if type_ == "cmd.storage.flow.write":
            payload = msg["payload"]
            self.writes.append({"at": time.monotonic(), "path": payload["path"], "backup": payload.get("backup") is True,
                                "text": payload["text"]})
            if self.hold:
                self.held.append(msg)
                return
            self._answer_write(msg)
            return
        if type_ == "cmd.storage.flow.delete":
            self.deletes.append(time.monotonic())
            target = self.datadir / "Flows" / (msg["payload"]["flowId"] + ".json")
            existed = target.is_file()
            if existed:
                target.unlink()
            self.client.reply(msg, {"ok": True, "existed": existed})
            return
        super()._handle(msg)

    def _answer_write(self, msg):
        if self.fail > 0:
            self.fail -= 1
            self.client.reply(msg, {"ok": False, "error": {"code": "internal", "message": "disk full (test)"}})
            return
        target = self.datadir / msg["payload"]["path"]
        target.write_text(msg["payload"]["text"], encoding="utf-8")
        self.client.reply(msg, {"ok": True})

    def release(self):
        while self.held:
            self._answer_write(self.held.pop(0))

    def writes_of_flow(self):
        return [w for w in self.writes if w["path"] == FILE]

    def backups(self):
        return [w for w in self.writes_of_flow() if w["backup"]]


@pytest.fixture
def storage(hub, pipe, flowdir):
    stub = RecordingStorage(pipe, flowdir).start()
    yield stub
    stub.close()


@pytest.fixture
def boot(procs, flowdir, runs, pipe, session_id, hub, storage):
    """Starts the engine with the given options. Every engine that is still running at the end is shut down."""
    started = []

    def start(*options, label="engine"):
        args = ["--role=engine", "--session=" + session_id, "--hub=" + pipe, "--data=" + str(flowdir), "--workers=0"]
        args.extend(options)
        run = RoleRun(procs, flowdir, label, args)
        runs.append(run)
        started.append(run)
        return run

    yield start
    for run in started:
        if run.proc.poll() is None:
            hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 2000})
            run.wait_exit(timeout=10)


def kill_engine(run):
    """Kills the AutoHotkey process of the engine (the wrapper ahkrun.py ends with it)."""
    for child in psutil.Process(run.proc.pid).children(recursive=True):
        child.kill()
    run.proc.wait(timeout=10)


def on_disk_x(flowdir):
    # the file is read while the storage may be writing it: a torn read counts as "not yet"
    try:
        return json.loads((flowdir / FILE).read_text(encoding="utf-8"))["allElements"][SLEEP]["x"]
    except (ValueError, OSError):
        return None


def wait_until(predicate, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(0.05)
    return predicate()


def patch(obs, base, ops, session=None):
    payload = {"flowId": FLOW, "baseRev": base, "ops": ops}
    if session is not None:
        payload["session"] = session
    answer = obs.request("engine", "cmd.flow.patch", payload, timeout=5)
    return answer["payload"]


def move(x):
    return {"op": "element.update", "id": SLEEP, "fields": {"x": x}}


def view(zoom):
    return {"op": "flow.settings", "settings": {"zoomFactor": zoom}, "view": True}


# --- the write-behind ------------------------------------------------------------------------------------------------

def test_a_commit_is_written_about_3_s_later_without_a_save(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    run = boot()
    wait_ready(obs)
    t0 = time.monotonic()
    assert patch(obs, 1, [move(X_SAVED)])["ok"] is True
    assert on_disk_x(flowdir) != X_SAVED, "the commit is not written at once"
    assert wait_until(lambda: on_disk_x(flowdir) == X_SAVED, timeout=scaled(8.0))
    elapsed = time.monotonic() - t0
    assert 2.0 <= elapsed, "written after %.2f s, the delay is about 3 s" % elapsed
    assert len(storage.writes_of_flow()) == 1
    obs.close()


@pytest.mark.slow
def test_patches_every_second_give_a_write_at_least_every_10_s(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    boot()
    wait_ready(obs)
    rev = 1
    t0 = time.monotonic()
    while time.monotonic() - t0 < scaled(22.0):
        rev += 1
        assert patch(obs, rev - 1, [move(X_SAVED + rev)])["ok"] is True
        time.sleep(1.0)
    last = X_SAVED + rev
    assert wait_until(lambda: on_disk_x(flowdir) == last, timeout=scaled(6.0))
    times = [w["at"] for w in storage.writes_of_flow()]
    assert len(times) >= 2, "a write during the 22 s of patches and one after"
    gaps = [b - a for a, b in zip([t0] + times, times)]
    assert max(gaps) <= scaled(10.5), "a gap of %.1f s between two writes" % max(gaps)
    obs.close()


def test_cmd_flow_save_writes_at_once_and_answers_with_the_saved_revision(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    boot()
    wait_ready(obs)
    assert patch(obs, 1, [move(X_SAVED)])["ok"] is True
    t0 = time.monotonic()
    answer = ask(obs, "cmd.flow.save", {"flowId": FLOW})
    assert answer["savedRev"] == 2, answer
    assert time.monotonic() - t0 < 1.5, "the save does not wait for the delay"
    assert on_disk_x(flowdir) == X_SAVED
    saved = collect_until(obs, is_type("evt.flow.saved"), timeout=3)[-1][1]["payload"]
    assert saved == {"flowId": FLOW, "savedRev": 2, "epoch": saved["epoch"], "seq": saved["seq"]}, saved
    obs.close()


def test_a_commit_during_a_write_gets_another_write_afterwards(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    boot()
    wait_ready(obs)
    storage.hold = True
    assert patch(obs, 1, [move(X_SAVED)])["ok"] is True
    assert wait_until(lambda: len(storage.writes_of_flow()) == 1, timeout=scaled(8.0))
    assert patch(obs, 2, [move(X_SAVED + 1)])["rev"] == 3, "a commit while the write is in flight"
    storage.hold = False
    storage.release()
    assert wait_until(lambda: on_disk_x(flowdir) == X_SAVED + 1, timeout=scaled(10.0))
    assert len(storage.writes_of_flow()) == 2
    obs.close()


def test_a_failed_write_is_reported_once_and_retried_until_it_succeeds(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    boot()
    wait_ready(obs)
    storage.fail = 2
    assert patch(obs, 1, [move(X_SAVED)])["ok"] is True
    assert wait_until(lambda: on_disk_x(flowdir) == X_SAVED, timeout=scaled(15.0))
    seen = [m for _, m in collect_until(obs, is_type("evt.storage.error"), timeout=0.5)]
    errors = [m for m in seen if m["type"] == "evt.storage.error"]
    assert len(errors) == 1, seen
    assert errors[0]["payload"]["op"] == "flow.write" and errors[0]["payload"]["path"] == FILE
    assert len(storage.writes_of_flow()) == 3, "two failures and the write that succeeds"
    obs.close()


def test_a_save_whose_write_fails_answers_with_the_error(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    boot()
    wait_ready(obs)
    storage.fail = 1
    assert patch(obs, 1, [move(X_SAVED)])["ok"] is True
    answer = obs.request("engine", "cmd.flow.save", {"flowId": FLOW}, timeout=10)["payload"]
    assert answer["ok"] is False and answer["error"]["code"] == "internal", answer
    obs.close()


# --- shutdown and kill ----------------------------------------------------------------------------------------------

def test_a_shutdown_writes_the_pending_commit_before_it_says_bye(pipe, flowdir, storage, hub, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    run = boot()
    wait_ready(obs)
    assert patch(obs, 1, [move(X_SAVED)])["ok"] is True
    hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 3000})
    assert run.wait_exit(timeout=10) == 0, run.stderr_text()
    # the write is on its way to storage (the stand-in answers it on its own thread)
    assert wait_until(lambda: on_disk_x(flowdir) == X_SAVED, timeout=scaled(3.0)), "the pending commit was not written"
    obs.close()


def test_a_killed_engine_keeps_the_commits_that_were_written(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    run = boot()
    wait_ready(obs)
    assert patch(obs, 1, [move(X_SAVED)])["ok"] is True
    assert wait_until(lambda: on_disk_x(flowdir) == X_SAVED, timeout=scaled(8.0))
    kill_engine(run)
    assert on_disk_x(flowdir) == X_SAVED
    obs.close()


def test_a_delete_drops_the_pending_write_of_the_flow(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    boot()
    wait_ready(obs)
    assert patch(obs, 1, [move(X_SAVED)])["ok"] is True
    answer = obs.request("engine", "cmd.flow.delete", {"flowId": FLOW}, timeout=10)["payload"]
    assert answer["ok"] is True, answer
    time.sleep(scaled(4.5))
    assert not (flowdir / FILE).exists(), "the pending write must not re-create the deleted file"
    assert storage.writes_of_flow() == []
    obs.close()


# --- backups ----------------------------------------------------------------------------------------------------------

def test_a_session_gets_one_backup_at_its_first_write_and_a_new_session_another(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    boot()
    wait_ready(obs)
    rev = 1
    for i in range(6):                    # six patches of session S1 in about 3 s
        rev += 1
        assert patch(obs, rev - 1, [move(X_SAVED + i)], session="S1")["ok"] is True
        time.sleep(0.5)
    assert wait_until(lambda: on_disk_x(flowdir) == X_SAVED + 5, timeout=scaled(8.0))
    assert len(storage.backups()) == 1, "the first write of the session asks for the backup"
    rev += 1
    assert patch(obs, rev - 1, [move(1)], session="S2")["ok"] is True
    assert wait_until(lambda: len(storage.backups()) == 2, timeout=scaled(8.0))
    obs.close()


def test_a_patch_without_a_session_follows_the_backup_interval(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    boot("--backup-interval-ms=1000")
    wait_ready(obs)
    assert patch(obs, 1, [move(X_SAVED)])["ok"] is True
    assert wait_until(lambda: on_disk_x(flowdir) == X_SAVED, timeout=scaled(8.0))
    assert len(storage.backups()) == 1, "the first write since the start has no backup yet"
    assert patch(obs, 2, [move(X_SAVED + 1)])["ok"] is True
    assert wait_until(lambda: on_disk_x(flowdir) == X_SAVED + 1, timeout=scaled(8.0))
    assert len(storage.backups()) == 2, "the interval has passed: the clock of the test is the option"
    obs.close()


def test_a_view_patch_never_asks_for_a_backup(pipe, flowdir, storage, boot):
    obs = observer(pipe, "engine", "flow:" + FLOW)
    boot()
    wait_ready(obs)
    assert patch(obs, 1, [move(X_SAVED)], session="S1")["ok"] is True
    assert wait_until(lambda: on_disk_x(flowdir) == X_SAVED, timeout=scaled(8.0))
    assert len(storage.backups()) == 1
    assert patch(obs, 2, [view(1.5)], session="S2")["ok"] is True
    assert wait_until(lambda: len(storage.writes_of_flow()) == 2, timeout=scaled(8.0))
    assert len(storage.backups()) == 1, "a view patch of a new session does not ask"
    assert storage.writes_of_flow()[-1]["backup"] is False
    obs.close()
