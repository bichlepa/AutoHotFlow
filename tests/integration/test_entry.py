"""WI-0022 points 3 and 4: what the entry point does before AhfMain runs.

3. An error while the files are loaded (file-level code of an element file, e.g. ElementRegistry.Register) must
   not show a dialog: tools/ahkrun.py would report exit 97 then. The message goes to stderr, exit code 1.
4. Only the 64-bit interpreter is supported (decision E0004): AutoHotkey32.exe gets exit 2 and a message.
"""

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / "src" / "AutoHotFlow.ahk"
TEST_ENTRY = ROOT / "tests" / "integration" / "helpers" / "AutoHotFlowTest.ahk"   # WI-0029: product entry plus test roles
AHKRUN = ROOT / "tools" / "ahkrun.py"
AHK32 = Path(r"C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe")

EXIT_START_FAILED = 1
EXIT_BAD_ARGS = 2
EXIT_DIALOG_CAUGHT = 97     # tools/ahkrun.py: a dialog appeared and was closed


def run_entry(procs, datadir, args, timeout=30, entry=ENTRY):
    out = Path(datadir) / "entry.out"
    err = Path(datadir) / "entry.err"
    with open(out, "wb") as o, open(err, "wb") as e:
        proc = procs.start([sys.executable, str(AHKRUN), "--timeout", str(timeout), str(entry), *args],
                           stdout=o, stderr=e, cwd=str(ROOT))
        code = proc.wait(timeout=timeout + 15)
    return code, out.read_bytes().decode("utf-8", "replace"), err.read_bytes().decode("utf-8", "replace")


def test_error_while_loading_files_shows_no_dialog_and_ends_with_exit_1(procs, datadir, session_id):
    code, out, err = run_entry(procs, datadir, ["--session=" + session_id, "--data=" + str(datadir),
                                                "--test-roles", "--test-register-failure"], entry=TEST_ENTRY)
    assert code != EXIT_DIALOG_CAUGHT, "a dialog appeared:\n" + out + err
    assert code == EXIT_START_FAILED, (code, out, err)
    assert "Test_RegisterFailure" in err or "Mode" in err, err


def test_a_start_without_the_test_option_is_not_affected_by_the_helper(procs, datadir, session_id):
    # the helper file is part of the test entry, but it acts only with both test options; --role=echo needs a hub
    code, out, err = run_entry(procs, datadir, ["--session=" + session_id, "--data=" + str(datadir),
                                                "--role=nonexistent"])
    assert code == EXIT_BAD_ARGS, (code, out, err)
    assert "unknown role" in err, err


def test_the_boot_file_hides_the_tray_icon(procs, datadir):
    # E0046. Proves: a script that includes AhfBoot.ahk has A_IconHidden set. It cannot show the real icon.
    code, out, err = run_entry(procs, datadir, [], entry=ROOT / "tests" / "integration" / "helpers" / "IconProbe.ahk")
    assert code == 0, (code, out, err)
    assert "A_IconHidden=1" in out, (out, err)


def test_every_entry_script_includes_the_boot_file():
    # E0046. Proves: no process entry of the product or of the tests starts without the boot file (and so without
    # #NoTrayIcon). A new entry that forgets the include fails here.
    helpers = ROOT / "tests" / "integration" / "helpers"
    entries = [ENTRY, helpers / "AutoHotFlowTest.ahk", *(ROOT / "src" / "entry").glob("*.ahk"),
               *(helpers / "entry").rglob("*.ahk")]
    entries = [p for p in entries if "generated" not in p.parts]
    assert len(entries) >= 15
    for p in entries:
        assert "AhfBoot.ahk" in p.read_text(encoding="utf-8"), p
    boot = (ROOT / "src" / "AhfBoot.ahk").read_text(encoding="utf-8")
    assert any(line.strip().lower() == "#notrayicon" for line in boot.splitlines())


@pytest.mark.skipif(not AHK32.exists(), reason="AutoHotkey32.exe is not installed")
def test_the_32_bit_interpreter_is_rejected_with_exit_2_and_no_dialog(procs, datadir, session_id, monkeypatch):
    monkeypatch.setenv("AHF_AHK2_EXE", str(AHK32))      # tools/ahkrun.py picks the interpreter from it
    code, out, err = run_entry(procs, datadir, ["--session=" + session_id, "--data=" + str(datadir)])
    assert code != EXIT_DIALOG_CAUGHT, "a dialog appeared:\n" + out + err
    assert code == EXIT_BAD_ARGS, (code, out, err)
    assert "64-bit" in err, err
