"""WI-0079: Start with Windows (the shortcut, the start context) and Run as administrator (the restart), and E0083 (a start
without parameters).

REQ-SET-030, REQ-SET-040, REQ-TRG-220 (start context).

SAFETY: no test touches the real startup folder (the shortcut is handled only in a folder the test names with
--startup-dir, or in none) and no test elevates for real: the hook --fake-elevation=accept|decline replaces the UAC
question (the real one is a manual check, doc/MANUAL-CHECKS.md section 7).
"""

import json
import subprocess
import sys
import time
from pathlib import Path

import pytest

from support import pipenames
from support.ahfclient import AhfClient
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
TEST_ENTRY = ROOT / "tests" / "integration" / "helpers" / "AutoHotFlowTest.ahk"
PRODUCT_ENTRY = ROOT / "src" / "AutoHotFlow.ahk"
AHKRUN = ROOT / "tools" / "ahkrun.py"
WAIT_S = scaled(15.0)
SHORTCUT = "AutoHotFlow v2.lnk"


def start(procs, tmp, entry, args, label="sup"):
    err = open(tmp / (label + ".stderr"), "wb")
    proc = procs.start([sys.executable, str(AHKRUN), "--timeout", "120", str(entry), *args], stdout=err, stderr=err,
                       cwd=str(ROOT))
    return proc, tmp / (label + ".stderr")


def connect(session, timeout=WAIT_S):
    deadline = time.monotonic() + timeout
    while True:
        try:
            return AhfClient(pipenames.hub_pipe(session), "test", connect_timeout=2.0)
        except Exception:
            if time.monotonic() > deadline:
                raise
            time.sleep(0.05)


def wait_for(predicate, timeout=WAIT_S):
    deadline = time.monotonic() + timeout
    while True:
        value = predicate()
        if value:
            return value
        if time.monotonic() > deadline:
            return None
        time.sleep(0.1)


def roles_up(client, names):
    """True when every role in names is `ready` in the process list of the supervisor."""
    try:
        procs = client.request("supervisor", "cmd.process.list", {}, timeout=3)["payload"]["processes"]
    except Exception:
        return False
    ready = {p["name"] for p in procs if p["state"] == "ready"}
    return set(names) <= ready


def process_names(client):
    procs = client.request("supervisor", "cmd.process.list", {}, timeout=5)["payload"]["processes"]
    return {p["name"] for p in procs}


def check_shortcut(client, folder):
    answer = client.request("storage", "cmd.storage.startup.check", {"startupDir": str(folder)}, timeout=5)["payload"]
    return answer if answer["ok"] else {"exists": False, "args": ""}   # storage is not connected yet


def settings_file(datadir, **values):
    (datadir / "Settings.json").write_text(json.dumps(values), encoding="utf-8")


def snapshot(client):
    return client.request("supervisor", "cmd.diag.snapshot", {}, timeout=5)["payload"]["snapshot"]


@pytest.fixture
def relaunched(session_id):
    """A test whose session starts itself again (the new supervisor is not a child of the test): at the end, whatever is
    still listening on the session is asked to exit, also when the test failed halfway."""
    yield
    for _ in range(3):
        try:
            c = AhfClient(pipenames.hub_pipe(session_id), "cleanup", connect_timeout=1.0)
        except Exception:
            return
        try:
            c.request("supervisor", "cmd.app.exit", {}, timeout=5)
        except Exception:
            pass
        c.close()
        time.sleep(0.5)


@pytest.fixture
def startup(tmp_path):
    folder = tmp_path / "Startup"
    folder.mkdir()
    return folder


# --- Start with Windows -------------------------------------------------------------------------------------------

def test_the_shortcut_is_created_removed_and_not_taken_for_the_one_of_v1(procs, datadir, session_id, startup):
    settings_file(datadir, startWithWindows=True)
    sup, _ = start(procs, datadir, TEST_ENTRY, ["--session=" + session_id, "--data=" + str(datadir),
                                                "--startup-dir=" + str(startup), "--start=storage,engine"])
    client = connect(session_id)
    made = wait_for(lambda: check_shortcut(client, startup)["exists"] and check_shortcut(client, startup))
    assert made, "the shortcut was not created"
    assert (startup / SHORTCUT).exists() and not (startup / "AutoHotFlow.lnk").exists()
    assert made["target"].lower().endswith("autohotkey64.exe"), made
    assert "--windows-startup" in made["args"] and "--start=storage,engine,triggerhost" in made["args"], made
    assert "--data=" + str(datadir) in made["args"], made
    assert Path(made["workDir"]).resolve() == TEST_ENTRY.parent.resolve(), made   # the folder of the script (src for the product)
    # the import of v1 does not see it as the shortcut of v1
    v1 = client.request("storage", "cmd.storage.autostart.check", {"startupDir": str(startup)}, timeout=5)["payload"]
    assert v1["ok"] and not v1["exists"] and not v1["v1"], v1
    # switched off: removed
    done = client.request("engine", "cmd.settings.set", {"settings": {"startWithWindows": False}}, timeout=10)["payload"]
    assert done["ok"], done
    assert wait_for(lambda: not (startup / SHORTCUT).exists()), "the shortcut was not removed"
    client.close()


def test_a_shortcut_that_does_not_match_is_repaired_at_the_start(procs, datadir, session_id, startup):
    settings_file(datadir, startWithWindows=True)
    # a shortcut of an older place of the program: another target and other arguments
    script = ("$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%s'); $s.TargetPath='C:\\Windows\\notepad.exe'; "
              "$s.Arguments='--old'; $s.Save()" % (startup / SHORTCUT))
    subprocess.run(["powershell", "-NoProfile", "-Command", script], check=True, timeout=60)
    sup, _ = start(procs, datadir, TEST_ENTRY, ["--session=" + session_id, "--data=" + str(datadir),
                                                "--startup-dir=" + str(startup), "--start=storage,engine"])
    client = connect(session_id)
    fixed = wait_for(lambda: "--windows-startup" in check_shortcut(client, startup)["args"]
                     and check_shortcut(client, startup))
    assert fixed, "the shortcut was not repaired"
    assert fixed["target"].lower().endswith("autohotkey64.exe"), fixed
    assert wait_for(lambda: snapshot(client)["startup"]["action"] == "repaired")
    client.close()


def test_switched_off_with_a_missing_startup_folder_is_not_a_failure(procs, datadir, session_id, tmp_path):
    sup, _ = start(procs, datadir, TEST_ENTRY, ["--session=" + session_id, "--data=" + str(datadir),
                                                "--startup-dir=" + str(tmp_path / "NoSuchFolder"), "--start=storage,engine"])
    client = connect(session_id)
    assert wait_for(lambda: snapshot(client)["startup"]["action"] != "")
    assert snapshot(client)["startup"]["action"] == "none"
    client.close()


def test_without_a_startup_folder_a_test_session_never_handles_the_shortcut(procs, datadir, session_id):
    settings_file(datadir, startWithWindows=True)
    sup, _ = start(procs, datadir, TEST_ENTRY, ["--session=" + session_id, "--data=" + str(datadir),
                                                "--start=storage,engine"])
    client = connect(session_id)
    assert wait_for(lambda: roles_up(client, ["storage", "engine"]))
    time.sleep(1.0)
    assert snapshot(client)["startup"] == {"dir": "", "wanted": False, "action": ""}
    client.close()


def test_a_start_with_windows_starts_no_manager_and_a_normal_start_does(procs, datadir, session_id, tmp_path):
    other = tmp_path / "other"
    other.mkdir()
    sup, _ = start(procs, datadir, TEST_ENTRY, ["--session=" + session_id, "--data=" + str(datadir),
                                                "--start=storage,engine,manager", "--headless", "--windows-startup"])
    client = connect(session_id)
    assert wait_for(lambda: roles_up(client, ["storage", "engine"]))
    assert "manager" not in process_names(client)
    client.close()
    session2 = session_id + "n"
    sup2, _ = start(procs, other, TEST_ENTRY, ["--session=" + session2, "--data=" + str(other),
                                               "--start=storage,engine,manager", "--headless"], label="sup2")
    client2 = connect(session2)
    assert wait_for(lambda: roles_up(client2, ["storage", "engine", "manager"]))
    client2.close()


# --- a start without parameters (E0083) ---------------------------------------------------------------------------

def test_the_product_starts_its_default_roles_without_parameters(procs, datadir, session_id, monkeypatch):
    """No --start, no --data: the data folder comes from the environment (the guard of the tests), --session only keeps
    the pipe away from a real instance, --headless keeps every window and icon away."""
    monkeypatch.setenv("AHF_DATA_DIR", str(datadir))
    sup, _ = start(procs, datadir, PRODUCT_ENTRY, ["--session=" + session_id, "--headless"])
    client = connect(session_id)
    names = ["storage", "engine", "triggerhost", "manager", "tray"]
    assert wait_for(lambda: roles_up(client, names)), process_names(client)
    assert "debug" not in process_names(client)
    client.close()


def test_the_product_started_with_windows_starts_only_the_tray(procs, datadir, session_id, monkeypatch):
    monkeypatch.setenv("AHF_DATA_DIR", str(datadir))
    sup, _ = start(procs, datadir, PRODUCT_ENTRY, ["--session=" + session_id, "--headless", "--windows-startup"])
    client = connect(session_id)
    assert wait_for(lambda: roles_up(client, ["storage", "engine", "triggerhost", "tray"])), process_names(client)
    assert "manager" not in process_names(client)
    client.close()


def test_the_product_entry_ignores_the_test_hooks_of_the_elevation(procs, datadir, session_id, monkeypatch):
    """--fake-admin and --fake-elevation exist only in the test entry. The setting stays off here, so nothing can elevate."""
    if ctypes_is_admin():
        pytest.skip("the test process is elevated")
    monkeypatch.setenv("AHF_DATA_DIR", str(datadir))
    sup, _ = start(procs, datadir, PRODUCT_ENTRY, ["--session=" + session_id, "--headless", "--start=storage,engine",
                                                   "--test-roles", "--fake-admin", "--fake-elevation=bogus"])
    client = connect(session_id)
    assert wait_for(lambda: roles_up(client, ["storage", "engine"]))
    assert snapshot(client)["elevation"]["admin"] is False
    client.close()


def ctypes_is_admin():
    import ctypes
    return bool(ctypes.windll.shell32.IsUserAnAdmin())


# --- Run as administrator ------------------------------------------------------------------------------------------

def test_with_the_setting_on_the_supervisor_restarts_elevated_before_it_starts_any_child(procs, datadir, session_id, relaunched):
    settings_file(datadir, runAsAdmin=True)
    sup, err = start(procs, datadir, TEST_ENTRY, ["--session=" + session_id, "--data=" + str(datadir), "--test-roles",
                                                  "--fake-elevation=accept", "--start=storage,engine"])
    assert sup.wait(timeout=WAIT_S) == 0
    text = err.read_bytes().decode("utf-8", "replace")
    assert "restarted with administrator rights" in text and "started storage" not in text, text
    client = connect(session_id)
    try:
        assert wait_for(lambda: roles_up(client, ["storage", "engine"]))
        assert snapshot(client)["elevation"]["admin"] is True
    finally:
        client.request("supervisor", "cmd.app.exit", {}, timeout=5)
        client.close()


def test_a_declined_elevation_leaves_the_session_running_without_rights(procs, datadir, session_id):
    settings_file(datadir, runAsAdmin=True)
    sup, err = start(procs, datadir, TEST_ENTRY, ["--session=" + session_id, "--data=" + str(datadir), "--test-roles",
                                                  "--fake-elevation=decline", "--start=storage,engine"])
    client = connect(session_id)
    assert wait_for(lambda: roles_up(client, ["storage", "engine"]))
    snap = snapshot(client)
    assert snap["elevation"] == {"admin": False, "state": "declined"}, snap["elevation"]
    assert sup.poll() is None
    client.close()


def test_the_command_restart_ends_the_session_and_starts_it_elevated(procs, datadir, session_id, relaunched):
    sup, err = start(procs, datadir, TEST_ENTRY, ["--session=" + session_id, "--data=" + str(datadir), "--test-roles",
                                                  "--fake-elevation=accept", "--start=storage,engine"])
    client = connect(session_id)
    assert wait_for(lambda: roles_up(client, ["storage", "engine"]))
    assert snapshot(client)["elevation"]["admin"] is False
    answer = client.request("supervisor", "cmd.app.restart", {"elevate": True}, timeout=10)["payload"]
    assert answer["ok"] and answer["started"], answer
    assert sup.wait(timeout=WAIT_S) == 0
    client.close()
    client2 = connect(session_id)
    try:
        assert wait_for(lambda: roles_up(client2, ["storage", "engine"]))
        assert snapshot(client2)["elevation"]["admin"] is True
    finally:
        client2.request("supervisor", "cmd.app.exit", {}, timeout=5)
        client2.close()


def test_a_declined_restart_starts_the_application_again_without_rights(procs, datadir, session_id, relaunched):
    sup, err = start(procs, datadir, TEST_ENTRY, ["--session=" + session_id, "--data=" + str(datadir), "--test-roles",
                                                  "--fake-elevation=decline", "--start=storage,engine"])
    client = connect(session_id)
    assert wait_for(lambda: roles_up(client, ["storage", "engine"]))
    client.request("supervisor", "cmd.app.restart", {"elevate": True}, timeout=10)
    assert sup.wait(timeout=WAIT_S) == 0
    client.close()
    client2 = connect(session_id)
    try:
        assert wait_for(lambda: roles_up(client2, ["storage", "engine"]))
        assert snapshot(client2)["elevation"]["admin"] is False
    finally:
        client2.request("supervisor", "cmd.app.exit", {}, timeout=5)
        client2.close()
