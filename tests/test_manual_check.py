"""Tests of tools/manual_check.py that start no AutoHotkey (the start itself is the owner's manual check, F-0065)."""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import manual_check as mc  # noqa: E402


def test_prepare_makes_a_data_folder_with_the_skeleton_flow(tmp_path):
    folder = tmp_path / "manual"
    mc.prepare(str(folder))
    flow = folder / "Flows" / "skeleton.json"
    assert flow.read_bytes() == open(mc.SKELETON, "rb").read()
    json.loads(flow.read_text(encoding="utf-8"))
    assert (folder / mc.MARKER).is_file()


def test_prepare_again_empties_its_own_folder(tmp_path):
    folder = tmp_path / "manual"
    mc.prepare(str(folder))
    (folder / "Log").mkdir()
    (folder / "Log" / "Log.txt").write_text("old run")
    mc.prepare(str(folder))
    assert not (folder / "Log").exists()
    assert (folder / "Flows" / "skeleton.json").is_file()


def test_prepare_refuses_a_folder_it_did_not_make(tmp_path):
    folder = tmp_path / "someone"
    folder.mkdir()
    (folder / "important.txt").write_text("keep me")
    assert mc.main(["prepare", "--dir", str(folder)]) == 1
    assert (folder / "important.txt").read_text() == "keep me"


def test_prepare_takes_an_empty_folder(tmp_path):
    assert mc.main(["prepare", "--dir", str(tmp_path)]) == 0
    assert (tmp_path / "Flows" / "skeleton.json").is_file()


def test_start_uses_the_manual_session_and_the_data_folder():
    cmd = mc.command_line("ahk.exe", r"C:\data", ["--ui=stub", "--start=storage,engine,manager,debug"])
    assert cmd[0] == "ahk.exe"
    assert cmd[1] == "/ErrorStdOut=UTF-8"
    assert cmd[2].endswith(os.path.join("src", "AutoHotFlow.ahk"))
    assert cmd[3:] == ["--session=manual", r"--data=C:\data", "--ui=stub", "--start=storage,engine,manager,debug"]


DPI_FLOW = "dpi_dialogs"


def test_prepare_with_a_flow_copies_the_flow_next_to_the_skeleton(tmp_path):
    folder = tmp_path / "manual"
    mc.prepare(str(folder), DPI_FLOW)
    copied = folder / "Flows" / (DPI_FLOW + ".json")
    assert copied.read_bytes() == open(mc.flow_source(DPI_FLOW), "rb").read()
    assert (folder / "Flows" / "skeleton.json").is_file()


def test_an_unknown_or_bad_flow_name_is_refused_before_the_folder_is_touched(tmp_path, monkeypatch):
    folder = tmp_path / "manual"
    started = []
    monkeypatch.setattr(mc.subprocess, "run", lambda *a, **k: started.append(a))
    assert mc.main(["start", "--flow", "no_such_flow", "--dir", str(folder)]) == 1
    assert mc.main(["start", "--flow", "../skeleton", "--dir", str(folder)]) == 1
    assert not folder.exists() and started == []


def test_start_with_a_flow_copies_it_and_builds_the_start_command(tmp_path, monkeypatch):
    folder = tmp_path / "manual"
    calls = []

    class Done:
        returncode = 0

    def fake_run(cmd, cwd=None):
        # the flow is in place before the application starts
        assert (folder / "Flows" / (DPI_FLOW + ".json")).is_file()
        calls.append((cmd, cwd))
        return Done()

    monkeypatch.setattr(mc, "find_ahk_exe", lambda: ("ahk.exe", None))
    monkeypatch.setattr(mc.subprocess, "run", fake_run)
    code = mc.main(["start", "--flow", DPI_FLOW, "--dir", str(folder), "--",
                    "--ui=stub", "--start=storage,engine,manager"])
    assert code == 0
    (cmd, cwd), = calls
    assert cmd[0] == "ahk.exe" and cmd[1] == "/ErrorStdOut=UTF-8"
    assert cmd[2].endswith(os.path.join("src", "AutoHotFlow.ahk"))
    assert cmd[3:] == ["--session=manual", "--data=" + str(folder), "--ui=stub", "--start=storage,engine,manager"]
    assert cwd == mc.ROOT
