"""tools/ahkrun.py --interpreter: another interpreter (the v1 one) with the same dialog guard (WI-36)."""

import os
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

import ahkrun  # noqa: E402

V1_EXE = str(REPO / "v1" / "AutoHotKey" / "AutoHotFlow.exe")


def test_ahkrun_reports_a_missing_interpreter(tmp_path):
    script = tmp_path / "x.ahk"
    script.write_text("ExitApp\n")
    code, out, err, dialogs = ahkrun.run(str(script), interpreter=str(tmp_path / "nothing.exe"), timeout=5)
    assert code == 99 and "interpreter not found" in err and not dialogs


@pytest.mark.skipif(not os.path.isfile(V1_EXE), reason="v1/ is gone")
def test_ahkrun_runs_the_v1_interpreter_without_a_dialog_and_with_stderr_for_load_errors(tmp_path):
    good = tmp_path / "good.ahk"
    good.write_text('#NoEnv\nFileAppend, % "v" A_AhkVersion, *\nExitApp\n')
    code, out, err, dialogs = ahkrun.run(str(good), interpreter=V1_EXE, timeout=20)
    assert (code, out, dialogs) == (0, "v1.1.32.00", [])
    bad = tmp_path / "bad.ahk"
    bad.write_text("x := (1 +\nExitApp\n")
    code, out, err, dialogs = ahkrun.run(str(bad), interpreter=V1_EXE, timeout=20)
    assert code == 2 and "Missing" in err and not dialogs     # a load error goes to stderr, no dialog
