"""WI-22 points 3 and 4: what the entry point does before AhfMain runs.

3. An error while the files are loaded (file-level code of an element file, e.g. ElementRegistry.Register) must
   not show a dialog: tools/ahkrun.py would report exit 97 then. The message goes to stderr, exit code 1.
4. Only the 64-bit interpreter is supported (decision E4): AutoHotkey32.exe gets exit 2 and a message.
"""

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / "src" / "AutoHotFlow.ahk"
AHKRUN = ROOT / "tools" / "ahkrun.py"
AHK32 = Path(r"C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe")

EXIT_START_FAILED = 1
EXIT_BAD_ARGS = 2
EXIT_DIALOG_CAUGHT = 97     # tools/ahkrun.py: a dialog appeared and was closed


def run_entry(procs, datadir, args, timeout=30):
    out = Path(datadir) / "entry.out"
    err = Path(datadir) / "entry.err"
    with open(out, "wb") as o, open(err, "wb") as e:
        proc = procs.start([sys.executable, str(AHKRUN), "--timeout", str(timeout), str(ENTRY), *args],
                           stdout=o, stderr=e, cwd=str(ROOT))
        code = proc.wait(timeout=timeout + 15)
    return code, out.read_bytes().decode("utf-8", "replace"), err.read_bytes().decode("utf-8", "replace")


def test_error_while_loading_files_shows_no_dialog_and_ends_with_exit_1(procs, datadir, session_id):
    code, out, err = run_entry(procs, datadir, ["--session=" + session_id, "--data=" + str(datadir),
                                                "--test-roles", "--test-register-failure"])
    assert code != EXIT_DIALOG_CAUGHT, "a dialog appeared:\n" + out + err
    assert code == EXIT_START_FAILED, (code, out, err)
    assert "Test_RegisterFailure" in err or "Mode" in err, err


def test_a_start_without_the_test_option_is_not_affected_by_the_helper(procs, datadir, session_id):
    # the helper file is part of the entry, but it acts only with both test options; --role=echo needs a hub
    code, out, err = run_entry(procs, datadir, ["--session=" + session_id, "--data=" + str(datadir),
                                                "--role=nonexistent"])
    assert code == EXIT_BAD_ARGS, (code, out, err)
    assert "unknown role" in err, err


@pytest.mark.skipif(not AHK32.exists(), reason="AutoHotkey32.exe is not installed")
def test_the_32_bit_interpreter_is_rejected_with_exit_2_and_no_dialog(procs, datadir, session_id, monkeypatch):
    monkeypatch.setenv("AHF_AHK2_EXE", str(AHK32))      # tools/ahkrun.py picks the interpreter from it
    code, out, err = run_entry(procs, datadir, ["--session=" + session_id, "--data=" + str(datadir)])
    assert code != EXIT_DIALOG_CAUGHT, "a dialog appeared:\n" + out + err
    assert code == EXIT_BAD_ARGS, (code, out, err)
    assert "64-bit" in err, err
