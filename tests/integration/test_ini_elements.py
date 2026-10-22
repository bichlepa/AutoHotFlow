"""WI-0121: end-to-end tests of the ini elements of the package Default: Read from ini, Write to ini and Delete from ini.
Every test works in its own temporary folder (pytest tmp_path). A new ini file is written as UTF-16 with a byte order mark (as
IniWrite and v1 do); an existing file keeps its encoding. Each flow runs in a real session (support/flowrun.py); the result is
a probe of the variable `x` (or `sec`), the file on disk or the exception of the run.
"""

import json

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def element_flow(name, cls, probe=None, **pars):
    """trigger -> the element -> (a probe of the variables named in `probe`)."""
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    parts = [fb.trigger(), el]
    if probe:
        parts.append(fb.probe(*probe.split(",")))
    fb.chain(*parts)
    return fb


def text_of(run, name="x"):
    probe = run.seen.get(name)
    assert probe is not None, run.exceptions
    return probe.text


def message_of(run):
    assert run.exceptions, run.steps
    return run.exceptions[0]


def write_ini(path, text):
    """Writes an ini file the way Windows tools do: UTF-16 with a byte order mark, CR LF line ends."""
    path.write_bytes(("﻿" + text).replace("\n", "\r\n").encode("utf-16-le"))


def write_flow(name, ini, section, key, value):
    return element_flow(name, "Action_Write_to_ini", file=str(ini), Section=section, Key=key, Value=value)


def read_flow(name, ini, probe="x", **pars):
    """Reads into the variable of the probe of the same name."""
    return element_flow(name, "Action_Read_From_Ini", probe=probe, varname=probe, file=str(ini), **pars)


def test_write_creates_a_utf16_file_with_a_byte_order_mark(flows, tmp_path):
    ini = tmp_path / "new.ini"
    runs = run_all(flows, [write_flow("ini_write_new", ini, "mySection", "myKey", "test value ä")])
    assert not runs[0].exceptions, runs[0].exceptions
    data = ini.read_bytes()
    assert data[:2] == b"\xff\xfe"
    text = data[2:].decode("utf-16-le")
    assert "[mySection]" in text and "myKey=test value ä" in text


def test_write_keeps_the_encoding_of_an_existing_file_and_replaces_a_key(flows, tmp_path):
    ini = tmp_path / "existing.ini"
    write_ini(ini, "[mySection]\nmyKey=old\nother=1\n")
    runs = run_all(flows, [
        write_flow("ini_write_again", ini, "mySection", "myKey", "new"),
        read_flow("ini_read_back", ini, Action="Key", Section="mySection", Key="myKey", WhenError="Exception"),
    ])
    assert not runs[0].exceptions, runs[0].exceptions
    assert ini.read_bytes()[:2] == b"\xff\xfe"
    assert text_of(runs[1]) == "new"


def test_read_a_key_of_a_file_that_v1_style_writes(flows, tmp_path):
    ini = tmp_path / "v1.ini"
    write_ini(ini, "[user]\nname=Paul\n")
    runs = run_all(flows, [read_flow("ini_read_v1", ini, Action="Key", Section="user", Key="name",
                                     WhenError="Exception")])
    assert text_of(runs[0]) == "Paul"


def test_a_missing_key_gives_the_default_or_an_exception(flows, tmp_path):
    ini = tmp_path / "keys.ini"
    write_ini(ini, "[mySection]\nmyKey=value\n")
    runs = run_all(flows, [
        read_flow("ini_default", ini, Action="Key", Section="mySection", Key="wrongKey", WhenError="Default",
                  Default="Big error!"),
        read_flow("ini_empty_default", ini, Action="Key", Section="mySection", Key="wrongKey", WhenError="Default",
                  Default=""),
        read_flow("ini_exception", ini, Action="Key", Section="mySection", Key="wrongKey", WhenError="Exception"),
    ])
    assert text_of(runs[0]) == "Big error!"
    assert text_of(runs[1]) == ""          # an empty default is the empty text (AutoHotkey v2 IniRead)
    assert message_of(runs[2]) == "Section 'mySection' and key 'wrongKey' not found."


def test_read_the_entire_section_gives_a_map_of_keys_and_values(flows, tmp_path):
    ini = tmp_path / "section.ini"
    write_ini(ini, "[mySection]\nmyKey=test value\nyourKey=little value\n[other]\nx=1\n")
    runs = run_all(flows, [read_flow("ini_section", ini, probe="sec", Action="EntireSection", Section="mySection")])
    assert not runs[0].exceptions, runs[0].exceptions
    assert json.loads(text_of(runs[0], "sec")) == {"myKey": "test value", "yourKey": "little value"}


def test_read_the_entire_section_of_a_missing_section_is_empty(flows, tmp_path):
    ini = tmp_path / "missing_section.ini"
    write_ini(ini, "[mySection]\nmyKey=1\n")
    runs = run_all(flows, [read_flow("ini_section_none", ini, probe="sec", Action="EntireSection", Section="nope")])
    assert not runs[0].exceptions, runs[0].exceptions
    assert json.loads(text_of(runs[0], "sec")) == {}


def test_read_the_section_names_gives_all_of_them(flows, tmp_path):
    ini = tmp_path / "names.ini"
    write_ini(ini, "[mySection]\nmyKey=1\n[yourSection]\nk=2\n")
    runs = run_all(flows, [read_flow("ini_names", ini, Action="SectionNames")])
    assert not runs[0].exceptions, runs[0].exceptions
    assert sorted(json.loads(text_of(runs[0]))) == ["mySection", "yourSection"]


def test_read_from_a_missing_file_is_an_exception(flows, tmp_path):
    runs = run_all(flows, [read_flow("ini_read_missing", tmp_path / "none.ini", Action="Key", Section="s", Key="k",
                                     WhenError="Exception")])
    assert message_of(runs[0]) == "File '%s' does not exist." % (tmp_path / "none.ini")


def test_write_refuses_a_folder_and_empty_names(flows, tmp_path):
    """An empty Section or Key has WarnIfEmpty: the parameter evaluation ends the element first (the text of
    ParamEvaluator, as for every element)."""
    folder = tmp_path / "folder"
    folder.mkdir()
    runs = run_all(flows, [
        write_flow("ini_write_folder", folder, "s", "k", "v"),
        write_flow("ini_write_no_section", tmp_path / "w.ini", "", "k", "v"),
        write_flow("ini_write_no_key", tmp_path / "w.ini", "s", "", "v"),
    ])
    assert message_of(runs[0]) == "File '%s' is a folder." % folder
    assert message_of(runs[1]) == "String 'Section' is empty"
    assert message_of(runs[2]) == "String 'Key' is empty"
    assert not (tmp_path / "w.ini").exists(), "a refused write creates no file"


def test_read_refuses_an_empty_section_for_a_key(flows, tmp_path):
    ini = tmp_path / "read_empty.ini"
    write_ini(ini, "[mySection]\nmyKey=1\n")
    runs = run_all(flows, [read_flow("ini_read_no_section", ini, Action="Key", Section="", Key="myKey",
                                     WhenError="Exception")])
    assert message_of(runs[0]) == "String 'Section' is empty"


def test_delete_a_key_and_a_section(flows, tmp_path):
    ini = tmp_path / "delete.ini"
    write_ini(ini, "[mySection]\nmyKey=1\nyourKey=2\n[other]\nx=3\n")
    runs = run_all(flows, [
        element_flow("ini_delete_key", "Action_Delete_From_Ini", file=str(ini), Action="DeleteKey",
                     Section="mySection", Key="myKey"),
        read_flow("ini_after_key", ini, Action="Key", Section="mySection", Key="myKey", WhenError="Exception"),
        element_flow("ini_delete_section", "Action_Delete_From_Ini", file=str(ini), Action="DeleteSection",
                     Section="other"),
        read_flow("ini_after_section", ini, probe="sec", Action="EntireSection", Section="other"),
    ])
    assert not runs[0].exceptions, runs[0].exceptions
    assert message_of(runs[1]) == "Section 'mySection' and key 'myKey' not found."
    assert not runs[2].exceptions, runs[2].exceptions
    assert json.loads(text_of(runs[3], "sec")) == {}


def test_delete_a_key_needs_a_key_and_a_section(flows, tmp_path):
    ini = tmp_path / "delete_checks.ini"
    write_ini(ini, "[mySection]\nmyKey=1\n")
    runs = run_all(flows, [
        element_flow("ini_delete_nokey", "Action_Delete_From_Ini", file=str(ini), Action="DeleteKey",
                     Section="mySection", Key=""),
        element_flow("ini_delete_nosection", "Action_Delete_From_Ini", file=str(ini), Action="DeleteKey",
                     Section="", Key="myKey"),
    ])
    assert message_of(runs[0]) == "String 'Key' is empty"
    assert message_of(runs[1]) == "String 'Section' is empty"
    assert (ini.read_bytes()[2:].decode("utf-16-le")).count("myKey") == 1, "a refused delete changes nothing"


def test_delete_from_a_missing_file_is_an_exception(flows, tmp_path):
    runs = run_all(flows, [element_flow("ini_delete_missing", "Action_Delete_From_Ini",
                                        file=str(tmp_path / "none.ini"), Action="DeleteSection", Section="s")])
    assert message_of(runs[0]) == "File '%s' does not exist." % (tmp_path / "none.ini")
