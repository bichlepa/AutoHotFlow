"""WI-0120: end-to-end tests of the file elements of the package Default: Read from file, Write to file, Copy file, Move file,
Rename file, Delete file, the condition File exists and Split path. Every test works in its own temporary folder (pytest
tmp_path); no file of the user is touched. The Recycle method goes through the system seam (TestSystemProvider), so no
recycle bin is used. Each flow runs in a real session (support/flowrun.py); the result is a probe of the variable `x`, the
files on disk, or the exception of the run. The expected texts are those of v1 unless MIGRATION M-0113 to M-0118 says
otherwise.
"""

import pytest

from support.coreflows import answer, condition_flow, run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.system import SystemScript


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
    """The probed text of a variable of run_all; the test fails when the flow did not reach the probe."""
    probe = run.seen.get(name)
    assert probe is not None, run.exceptions
    return probe.text


def message_of(run):
    """The exception message of the element of a run that ended with an exception."""
    assert run.exceptions, run.steps
    return run.exceptions[0]


# --- Read from file -------------------------------------------------------------------------------------------------------
def read_flow(name, path, **pars):
    return element_flow(name, "Action_Read_From_File", probe="x", varname="x", file=str(path), **pars)


def test_read_utf8_replaces_crlf_by_linefeed(flows, tmp_path):
    path = tmp_path / "text.txt"
    path.write_bytes("Zeile 1\r\nZeile \u00e4\u00f6\n".encode("utf-8"))
    runs = run_all(flows, [read_flow("read_default", path), read_flow("read_no_lf", path, Linefeed=0)])
    assert text_of(runs[0]) == "Zeile 1\nZeile \u00e4\u00f6\n"
    assert text_of(runs[1]) == "Zeile 1\r\nZeile \u00e4\u00f6\n"


def test_read_other_codepage_and_utf16(flows, tmp_path):
    cp = tmp_path / "cp.txt"
    cp.write_bytes("gr\u00fc\u00dfe".encode("cp1252"))
    wide = tmp_path / "wide.txt"
    wide.write_bytes("\ufeffhallo".encode("utf-16-le"))
    runs = run_all(flows, [
        read_flow("read_cp1252", cp, Encoding="other", CodePageIdentifier="1252"),
        read_flow("read_utf16", wide, Encoding="UTF-16"),
    ])
    assert text_of(runs[0]) == "gr\u00fc\u00dfe"
    assert text_of(runs[1]) == "hallo"


def test_read_raw_gives_one_character_per_byte(flows, tmp_path):
    path = tmp_path / "bytes.bin"
    path.write_bytes(bytes([0x41, 0x42, 0xFF, 0x0D, 0x0A]))
    runs = run_all(flows, [read_flow("read_raw", path, Encoding="raw")])
    assert text_of(runs[0]) == "AB\u00ff\r\n"


def test_read_size_limit_takes_the_leading_bytes(flows, tmp_path):
    path = tmp_path / "long.txt"
    path.write_bytes(b"abcdefgh")
    runs = run_all(flows, [read_flow("read_limit", path, EnableSizeLimit=1, SizeLimit="3")])
    assert text_of(runs[0]) == "abc"


def test_read_errors_are_exceptions_with_the_v1_texts(flows, tmp_path):
    folder = tmp_path / "folder"
    folder.mkdir()
    path = tmp_path / "text.txt"
    path.write_bytes(b"x")
    runs = run_all(flows, [
        read_flow("read_missing", tmp_path / "none.txt"),
        read_flow("read_folder", folder),
        read_flow("read_limit_zero", path, EnableSizeLimit=1, SizeLimit="0"),
        read_flow("read_limit_half", path, EnableSizeLimit=1, SizeLimit="1.5"),
    ])
    assert "does not exist" in message_of(runs[0])
    assert "is a folder" in message_of(runs[1])
    assert "is not a positive number" in message_of(runs[2])
    assert "is not an integer" in message_of(runs[3])


# --- Write to file --------------------------------------------------------------------------------------------------------
def write_flow(name, path, text, **pars):
    return element_flow(name, "Action_Write_To_File", text=text, file=str(path), **pars)


def test_write_appends_and_overwrites(flows, tmp_path):
    path = tmp_path / "out.txt"
    runs = run_all(flows, [
        write_flow("write_first", path, "one", Overwrite="Append", Linefeed=0),
        write_flow("write_second", path, "two", Overwrite="Append", Linefeed=0),
        write_flow("write_overwrite", path, "three", Overwrite="Overwrite", Linefeed=0),
    ])
    assert [r.reason for r in runs] == ["finished"] * 3 and not any(r.exceptions for r in runs)
    assert path.read_bytes() == b"three"


def test_write_utf8_bom_only_when_asked(flows, tmp_path):
    with_bom = tmp_path / "bom.txt"
    without = tmp_path / "raw.txt"
    runs = run_all(flows, [
        write_flow("write_bom", with_bom, "a\u00e4", Overwrite="Overwrite", WithBOM=1, Linefeed=0),
        write_flow("write_no_bom", without, "a\u00e4", Overwrite="Overwrite", WithBOM=0, Linefeed=0),
    ])
    assert not any(r.exceptions for r in runs)
    assert with_bom.read_bytes() == b"\xef\xbb\xbf" + "a\u00e4".encode("utf-8")
    assert without.read_bytes() == "a\u00e4".encode("utf-8")


def test_write_linefeeds_become_crlf_once(flows, tmp_path):
    path = tmp_path / "lines.txt"
    runs = run_all(flows, [write_flow("write_lines", path, "a\nb\r\nc", Overwrite="Overwrite", Encoding="UTF-8")])
    assert not runs[0].exceptions
    assert path.read_bytes() == b"a\r\nb\r\nc"


def test_write_other_codepage(flows, tmp_path):
    path = tmp_path / "cp.txt"
    runs = run_all(flows, [write_flow("write_cp", path, "\u00fc", Overwrite="Overwrite", Encoding="Other",
                                      CodePageIdentifier="1252", Linefeed=0)])
    assert not runs[0].exceptions
    assert path.read_bytes() == b"\xfc"


def test_write_overwrite_of_a_file_in_use_is_an_exception(flows, tmp_path):
    path = tmp_path / "locked.txt"
    path.write_bytes(b"old")
    with open(path, "r+b"):             # opened without delete sharing: the file cannot be deleted meanwhile
        runs = run_all(flows, [write_flow("write_in_use", path, "new", Overwrite="Overwrite", Linefeed=0)])
    text = message_of(runs[0])
    assert "could not be deleted" in text and "in use by another program" in text
    assert path.read_bytes() == b"old"


# --- Copy, move, rename, delete a file ------------------------------------------------------------------------------------
def test_copy_one_file_into_a_folder_and_with_a_new_name(flows, tmp_path):
    src = tmp_path / "src.txt"
    src.write_bytes(b"data")
    dest_dir = tmp_path / "dest"
    dest_dir.mkdir()
    runs = run_all(flows, [
        element_flow("copy_into_folder", "Action_Copy_File", file=str(src), destFile=str(dest_dir)),
        element_flow("copy_new_name", "Action_Copy_File", file=str(src), destFile=str(tmp_path / "copy.txt")),
    ])
    assert not any(r.exceptions for r in runs)
    assert (dest_dir / "src.txt").read_bytes() == b"data"
    assert (tmp_path / "copy.txt").read_bytes() == b"data"


def test_copy_a_wildcard_pattern_and_count_the_failures(flows, tmp_path):
    src_dir = tmp_path / "src"
    src_dir.mkdir()
    dest_dir = tmp_path / "dest"
    dest_dir.mkdir()
    for name in ("a.txt", "b.txt", "c.log"):
        (src_dir / name).write_bytes(name.encode())
    (dest_dir / "b.txt").write_bytes(b"exists")
    runs = run_all(flows, [
        element_flow("copy_pattern", "Action_Copy_File", file=str(src_dir / "*.txt"), destFile=str(dest_dir), Overwrite=1),
        element_flow("copy_pattern_no_match", "Action_Copy_File", file=str(src_dir / "*.zip"), destFile=str(dest_dir)),
    ])
    assert not runs[0].exceptions
    assert (dest_dir / "a.txt").read_bytes() == b"a.txt"
    assert (dest_dir / "c.log").exists() is False
    assert "does not exist" in message_of(runs[1])


def test_copy_without_overwrite_refuses_an_existing_file(flows, tmp_path):
    src = tmp_path / "src.txt"
    src.write_bytes(b"new")
    dest = tmp_path / "dest.txt"
    dest.write_bytes(b"old")
    runs = run_all(flows, [element_flow("copy_exists", "Action_Copy_File", file=str(src), destFile=str(dest))])
    assert "already exists" in message_of(runs[0])
    assert dest.read_bytes() == b"old"


def test_move_one_file_and_refuse_an_existing_target(flows, tmp_path):
    src = tmp_path / "move.txt"
    src.write_bytes(b"moved")
    target = tmp_path / "target"
    target.mkdir()
    other = tmp_path / "other.txt"
    other.write_bytes(b"x")
    runs = run_all(flows, [
        element_flow("move_into_folder", "Action_Move_File", file=str(src), destFile=str(target)),
        element_flow("move_onto_existing", "Action_Move_File", file=str(other), destFile=str(target / "move.txt")),
        element_flow("move_overwrite", "Action_Move_File", file=str(other), destFile=str(target / "move.txt"),
                     Overwrite=1),
    ])
    assert not runs[0].exceptions
    assert "already exists" in message_of(runs[1]), "without Overwrite the existing target is an error"
    assert not runs[2].exceptions
    assert not src.exists() and not other.exists()
    assert (target / "move.txt").read_bytes() == b"x", "the last flow overwrote the target"


def test_rename_a_file_keeps_its_folder(flows, tmp_path):
    src = tmp_path / "old.txt"
    src.write_bytes(b"x")
    runs = run_all(flows, [element_flow("rename_file", "Action_Rename_File", file=str(src), newName="new.txt")])
    assert not runs[0].exceptions
    assert not src.exists() and (tmp_path / "new.txt").read_bytes() == b"x"


def test_rename_refuses_a_wildcard_and_an_existing_name(flows, tmp_path):
    (tmp_path / "a.txt").write_bytes(b"a")
    (tmp_path / "b.txt").write_bytes(b"b")
    runs = run_all(flows, [
        element_flow("rename_wild", "Action_Rename_File", file=str(tmp_path / "*.txt"), newName="z.txt"),
        element_flow("rename_taken", "Action_Rename_File", file=str(tmp_path / "a.txt"), newName="b.txt"),
        element_flow("rename_wild_name", "Action_Rename_File", file=str(tmp_path / "a.txt"), newName="*.bak"),
    ])
    assert "Wildcards are not allowed" in message_of(runs[0])
    assert "already exists" in message_of(runs[1])
    assert "Wildcards are not allowed" in message_of(runs[2])
    assert (tmp_path / "a.txt").read_bytes() == b"a"


def test_delete_a_file_and_send_one_to_the_recycle_bin_through_the_seam(flows, tmp_path):
    gone = tmp_path / "gone.txt"
    gone.write_bytes(b"x")
    kept = tmp_path / "kept.txt"
    kept.write_bytes(b"y")
    system = SystemScript(flows.datadir)
    runs = run_all(flows, [
        element_flow("delete_file", "Action_Delete_File", file=str(gone), deleteFileMethod="Delete"),
        element_flow("recycle_file", "Action_Delete_File", file=str(kept), deleteFileMethod="Recycle"),
    ])
    assert not any(r.exceptions for r in runs)
    assert not gone.exists()
    assert kept.exists(), "the test provider records the call; the file is not really recycled"
    calls = [c for c in system.requests() if c["function"] == "FileRecycle"]
    assert calls and calls[0]["args"][0] == str(kept)


def test_delete_a_missing_file_is_an_exception(flows, tmp_path):
    runs = run_all(flows, [element_flow("delete_missing", "Action_Delete_File", file=str(tmp_path / "none.txt"))])
    assert "does not exist" in message_of(runs[0])


# --- File exists and Split path -------------------------------------------------------------------------------------------
def test_file_exists_takes_yes_or_no(flows, tmp_path):
    (tmp_path / "here.txt").write_bytes(b"x")
    runs = run_all(flows, [
        condition_flow("exists_yes", "Condition_File_Exists", file=str(tmp_path / "here.txt")),
        condition_flow("exists_no", "Condition_File_Exists", file=str(tmp_path / "none.txt")),
        condition_flow("exists_folder", "Condition_File_Exists", file=str(tmp_path)),
    ])
    assert [answer(r) for r in runs] == ["YES", "NO", "YES"]


def test_split_path_writes_the_parts_and_skips_empty_names(flows, tmp_path):
    fb = FlowBuilder("split")
    el = fb.action("Action_Split_path", file="C:\\Users\\me\\notes.txt", OutFileName="n", OutDir="d",
                   OutExtension="e", OutNameNoExt="b", OutDrive="")
    fb.chain(fb.trigger(), el, fb.probe("n", "d", "e", "b"))
    run = flows.run(fb)
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert run.probe("n").text == "notes.txt"
    assert run.probe("d").text == "C:\\Users\\me"
    assert run.probe("e").text == "txt"
    assert run.probe("b").text == "notes"


@pytest.mark.parametrize("encoding", ["UTF-8", "other"])
def test_relative_paths_are_in_the_working_directory_of_the_flow(flows, tmp_path, encoding):
    """A flow with its own working directory: a relative path is below it (ParamEvaluator, E0028)."""
    fb = FlowBuilder("relative", flow_settings={"DefaultWorkingDir": 0, "WorkingDir": str(tmp_path)})
    write = fb.action("Action_Write_To_File", text="rel", file="rel.txt", Overwrite="Overwrite", Linefeed=0,
                      Encoding=encoding, CodePageIdentifier="1252")
    read = fb.action("Action_Read_From_File", varname="x", file="rel.txt", Encoding=encoding,
                     CodePageIdentifier="1252")
    fb.chain(fb.trigger(), write, read, fb.probe("x"))
    run = flows.run(fb)
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert (tmp_path / "rel.txt").read_bytes() == b"rel"
    assert run.probe("x").text == "rel"
