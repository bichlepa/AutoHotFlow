"""WI-27: worker pool lifecycle. Supervisor side (cmd.process.spawn, cmd.process.kill, sys.busy), then the
pool rules of the engine (src/engine/WorkerBridge.ahk).

The supervisor runs as a real process (tools/ahkrun.py). A Python client named "engine" plays the engine and
sends the commands; other names play a foreign sender. Workers are real worker processes.
"""

import time

import psutil
import pytest

from support.ahfclient import AhfClient
from support.timing import scaled
from test_supervisor import (EXIT_OK, Sup, alive, connect, event, process_list, request_ok, wait_ready, watch_for)

READY_S = 10.0
KILL_BUDGET_S = scaled(2.0)


@pytest.fixture
def started(procs, datadir, session_id):
    sups = []

    def make(*args, **kw):
        s = Sup(procs, datadir, session_id, *args, **kw)
        sups.append(s)
        return s

    yield make
    for s in sups:
        s.close()


@pytest.fixture
def clients():
    made = []

    def make(pipe, name):
        c = connect(pipe, name)
        made.append(c)
        return c

    yield make
    for c in made:
        try:
            c.close()
        except Exception:
            pass


def ask(client, to, type_, payload=None, timeout=5.0):
    return client.request(to, type_, payload or {}, timeout=timeout)["payload"]


def error_code(answer):
    assert not answer.get("ok"), answer
    return answer["error"]["code"]


# --- cmd.process.spawn: rights --------------------------------------------------------------------

def test_spawn_from_the_engine_starts_a_worker_with_the_next_number(started, clients):
    sup = started()
    engine = clients(sup.pipe, "engine")
    first = ask(engine, "supervisor", "cmd.process.spawn", {"role": "worker"})
    second = ask(engine, "supervisor", "cmd.process.spawn", {"role": "worker"})
    assert first["ok"] and first["name"] == "worker:1", first
    assert second["ok"] and second["name"] == "worker:2", second
    assert wait_ready(engine, ["worker:1", "worker:2"], timeout=READY_S) is not None, sup.text()
    states = {p["name"]: p for p in process_list(engine)}
    assert states["worker:1"]["role"] == "worker" and states["worker:1"]["pid"] > 0


def test_spawn_from_another_sender_is_denied(started, clients):
    sup = started()
    other = clients(sup.pipe, "manager")
    assert error_code(ask(other, "supervisor", "cmd.process.spawn", {"role": "worker"})) == "denied"
    assert not [p for p in process_list(other) if p["name"].startswith("worker:")]


def test_spawn_of_a_role_other_than_worker_is_denied(started, clients):
    sup = started()
    engine = clients(sup.pipe, "engine")
    for role in ("storage", "engine", "manager", "supervisor"):
        assert error_code(ask(engine, "supervisor", "cmd.process.spawn", {"role": role})) == "denied", role
    assert error_code(ask(engine, "supervisor", "cmd.process.spawn", {})) == "bad_payload"
    assert not process_list(engine)


def test_spawn_above_the_worker_limit_is_busy(started, clients):
    sup = started("--test-roles", "--worker-limit=2")
    engine = clients(sup.pipe, "engine")
    assert ask(engine, "supervisor", "cmd.process.spawn", {"role": "worker"})["ok"]
    assert ask(engine, "supervisor", "cmd.process.spawn", {"role": "worker"})["ok"]
    assert error_code(ask(engine, "supervisor", "cmd.process.spawn", {"role": "worker"})) == "busy"


# --- cmd.process.kill: rights and effect -----------------------------------------------------------

def test_kill_from_another_sender_is_denied_and_the_worker_lives(started, clients):
    sup = started()
    engine = clients(sup.pipe, "engine")
    other = clients(sup.pipe, "manager")
    name = ask(engine, "supervisor", "cmd.process.spawn", {"role": "worker"})["name"]
    assert wait_ready(engine, [name], timeout=READY_S) is not None, sup.text()
    assert error_code(ask(other, "supervisor", "cmd.process.kill", {"name": name, "reason": "test"})) == "denied"
    state = {p["name"]: p for p in process_list(engine)}[name]
    assert state["state"] == "ready" and alive(state["pid"])


def test_kill_of_a_name_other_than_worker_is_denied(started, clients):
    sup = started("--start=echo:a", "--test-roles")
    engine = clients(sup.pipe, "engine")
    assert wait_ready(engine, ["echo:a"], timeout=READY_S) is not None, sup.text()
    for name in ("echo:a", "engine", "storage", "supervisor", "worker", "workers:1"):
        assert error_code(ask(engine, "supervisor", "cmd.process.kill", {"name": name, "reason": "t"})) == "denied", name
    assert {p["name"]: p for p in process_list(engine)}["echo:a"]["state"] == "ready"


def test_kill_of_an_unknown_worker_is_not_found(started, clients):
    sup = started()
    engine = clients(sup.pipe, "engine")
    assert error_code(ask(engine, "supervisor", "cmd.process.kill", {"name": "worker:9", "reason": "t"})) == "not_found"
    assert error_code(ask(engine, "supervisor", "cmd.process.kill", {"reason": "t"})) == "bad_payload"


def test_kill_ends_the_worker_as_a_planned_exit_and_the_supervisor_still_exits_with_0(started, clients):
    sup = started()
    engine = clients(sup.pipe, "engine")
    watch = watch_for(clients(sup.pipe, "obs"))
    name = ask(engine, "supervisor", "cmd.process.spawn", {"role": "worker"})["name"]
    pid = wait_ready(engine, [name], timeout=READY_S)[name][1]
    t0 = time.perf_counter()
    assert ask(engine, "supervisor", "cmd.process.kill", {"name": name, "reason": "test"})["ok"]
    exited = watch.wait(event("evt.process.exited", name=name), timeout=KILL_BUDGET_S)
    assert exited is not None, "no evt.process.exited:\n" + sup.text()
    print("MEASURE kill -> evt.process.exited (ms): %.1f" % ((exited[0] - t0) * 1000))
    assert exited[1]["payload"]["reason"] == "killed" and exited[1]["payload"]["clean"] is False, exited[1]
    assert not watch.find(event("evt.process.crashed", name=name))
    assert not watch.find(event("evt.process.restarted", name=name))
    assert not alive(pid)
    # a second kill of the ended worker is not an error
    assert ask(engine, "supervisor", "cmd.process.kill", {"name": name, "reason": "again"})["ok"]
    assert ask(engine, "supervisor", "cmd.app.exit", {})["ok"]
    assert sup.wait_exit(timeout=10) == EXIT_OK, sup.text()
    watch.stop()


def test_spawn_during_shutdown_is_refused(started, clients):
    sup = started("--start=slow_shutdown:s", "--test-roles")
    engine = clients(sup.pipe, "engine")
    assert wait_ready(engine, ["slow_shutdown:s"], timeout=READY_S) is not None, sup.text()
    assert ask(engine, "supervisor", "cmd.app.exit", {"deadlineMs": 4000})["started"] is True
    deadline = time.monotonic() + 2.0
    code = ""
    while time.monotonic() < deadline:
        answer = ask(engine, "supervisor", "cmd.process.spawn", {"role": "worker"})
        if not answer.get("ok"):
            code = answer["error"]["code"]
            break
        time.sleep(0.05)
    assert code == "shutting_down", code
    sup.wait_exit(timeout=15)

