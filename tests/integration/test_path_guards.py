"""WI-0120 (review fix): the path guards of the file and folder elements (MIGRATION M-0119) and the wildcard guard of Write to
file. Every flow runs with its own working directory inside the temporary folder of the test (tmp_path / "wd"), so an
unguarded delete could only reach that folder. A drive root is tested only where a failed call is harmless (Delete folder
without its contents), so the test itself cannot delete a drive.
"""

from pathlib import Path

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def wd_flow(name, root, cls, **pars):
    """trigger -> the element, with the working directory root / "wd" of the flow."""
    fb = FlowBuilder(name, flow_settings={"DefaultWorkingDir": 0, "WorkingDir": str(root / "wd")})
    fb.chain(fb.trigger(), fb.action(cls, **pars))
    return fb


def message_of(run):
    """The exception message of the element of a run that ended with an exception."""
    assert run.exceptions, run.steps
    return run.exceptions[0]


@pytest.fixture
def workdir(tmp_path):
    wd = tmp_path / "wd"
    (wd / "sub").mkdir(parents=True)
    (wd / "keep.txt").write_bytes(b"keep")
    (wd / "sub" / "deep.txt").write_bytes(b"deep")
    return wd


def contents_kept(wd):
    return (wd / "keep.txt").read_bytes() == b"keep" and (wd / "sub" / "deep.txt").read_bytes() == b"deep"


def test_delete_folder_refuses_an_empty_path_and_the_working_directory(flows, tmp_path, workdir):
    runs = run_all(flows, [
        wd_flow("df_empty", tmp_path, "Action_Delete_Folder", Folder="", ifEmpty=0),
        wd_flow("df_dot", tmp_path, "Action_Delete_Folder", Folder=".", ifEmpty=0),
        wd_flow("df_dot_wild", tmp_path, "Action_Delete_Folder", Folder=".\\*", ifEmpty=0),
    ])
    assert "is empty" in message_of(runs[0])
    assert "working directory of the flow" in message_of(runs[1])
    assert "working directory of the flow" in message_of(runs[2])
    assert contents_kept(workdir)


def test_delete_folder_refuses_a_drive_root_and_a_path_below_the_drive_root(flows, tmp_path, workdir):
    # ifEmpty = 1: a non-recursive delete, so the test cannot empty a drive even if the guard were missing
    runs = run_all(flows, [
        wd_flow("df_root", tmp_path, "Action_Delete_Folder", Folder=str(Path(tmp_path.anchor)), ifEmpty=1),
        wd_flow("df_rooted", tmp_path, "Action_Delete_Folder", Folder="\\sub", ifEmpty=0),
    ])
    assert "drive root" in message_of(runs[0])
    assert "drive root" in message_of(runs[1])
    assert contents_kept(workdir)


def test_move_delete_and_folder_elements_refuse_an_empty_source_or_target(flows, tmp_path, workdir):
    runs = run_all(flows, [
        wd_flow("mf_empty_target", tmp_path, "Action_Move_File", file=str(workdir / "keep.txt"), destFile=""),
        wd_flow("mf_empty_source", tmp_path, "Action_Move_File", file="", destFile=str(tmp_path / "x.txt")),
        wd_flow("delf_empty", tmp_path, "Action_Delete_File", file=""),
        wd_flow("cf_empty", tmp_path, "Action_Copy_Folder", folder="", destFolder=str(tmp_path / "copy")),
        wd_flow("mdf_empty_target", tmp_path, "Action_Move_Folder", folder=str(workdir / "sub"), destFolder=""),
        wd_flow("rf_empty", tmp_path, "Action_Rename_Folder", folder="", newName="x"),
    ])
    for run in runs:
        assert "is empty" in message_of(run)
    assert contents_kept(workdir)
    assert not (tmp_path / "x.txt").exists() and not (tmp_path / "copy").exists()


def test_write_overwrite_with_a_wildcard_keeps_the_matching_files(flows, tmp_path):
    (tmp_path / "a.txt").write_bytes(b"a")
    (tmp_path / "b.txt").write_bytes(b"b")
    fb = FlowBuilder("write_wild")
    el = fb.action("Action_Write_To_File", text="x", file=str(tmp_path / "*.txt"), Overwrite="Overwrite", Linefeed=0)
    fb.chain(fb.trigger(), el)
    runs = run_all(flows, [fb])
    assert "Wildcards are not allowed" in message_of(runs[0])
    assert (tmp_path / "a.txt").read_bytes() == b"a"
    assert (tmp_path / "b.txt").read_bytes() == b"b"
