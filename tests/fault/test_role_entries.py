"""WI-0047-PREP (E0041): every role starts from its own entry script (src/entry/<role>.ahk) and reports ready.

The product supervisor (src/AutoHotFlow.ahk, no test options) starts storage, engine, manager, debug and, on request
of the engine, a worker. Each of them answers cmd.diag.snapshot (WI-0028) with the state ready, and the command line of
its process names the entry of its role. The placeholders (triggerhost, editor) start and say that they are not
implemented. An entry knows only its own role. Which classes a role registers: tests/test_element_includes.py.
"""

import subprocess
import sys
from pathlib import Path

import psutil
import pytest

import faultkit
from faultkit import STUB_OPTS, request_ok

from faultfixtures import chains  # noqa: F401  (fixture)
from support import snapshotschema

pytestmark = pytest.mark.fault

ROOT = Path(__file__).resolve().parents[2]
PRODUCT_ENTRY = ROOT / "src" / "AutoHotFlow.ahk"
ENTRY_DIR = ROOT / "src" / "entry"
AHKRUN = ROOT / "tools" / "ahkrun.py"
READY_S = 30.0
EXIT_BAD_ARGS = 2
EXIT_NOT_IMPLEMENTED = 3


def test_every_role_of_the_product_starts_from_its_own_entry_and_reports_ready(chains, datadir, monkeypatch):
    monkeypatch.setattr(faultkit, "ENTRY", PRODUCT_ENTRY)
    chain = chains("storage,engine,manager,debug", STUB_OPTS)
    chain.wait_ready(["storage", "engine", "manager", "debug", "worker:1"], timeout=READY_S)
    chain.wait_flows(timeout=READY_S)
    for name, role in (("storage", "storage"), ("engine", "engine"), ("manager", "manager"), ("debug", "debug"),
                       ("worker:1", "worker"), ("supervisor", "supervisor")):
        snap = request_ok(chain.obs, name, "cmd.diag.snapshot", {}, timeout=5.0)["snapshot"]
        snapshotschema.check_snapshot(snap, role)
        assert snap["name"] == name
        if name != "supervisor":
            assert snap["peer"]["status"] == "ready", (name, snap["peer"])
            cmdline = psutil.Process(snap["pid"]).cmdline()
            script = [part for part in cmdline if part.lower().endswith(".ahk")]
            assert [Path(s).resolve() for s in script] == [(ENTRY_DIR / (role + ".ahk")).resolve()], (name, cmdline)
        else:
            assert [Path(s).resolve() for s in psutil.Process(snap["pid"]).cmdline() if s.lower().endswith(".ahk")] \
                == [PRODUCT_ENTRY.resolve()]


def run_role_entry(procs, datadir, entry, *args):
    out = Path(datadir) / "entry.out"
    with open(out, "wb") as o:
        proc = procs.start([sys.executable, str(AHKRUN), "--timeout", "30", str(entry), *args], stdout=o,
                           stderr=subprocess.STDOUT, cwd=str(ROOT))
        code = proc.wait(timeout=60)
    return code, out.read_bytes().decode("utf-8", "replace")


@pytest.mark.parametrize("role", ["editor"])
def test_the_placeholder_entries_start_and_say_that_they_are_not_implemented(procs, datadir, session_id, role):
    code, text = run_role_entry(procs, datadir, ENTRY_DIR / (role + ".ahk"), "--role=" + role,
                                "--session=" + session_id, "--hub=ahf." + session_id + ".hub", "--data=" + str(datadir))
    assert code == EXIT_NOT_IMPLEMENTED, (code, text)
    assert "role '%s' is not implemented yet" % role in text


@pytest.mark.parametrize("entry_role, other", [("worker", "engine"), ("engine", "worker"), ("storage", "manager"),
                                               ("manager", "storage"), ("debug", "triggerhost")])
def test_an_entry_knows_only_its_own_role(procs, datadir, session_id, entry_role, other):
    code, text = run_role_entry(procs, datadir, ENTRY_DIR / (entry_role + ".ahk"), "--role=" + other,
                                "--session=" + session_id, "--hub=ahf." + session_id + ".hub", "--data=" + str(datadir))
    assert code == EXIT_BAD_ARGS, (code, text)
    assert "unknown role '%s'" % other in text


def test_the_supervisor_entry_is_not_a_role_entry(procs, datadir, session_id):
    code, text = run_role_entry(procs, datadir, PRODUCT_ENTRY, "--role=engine", "--session=" + session_id,
                                "--hub=ahf." + session_id + ".hub", "--data=" + str(datadir))
    assert code == EXIT_BAD_ARGS, (code, text)
    assert "unknown role 'engine'" in text


def test_the_role_entry_does_not_run_a_supervisor(procs, datadir, session_id):
    code, text = run_role_entry(procs, datadir, ENTRY_DIR / "engine.ahk", "--role=supervisor",
                                "--session=" + session_id, "--data=" + str(datadir))
    assert code == EXIT_BAD_ARGS, (code, text)
    assert "unknown role 'supervisor'" in text
