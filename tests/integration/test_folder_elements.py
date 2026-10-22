"""WI-0120: end-to-end tests of the folder elements of the package Default: Create folder, Copy folder, Move folder, Rename
folder and Delete folder. Every test works in its own temporary folder (pytest tmp_path). Each flow runs in a real session
(support/flowrun.py); the result is the state of the folders on disk or the exception of the run.
"""

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def element_flow(name, cls, **pars):
    """trigger -> the element."""
    fb = FlowBuilder(name)
    fb.chain(fb.trigger(), fb.action(cls, **pars))
    return fb


def message_of(run):
    """The exception message of the element of a run that ended with an exception."""
    assert run.exceptions, run.steps
    return run.exceptions[0]


def test_create_folder_makes_the_folders_above_too(flows, tmp_path):
    target = tmp_path / "a" / "b"
    runs = run_all(flows, [element_flow("create_nested", "Action_Create_Folder", folder=str(target))])
    assert not runs[0].exceptions
    assert target.is_dir()


def test_create_folder_an_existing_folder_is_fine_unless_asked(flows, tmp_path):
    existing = tmp_path / "there"
    existing.mkdir()
    runs = run_all(flows, [
        element_flow("create_existing", "Action_Create_Folder", folder=str(existing)),
        element_flow("create_existing_error", "Action_Create_Folder", folder=str(existing), ErrorIfExists=1),
    ])
    assert not runs[0].exceptions
    assert "already exists" in message_of(runs[1])


def test_create_folder_where_a_file_is_is_an_exception(flows, tmp_path):
    file = tmp_path / "file.txt"
    file.write_bytes(b"x")
    runs = run_all(flows, [element_flow("create_on_file", "Action_Create_Folder", folder=str(file))])
    assert "exists and it is a file" in message_of(runs[0])


def test_copy_folder_copies_subfolders_and_refuses_an_existing_destination(flows, tmp_path):
    src = tmp_path / "src"
    (src / "sub").mkdir(parents=True)
    (src / "sub" / "deep.txt").write_bytes(b"deep")
    dest = tmp_path / "dest"
    runs = run_all(flows, [
        element_flow("copy_folder", "Action_Copy_Folder", folder=str(src), destFolder=str(dest)),
        element_flow("copy_folder_again", "Action_Copy_Folder", folder=str(src), destFolder=str(dest)),
    ])
    assert not runs[0].exceptions
    assert (dest / "sub" / "deep.txt").read_bytes() == b"deep"
    assert "already exists" in message_of(runs[1])


def test_copy_folder_with_overwrite_merges_into_the_destination(flows, tmp_path):
    src = tmp_path / "src"
    src.mkdir()
    (src / "same.txt").write_bytes(b"new")
    dest = tmp_path / "dest"
    dest.mkdir()
    (dest / "same.txt").write_bytes(b"old")
    (dest / "keep.txt").write_bytes(b"keep")
    runs = run_all(flows, [element_flow("copy_merge", "Action_Copy_Folder", folder=str(src), destFolder=str(dest),
                                        Overwrite=1)])
    assert not runs[0].exceptions
    assert (dest / "same.txt").read_bytes() == b"new"
    assert (dest / "keep.txt").read_bytes() == b"keep"


def test_copy_folder_source_must_be_a_folder(flows, tmp_path):
    file = tmp_path / "file.txt"
    file.write_bytes(b"x")
    runs = run_all(flows, [
        element_flow("copy_source_missing", "Action_Copy_Folder", folder=str(tmp_path / "none"),
                     destFolder=str(tmp_path / "d1")),
        element_flow("copy_source_file", "Action_Copy_Folder", folder=str(file), destFolder=str(tmp_path / "d2")),
    ])
    assert "does not exist" in message_of(runs[0])
    assert "is not a folder" in message_of(runs[1])


def test_move_folder_moves_it_with_its_contents(flows, tmp_path):
    src = tmp_path / "moving"
    (src / "inner").mkdir(parents=True)
    (src / "inner" / "f.txt").write_bytes(b"f")
    dest = tmp_path / "moved"
    runs = run_all(flows, [element_flow("move_folder", "Action_Move_Folder", folder=str(src), destFolder=str(dest))])
    assert not runs[0].exceptions
    assert not src.exists()
    assert (dest / "inner" / "f.txt").read_bytes() == b"f"


def test_rename_folder_keeps_its_parent(flows, tmp_path):
    src = tmp_path / "old"
    src.mkdir()
    (src / "f.txt").write_bytes(b"x")
    runs = run_all(flows, [
        element_flow("rename_folder", "Action_Rename_Folder", folder=str(src), newName="new"),
        element_flow("rename_folder_wild", "Action_Rename_Folder", folder=str(tmp_path / "new"), newName="*"),
    ])
    assert not runs[0].exceptions
    assert not src.exists() and (tmp_path / "new" / "f.txt").read_bytes() == b"x"
    assert "Wildcards are not allowed" in message_of(runs[1])


def test_delete_folder_with_contents(flows, tmp_path):
    folder = tmp_path / "doomed"
    (folder / "inner").mkdir(parents=True)
    (folder / "inner" / "f.txt").write_bytes(b"x")
    runs = run_all(flows, [element_flow("delete_folder", "Action_Delete_Folder", Folder=str(folder), ifEmpty=0)])
    assert not runs[0].exceptions
    assert not folder.exists()


def test_delete_folder_only_if_empty_keeps_a_folder_with_contents(flows, tmp_path):
    """The checkbox "Remove only if the folder is empty" is honoured (MIGRATION M-0114: v1 ignored it)."""
    full = tmp_path / "full"
    full.mkdir()
    (full / "f.txt").write_bytes(b"x")
    empty = tmp_path / "empty"
    empty.mkdir()
    runs = run_all(flows, [
        element_flow("delete_full_if_empty", "Action_Delete_Folder", Folder=str(full), ifEmpty=1),
        element_flow("delete_empty_if_empty", "Action_Delete_Folder", Folder=str(empty), ifEmpty=1),
    ])
    assert "could not be deleted" in message_of(runs[0])
    assert full.exists() and (full / "f.txt").exists()
    assert not runs[1].exceptions and not empty.exists()


def test_delete_folder_missing_is_an_exception_unless_switched_off(flows, tmp_path):
    missing = tmp_path / "none"
    runs = run_all(flows, [
        element_flow("delete_missing", "Action_Delete_Folder", Folder=str(missing), ExceptionIfNotExist=1),
        element_flow("delete_missing_quiet", "Action_Delete_Folder", Folder=str(missing), ExceptionIfNotExist=0),
    ])
    assert "does not exist" in message_of(runs[0])
    assert not runs[1].exceptions and runs[1].reason == "finished"
