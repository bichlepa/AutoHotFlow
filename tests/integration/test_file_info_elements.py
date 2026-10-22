"""WI-0121: end-to-end tests of the file detail elements of the package Default: Get file attributes, Set file attributes,
the condition File has attribute, Get file size, Get file time, Set file time, Create shortcut, Get shortcut information and
Empty recycle bin. Every test works in its own temporary folder (pytest tmp_path); a shortcut is written there, never to the
desktop. The recycle bin goes through the system seam (TestSystemProvider, SystemScript): no bin is emptied. Each flow runs in
a real session (support/flowrun.py); the result is a probe of a variable, the files on disk or the exception of the run.
"""

import os
import re
import stat

from support.coreflows import answer, condition_flow, run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.system import SystemScript, error


def element_flow(name, cls, probe=None, **pars):
    """trigger -> the element -> (a probe of `x`)."""
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    parts = [fb.trigger(), el]
    if probe:
        parts.append(fb.probe(probe))
    fb.chain(*parts)
    return fb


def text_of(run, name="x"):
    """The probed text of a variable; the test fails when the flow did not reach the probe."""
    probe = run.seen.get(name)
    assert probe is not None, run.exceptions
    return probe.text


def message_of(run):
    """The exception message of a run that ended with an exception."""
    assert run.exceptions, run.steps
    return run.exceptions[0]


def set_read_only(path, on):
    """Sets or clears the read-only flag of a file (the test restores it, so tmp_path can be removed)."""
    mode = os.stat(path).st_mode
    os.chmod(path, mode & ~stat.S_IWRITE if on else mode | stat.S_IWRITE)


# --- attributes ------------------------------------------------------------------------------------------------------------
def test_get_file_attributes_stores_the_read_only_letter(flows, tmp_path):
    path = tmp_path / "ro.txt"
    path.write_bytes(b"x")
    set_read_only(path, True)
    try:
        runs = run_all(flows, [element_flow("attr_ro", "Action_Get_File_Attributes", probe="x", varname="x",
                                            file=str(path))])
        assert "R" in text_of(runs[0])
    finally:
        set_read_only(path, False)


def test_get_file_attributes_of_a_missing_file_is_an_exception(flows, tmp_path):
    runs = run_all(flows, [element_flow("attr_missing", "Action_Get_File_Attributes", probe="x", varname="x",
                                        file=str(tmp_path / "none.txt"))])
    assert "does not exist" in message_of(runs[0])


def test_set_file_attributes_sets_the_read_only_flag(flows, tmp_path):
    path = tmp_path / "attr.txt"
    path.write_bytes(b"x")
    try:
        runs = run_all(flows, [element_flow("attr_set", "Action_Set_file_attributes", file=str(path), ReadOnly=1)])
        assert not any(r.exceptions for r in runs), [r.exceptions for r in runs]
        assert os.stat(path).st_mode & stat.S_IWRITE == 0
    finally:
        set_read_only(path, False)


def test_set_file_attributes_clears_the_read_only_flag(flows, tmp_path):
    path = tmp_path / "attr_clear.txt"
    path.write_bytes(b"x")
    set_read_only(path, True)
    try:
        runs = run_all(flows, [element_flow("attr_clear", "Action_Set_file_attributes", file=str(path), ReadOnly=0)])
        assert not any(r.exceptions for r in runs), [r.exceptions for r in runs]
        assert os.stat(path).st_mode & stat.S_IWRITE
    finally:
        set_read_only(path, False)


def test_set_file_attributes_with_no_choice_changes_nothing(flows, tmp_path):
    path = tmp_path / "keep.txt"
    path.write_bytes(b"x")
    before = os.stat(path).st_mode
    runs = run_all(flows, [element_flow("attr_none", "Action_Set_file_attributes", file=str(path))])
    assert not any(r.exceptions for r in runs)
    assert os.stat(path).st_mode == before


def test_set_file_attributes_of_a_missing_file_is_an_exception(flows, tmp_path):
    runs = run_all(flows, [element_flow("attr_missing_set", "Action_Set_file_attributes",
                                        file=str(tmp_path / "none.txt"), ReadOnly=1)])
    assert "does not exist" in message_of(runs[0])


def test_condition_file_has_attribute_yes_no_and_missing(flows, tmp_path):
    path = tmp_path / "cond.txt"
    path.write_bytes(b"x")
    set_read_only(path, True)
    try:
        runs = run_all(flows, [
            condition_flow("has_r", "Condition_File_Has_Attribute", file=str(path), Attribute="R"),
            condition_flow("has_h", "Condition_File_Has_Attribute", file=str(path), Attribute="H"),
            condition_flow("has_missing", "Condition_File_Has_Attribute", file=str(tmp_path / "none.txt"),
                           Attribute="R"),
        ])
    finally:
        set_read_only(path, False)
    assert [answer(r) for r in runs] == ["YES", "NO", "EXCEPTION"]


# --- size ------------------------------------------------------------------------------------------------------------------
SIZE = 3 * 1024 * 1024 + 5          # 3145733 bytes: 3072 kilobytes and 3 megabytes, rounded down


def test_get_file_size_in_bytes_kilobytes_and_megabytes(flows, tmp_path):
    path = tmp_path / "big.bin"
    path.write_bytes(b"x" * SIZE)
    runs = run_all(flows, [
        element_flow("size_b", "Action_Get_File_Size", probe="x", varname="x", file=str(path), Unit="Bytes"),
        element_flow("size_k", "Action_Get_File_Size", probe="x", varname="x", file=str(path), Unit="Kilobytes"),
        element_flow("size_m", "Action_Get_File_Size", probe="x", varname="x", file=str(path), Unit="Megabytes"),
    ])
    assert [text_of(r) for r in runs] == [str(SIZE), "3072", "3"]


def test_get_file_size_of_a_folder_and_a_missing_file_are_exceptions(flows, tmp_path):
    folder = tmp_path / "folder"
    folder.mkdir()
    runs = run_all(flows, [
        element_flow("size_folder", "Action_Get_File_Size", probe="x", varname="x", file=str(folder)),
        element_flow("size_missing", "Action_Get_File_Size", probe="x", varname="x", file=str(tmp_path / "none")),
    ])
    assert "is a folder" in message_of(runs[0])
    assert "does not exist" in message_of(runs[1])


# --- time ------------------------------------------------------------------------------------------------------------------
# The times are checked as a round trip through the elements: AutoHotkey converts a local time with the time zone rules of
# the current date, python with those of the date of the time. In a summer time day the two differ by an hour for a winter
# date (not checked on other machines), so no test compares a file time with python's own conversion.
def test_get_file_time_is_the_time_that_set_file_time_wrote(flows, tmp_path):
    path = tmp_path / "time.txt"
    path.write_bytes(b"x")
    runs = run_all(flows, [
        element_flow("time_set_first", "Action_Set_file_time", file=str(path), time="20200102030405",
                     TimeType="Modification"),
        element_flow("time_mod", "Action_Get_File_Time", probe="x", varname="x", file=str(path),
                     TimeType="Modification"),
        element_flow("time_creation", "Action_Get_File_Time", probe="x", varname="x", file=str(path),
                     TimeType="Creation"),
    ])
    assert not runs[0].exceptions, runs[0].exceptions
    assert text_of(runs[1]) == "20200102030405"
    assert re.fullmatch(r"\d{14}", text_of(runs[2]))


def test_set_file_time_changes_the_modification_time(flows, tmp_path):
    path = tmp_path / "set_time.txt"
    path.write_bytes(b"x")
    runs = run_all(flows, [
        element_flow("time_set", "Action_Set_file_time", file=str(path), time="20210304050607",
                     TimeType="Modification"),
        element_flow("time_get", "Action_Get_File_Time", probe="x", varname="x", file=str(path),
                     TimeType="Modification"),
    ])
    assert not runs[0].exceptions, runs[0].exceptions
    assert text_of(runs[1]) == "20210304050607"


def test_set_file_time_of_a_missing_file_is_an_exception(flows, tmp_path):
    runs = run_all(flows, [element_flow("time_missing", "Action_Set_file_time", file=str(tmp_path / "none.txt"),
                                        time="20210304050607")])
    assert "does not exist" in message_of(runs[0])


def test_set_file_time_refuses_a_text_that_is_not_a_time(flows, tmp_path):
    path = tmp_path / "bad_time.txt"
    path.write_bytes(b"x")
    before = os.path.getmtime(path)
    runs = run_all(flows, [element_flow("time_bad", "Action_Set_file_time", file=str(path), time="no time")])
    assert message_of(runs[0]) == "Timestamp 'no time' is not valid."
    assert os.path.getmtime(path) == before


# --- shortcuts -------------------------------------------------------------------------------------------------------------
def test_create_shortcut_and_read_it_back_in_a_folder_of_the_test(flows, tmp_path):
    target = tmp_path / "example.txt"
    target.write_bytes(b"x")
    link = tmp_path / "example.lnk"
    create = element_flow("shortcut_create", "Action_Create_Shortcut", shortcutFile=str(link), file=str(target),
                          runArguments="-x", WorkingDir=str(tmp_path), description="a description",
                          RunMode="Max")
    read = FlowBuilder("shortcut_read")
    get = read.action("Action_Get_shortcut_information", shortcutFile=str(link), OutTarget="tgt", OutArgs="args",
                      OutDir="dir", OutDescription="desc", OutIcon="icon", OutIconNum="inum", OutRunState="rs")
    read.chain(read.trigger(), get, read.probe("tgt", "args", "dir", "desc", "rs"))
    runs = run_all(flows, [create, read])
    assert not runs[0].exceptions, runs[0].exceptions
    assert link.exists()
    got = runs[1]
    assert not got.exceptions, got.exceptions
    assert got.seen["tgt"].text == str(target)
    assert got.seen["args"].text == "-x"
    assert got.seen["dir"].text == str(tmp_path)
    assert got.seen["desc"].text == "a description"
    assert got.seen["rs"].text == "Maximized"


def test_create_shortcut_in_a_missing_folder_is_an_exception(flows, tmp_path):
    target = tmp_path / "t.txt"
    target.write_bytes(b"x")
    missing = tmp_path / "no_such_folder" / "link.lnk"
    runs = run_all(flows, [element_flow("shortcut_missing", "Action_Create_Shortcut", shortcutFile=str(missing),
                                        file=str(target))])
    assert message_of(runs[0]) == "Can't create shortcut '%s'" % missing
    assert not missing.exists()


def test_get_shortcut_information_of_a_file_that_is_not_a_shortcut(flows, tmp_path):
    plain = tmp_path / "plain.lnk"
    plain.write_bytes(b"not a shortcut")
    runs = run_all(flows, [element_flow("shortcut_plain", "Action_Get_shortcut_information", probe="tgt",
                                        shortcutFile=str(plain), OutTarget="tgt")])
    assert "Can't read informations of shortcut" in message_of(runs[0])


# --- recycle bin (through the seam) -------------------------------------------------------------------------------------
def recycle_calls(system):
    return [c for c in system.requests() if c["function"] == "FileRecycleEmpty"]


def test_empty_recycle_bin_of_all_drives_calls_the_seam_without_a_drive(flows):
    system = SystemScript(flows.datadir)
    runs = run_all(flows, [element_flow("recycle_all", "Action_Empty_Recycle_Bin", AllDrives="All")])
    assert not any(r.exceptions for r in runs), [r.exceptions for r in runs]
    calls = recycle_calls(system)
    assert len(calls) == 1 and calls[0]["args"] == []


def test_empty_recycle_bin_of_one_drive_passes_the_drive(flows):
    system = SystemScript(flows.datadir)
    runs = run_all(flows, [element_flow("recycle_drive", "Action_Empty_Recycle_Bin", AllDrives="Specified",
                                        DriveLetter="D:")])
    assert not any(r.exceptions for r in runs), [r.exceptions for r in runs]
    calls = recycle_calls(system)
    assert len(calls) == 1 and calls[0]["args"] == ["D:"]


def test_empty_recycle_bin_of_a_drive_that_is_not_given_is_an_exception(flows):
    SystemScript(flows.datadir)
    runs = run_all(flows, [element_flow("recycle_nodrive", "Action_Empty_Recycle_Bin", AllDrives="Specified",
                                        DriveLetter="")])
    assert message_of(runs[0]) == "String 'DriveLetter' is empty"


def test_empty_recycle_bin_that_fails_is_an_exception(flows):
    system = SystemScript(flows.datadir)
    system.script({"FileRecycleEmpty": [error("the bin is busy")]})
    runs = run_all(flows, [element_flow("recycle_fail", "Action_Empty_Recycle_Bin", AllDrives="All")])
    assert message_of(runs[0]).startswith("Recycle bin could not be emptied.")
