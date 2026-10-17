"""WI-0043: acceptance of step S0001 end to end (v1 flow, every kind of variable, restarts, the v1 data folder stays untouched).

Under the real supervisor (storage, engine, UI stub), like tests/fault/test_var_persistence.py. The data of a v1 working
directory is copied to a temporary folder (a flow of tests/data/flows/s1_acceptance in the v1 format, the variable files
of tests/data/variables); v2 gets a data folder of its own, the files are copied over as the import of S0004 will do it.
Checked:
  * the v1 flow is converted when the engine loads it (the texts of the expression parameters);
  * a variable of each kind (instance, thread, global, static) is set by the test element, read back in the same
    instance, and the built-in and the preloaded variables of the v1 files are found;
  * global and static variables are present after a restart of the engine (killed) and after a restart of the session;
    instance and thread variables are not;
  * v2 wrote nothing into the folder of the v1 data (file list and hashes before and after).
"""

import hashlib
import json
import shutil
from pathlib import Path

import psutil
import pytest

from faultkit import FULL_CHAIN, HEADLESS_OPTS, request_ok
from faultfixtures import chains  # noqa: F401  (fixture)
from test_var_persistence import (new_session, read_pair, run_flow, steps, wait_pair, wait_ready_count)

pytestmark = pytest.mark.slow

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "tests" / "data"
FLOW_ID = "Flow 1000000001"
FLOW_FILE = DATA / "flows" / "s1_acceptance" / (FLOW_ID + ".json")
NAMES = ["inst_value", "A_thread_value", "global_acc", "static_acc", "global_synthetic_text", "static_synthetic_map",
         "A_AhfVersion"]


def tree(folder):
    """{relative path: sha256 of the content, or None for a folder} of everything below the folder."""
    out = {}
    for path in sorted(Path(folder).rglob("*")):
        rel = path.relative_to(folder).as_posix()
        out[rel] = None if path.is_dir() else hashlib.sha256(path.read_bytes()).hexdigest()
    return out


def read_probe(datadir, name):
    """(text, type, location) that the probe step of the test element left for a variable name."""
    got = []
    for prefix in ("global_probe_", "global_probetype_", "global_probeloc_"):
        pair = wait_pair(datadir, prefix + name, lambda p: True)
        assert pair is not None, "probe %s%s not written" % (prefix, name)
        got.append(pair[1])
    return tuple(got)


def clear_probes(datadir):
    folder = Path(datadir) / "Variables"
    for path in folder.glob("global_probe*"):
        path.unlink()


def write_prober(datadir):
    """The flow of the v1 folder with the steps of both test elements replaced: only probe, set nothing."""
    flow = json.loads(FLOW_FILE.read_text(encoding="utf-8"))
    flow["allElements"]["element0000000002"]["pars"]["Steps"] = steps(*[{"op": "probe", "name": n} for n in NAMES])
    flow["allElements"]["element0000000003"]["pars"]["Steps"] = "[]"
    (Path(datadir) / "Flows" / (FLOW_ID + ".json")).write_text(json.dumps(flow, indent=2), encoding="utf-8")


def assert_loaded_values(datadir):
    """What a probe sees after a restart: the permanent variables with their values, nothing of the instance."""
    got = {n: read_probe(datadir, n) for n in NAMES}
    assert got["global_acc"] == ("global text", "String", "global")
    assert json.loads(got["static_acc"][0]) == {"k": [1, 2]} and got["static_acc"][1:] == ("Map", "static")
    assert got["global_synthetic_text"] == ("0.500000", "String", "global")             # a text of the v1 file stays
    assert json.loads(got["static_synthetic_map"][0]) == {"text": "1", "number": 2, "nested": {"key": "value"}}
    assert got["static_synthetic_map"][1:] == ("Map", "static")
    assert got["inst_value"] == ("<missing>", "<missing>", "<missing>")                   # an instance is gone
    assert got["A_thread_value"] == ("<missing>", "<missing>", "<missing>")
    assert got["A_AhfVersion"][1:] == ("String", "builtin")


def test_a_v1_flow_with_every_kind_of_variable_survives_the_restarts_and_leaves_the_v1_folder_alone(
        chains, datadir, tmp_path):
    # the v1 folder: a copy of the flow and of the variable files, as they lie in a v1 working directory
    v1dir = tmp_path / "v1_working_directory"
    (v1dir / "Flows").mkdir(parents=True)
    shutil.copy(FLOW_FILE, v1dir / "Flows" / FLOW_FILE.name)
    shutil.copytree(DATA / "variables", v1dir / "Variables")
    before = tree(v1dir)
    assert len(before) >= 8

    # the data folder of v2 gets copies (S0004 will import; for now by hand)
    shutil.copytree(v1dir / "Flows", datadir / "Flows")
    shutil.copytree(v1dir / "Variables", datadir / "Variables")

    first = chains(FULL_CHAIN, HEADLESS_OPTS)
    wait_ready_count(first, 1)

    # the texts of the v1 flow are converted when the engine loads it
    definition = request_ok(first.obs, "engine", "cmd.flow.get", {"flowId": FLOW_ID})["definition"]
    pars = definition["allElements"]["element0000000004"]["pars"]
    assert pars["Expr"] == 'x := "1.50"'
    assert pars["Condition"] == 'x = 1.50 and "a" . "b"'

    # run: set a variable of each kind, read them back in the same instance, evaluate the converted expression
    run_flow(first, FLOW_ID)
    got = {n: read_probe(datadir, n) for n in NAMES}
    assert got["inst_value"] == ("7", "Integer", "instance")
    assert got["A_thread_value"] == ("thread text", "String", "thread")
    assert got["global_acc"] == ("global text", "String", "global")
    assert json.loads(got["static_acc"][0]) == {"k": [1, 2]} and got["static_acc"][1:] == ("Map", "static")
    assert got["global_synthetic_text"] == ("0.500000", "String", "global")
    assert got["static_synthetic_map"][1:] == ("Map", "static")
    assert got["A_AhfVersion"][1:] == ("String", "builtin")
    report = json.loads(wait_pair(datadir, "global_evalresult_s1", lambda p: True)[1])
    assert report["Expr"] == {"type": "String", "value": "1.50"}          # unconverted, v2 would give the number 1.5

    # the permanent variables are on disk (v1 pair format) before the engine is killed
    assert wait_pair(datadir, "global_acc", lambda p: p[1] == "global text") == ("normal", "global text")
    assert wait_pair(datadir, "static_acc", lambda p: True, scope_dir=FLOW_ID)[0] == "object"

    # restart of the engine
    write_prober(datadir)                 # the new engine loads the flow from disk
    clear_probes(datadir)
    pid = first.pid("engine")
    psutil.Process(pid).kill()
    first.wait_restarted_ready("engine", pid, timeout=15.0)
    wait_ready_count(first, 2)
    run_flow(first, FLOW_ID)
    assert_loaded_values(datadir)

    # restart of the session
    assert first.request_exit()["payload"]["started"] is True
    assert first.sup.wait_exit(30) == 0, first.sup.text()
    clear_probes(datadir)
    second = chains(FULL_CHAIN, HEADLESS_OPTS, session=new_session())
    wait_ready_count(second, 1)
    run_flow(second, FLOW_ID)
    assert_loaded_values(datadir)
    assert second.request_exit()["payload"]["started"] is True
    assert second.sup.wait_exit(30) == 0, second.sup.text()

    # v2 wrote into its own folder, and not a byte into the v1 folder
    assert read_pair(datadir, "global_acc") == ("normal", "global text")
    assert tree(v1dir) == before
