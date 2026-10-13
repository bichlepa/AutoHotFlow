"""conftest._collect_diagnosis runs inside pytest_runtest_makereport. An exception there is an INTERNALERROR that
ends the whole (xdist) run, so it must never raise, also when there is no supervisor and no target folder yet."""

from conftest import _collect_diagnosis


def test_no_supervisor_and_no_target_folder_writes_a_note_and_does_not_raise(tmp_path):
    target = tmp_path / "data" / "some_test" / "diagnosis"          # does not exist, as in the hook
    _collect_diagnosis("tnosuchsession0000", target)
    note = target / "diagnosis-none.txt"
    assert note.is_file()
    assert "no diagnosis" in note.read_text(encoding="utf-8")


def test_an_unwritable_target_does_not_raise(tmp_path):
    blocker = tmp_path / "data"
    blocker.write_text("a file where a folder should be", encoding="utf-8")
    _collect_diagnosis("tnosuchsession0001", blocker / "diagnosis")       # mkdir fails: must be swallowed
