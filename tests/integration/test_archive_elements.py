"""WI-0122: end-to-end tests of the archive elements of the package Default: Compress files and Extract files, with tar.exe of
Windows (TarOps). Every test works in its own temporary folder (pytest tmp_path). The archives that a test crafts (an entry
that leaves the folder, a link) are written with the Python modules zipfile and tarfile.

The formats: zip, 7z, tar, and the tar archives with gzip, bzip2 and xz are written and read back (M-0141). A single file
compressed with gzip, bzip2 or xz without tar is not an archive for tar.exe, so Extract ends with an exception (M-0141).
"""

import gzip
import io
import tarfile
import zipfile
from pathlib import Path

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def compress_flow(name, source, archive, format_):
    fb = FlowBuilder(name)
    el = fb.action("Action_Compress_files", file=str(source), zipfile=str(archive), zipformat=format_)
    fb.chain(fb.trigger(), el)
    return fb


def extract_flow(name, archive, folder, format_="*"):
    fb = FlowBuilder(name)
    el = fb.action("Action_Extract_files", zipfile=str(archive), folder=str(folder), zipformat=format_)
    fb.chain(fb.trigger(), el)
    return fb


def message_of(run):
    assert run.exceptions, run.steps
    return run.exceptions[0]


@pytest.fixture
def tree(tmp_path):
    """A source folder with a text file, a file with a non-ASCII name and a sub folder."""
    root = tmp_path / "source"
    (root / "sub").mkdir(parents=True)
    (root / "one.txt").write_bytes(b"first file\n")
    (root / "sub" / "two.txt").write_bytes(b"second file\n")
    (root / "Gr\u00f6\u00dfe \u00fc.txt").write_bytes(b"umlauts\n")
    return root


def read_tree(folder: Path):
    """Relative paths and contents of every file under folder (the archives store the folder itself as its name)."""
    found = {}
    for path in folder.rglob("*"):
        if path.is_file():
            found[path.relative_to(folder).as_posix()] = path.read_bytes()
    return found


def assert_same_files(source: Path, extracted: Path):
    """Every file of source is in extracted with the same contents (the archive keeps the name of the source folder)."""
    wanted = {rel: data for rel, data in read_tree(source).items()}
    got = read_tree(extracted)
    for rel, data in wanted.items():
        matches = [value for key, value in got.items() if key.endswith(rel)]
        assert data in matches, (rel, sorted(got))


# --- Compress and extract, one format each -----------------------------------------------------------------------------
@pytest.mark.parametrize("format_, suffix", [
    ("zip", ".zip"), ("7z", ".7z"), ("tar", ".tar"), ("gzip", ".tar.gz"), ("BZIP2", ".tar.bz2"), ("xz", ".tar.xz"),
])
def test_a_folder_is_compressed_and_extracted_again(flows, tmp_path, tree, format_, suffix):
    archive = tmp_path / ("packed" + suffix)
    back = tmp_path / ("back_" + format_)
    back.mkdir()
    # one session: the flows of a run_all run one after the other, so the extract sees the archive of the compress
    runs = run_all(flows, [compress_flow("c_" + format_, tree, archive, format_),
                           extract_flow("x_" + format_, archive, back)])
    assert not runs[0].exceptions, runs[0].steps
    assert archive.is_file() and archive.stat().st_size > 0
    assert not runs[1].exceptions, runs[1].steps
    assert_same_files(tree, back)


def test_a_single_file_is_compressed_to_a_zip_archive(flows, tmp_path, tree):
    archive = tmp_path / "one.zip"
    runs = run_all(flows, [compress_flow("single", tree / "one.txt", archive, "zip")])
    assert not runs[0].exceptions, runs[0].steps
    with zipfile.ZipFile(archive) as zf:
        assert zf.read("one.txt") == b"first file\n"


def test_an_existing_archive_is_replaced(flows, tmp_path, tree):
    archive = tmp_path / "again.zip"
    archive.write_bytes(b"old content, not a zip")
    runs = run_all(flows, [compress_flow("replace", tree / "one.txt", archive, "zip")])
    assert not runs[0].exceptions, runs[0].steps
    with zipfile.ZipFile(archive) as zf:
        assert zf.namelist() == ["one.txt"]


def test_the_name_with_umlauts_survives_a_zip_round_trip(flows, tmp_path, tree):
    archive = tmp_path / "umlauts.zip"
    back = tmp_path / "umlauts_back"
    back.mkdir()
    runs = run_all(flows, [compress_flow("umlaut_c", tree, archive, "zip"), extract_flow("umlaut_x", archive, back)])
    assert not runs[0].exceptions and not runs[1].exceptions, (runs[0].steps, runs[1].steps)
    assert (back / "source" / "Gr\u00f6\u00dfe \u00fc.txt").read_bytes() == b"umlauts\n"


# --- Errors of the compress side ----------------------------------------------------------------------------------------
def test_a_missing_source_is_an_exception(flows, tmp_path):
    runs = run_all(flows, [compress_flow("missing_src", tmp_path / "nothing", tmp_path / "x.zip", "zip")])
    assert "does not exist" in message_of(runs[0])
    assert not (tmp_path / "x.zip").exists()


def test_a_wildcard_source_is_an_exception(flows, tmp_path, tree):
    runs = run_all(flows, [compress_flow("wild_src", tree / "*.txt", tmp_path / "x.zip", "zip")])
    assert "not allowed" in message_of(runs[0]) or "Wildcard" in message_of(runs[0])
    assert not (tmp_path / "x.zip").exists()


def test_a_folder_as_destination_is_an_exception(flows, tmp_path, tree):
    target = tmp_path / "target_folder"
    target.mkdir()
    runs = run_all(flows, [compress_flow("dest_folder", tree / "one.txt", target, "zip")])
    assert "is a folder" in message_of(runs[0])


def test_a_destination_in_a_missing_folder_is_an_exception(flows, tmp_path, tree):
    runs = run_all(flows, [compress_flow("no_dir", tree / "one.txt", tmp_path / "missing" / "x.zip", "zip")])
    assert "does not exist" in message_of(runs[0])


def test_a_drive_root_as_destination_is_refused_before_tar_runs(flows, tree):
    runs = run_all(flows, [compress_flow("root_dest", tree / "one.txt", "C:\\", "zip")])
    assert "drive root" in message_of(runs[0])


def test_a_percent_sign_in_the_destination_is_refused(flows, tmp_path, tree):
    runs = run_all(flows, [compress_flow("percent", tree / "one.txt", tmp_path / "50%.zip", "zip")])
    assert "cannot be passed to tar.exe" in message_of(runs[0])
    assert not (tmp_path / "50%.zip").exists()


# --- Extract -----------------------------------------------------------------------------------------------------------
def test_a_missing_archive_is_an_exception(flows, tmp_path):
    back = tmp_path / "back"
    back.mkdir()
    runs = run_all(flows, [extract_flow("no_archive", tmp_path / "missing.zip", back)])
    assert "does not exist" in message_of(runs[0])


def test_a_folder_as_archive_is_an_exception(flows, tmp_path):
    back = tmp_path / "back"
    back.mkdir()
    runs = run_all(flows, [extract_flow("archive_is_folder", tmp_path, back)])
    assert "is a folder" in message_of(runs[0])


def test_a_missing_destination_folder_is_an_exception(flows, tmp_path, tree):
    archive = tmp_path / "x.zip"
    runs = run_all(flows, [compress_flow("mk", tree / "one.txt", archive, "zip"),
                           extract_flow("no_folder", archive, tmp_path / "nowhere")])
    assert not runs[0].exceptions, runs[0].steps
    assert "does not exist" in message_of(runs[1])


def test_a_file_as_destination_folder_is_an_exception(flows, tmp_path, tree):
    archive = tmp_path / "x.zip"
    file_as_folder = tmp_path / "plain.txt"
    file_as_folder.write_bytes(b"x")
    runs = run_all(flows, [compress_flow("mk2", tree / "one.txt", archive, "zip"),
                           extract_flow("file_folder", archive, file_as_folder)])
    assert not runs[0].exceptions, runs[0].steps
    assert "is not a folder" in message_of(runs[1])


def test_a_drive_root_as_destination_is_refused(flows, tmp_path, tree):
    archive = tmp_path / "x.zip"
    runs = run_all(flows, [compress_flow("mk3", tree / "one.txt", archive, "zip"),
                           extract_flow("root_extract", archive, "C:\\")])
    assert not runs[0].exceptions, runs[0].steps
    assert "drive root" in message_of(runs[1])


def test_a_gzip_file_without_tar_is_not_an_archive(flows, tmp_path):
    """A single file compressed with gzip (v1 "gzip") is not a tar archive, and tar.exe does not read it (M-0141)."""
    raw = tmp_path / "single.gz"
    raw.write_bytes(gzip.compress(b"plain text inside gzip\n"))
    back = tmp_path / "back"
    back.mkdir()
    runs = run_all(flows, [extract_flow("raw_gz", raw, back)])
    assert "Extracting the archive failed" in message_of(runs[0]) or "failed" in message_of(runs[0])
    assert list(back.iterdir()) == []


def _zip_bytes(entries):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for name, data in entries:
            zf.writestr(name, data)
    return buf.getvalue()


def test_an_entry_that_leaves_the_folder_refuses_the_whole_archive(flows, tmp_path):
    """Zip slip: an entry "../escape.txt" would be written next to the folder. Nothing is extracted (checked before)."""
    archive = tmp_path / "slip.zip"
    archive.write_bytes(_zip_bytes([("good.txt", b"good"), ("../escape.txt", b"escaped")]))
    back = tmp_path / "back"
    back.mkdir()
    runs = run_all(flows, [extract_flow("slip", archive, back)])
    assert "leaves the destination folder" in message_of(runs[0])
    assert not (tmp_path / "escape.txt").exists()
    assert list(back.iterdir()) == []


def test_an_absolute_entry_name_refuses_the_archive(flows, tmp_path):
    archive = tmp_path / "absolute.zip"
    archive.write_bytes(_zip_bytes([("C:/Windows/evil.txt", b"x")]))
    back = tmp_path / "back"
    back.mkdir()
    runs = run_all(flows, [extract_flow("absolute", archive, back)])
    assert "leaves the destination folder" in message_of(runs[0])


def test_a_tar_symlink_refuses_the_archive(flows, tmp_path):
    """A symbolic link in the archive could point outside the folder: such an archive is refused as a whole."""
    archive = tmp_path / "link.tar"
    with tarfile.open(archive, "w") as tf:
        info = tarfile.TarInfo("link")
        info.type = tarfile.SYMTYPE
        info.linkname = "..\\..\\outside"
        tf.addfile(info)
    back = tmp_path / "back"
    back.mkdir()
    runs = run_all(flows, [extract_flow("symlink", archive, back)])
    assert "link or a device" in message_of(runs[0])
    assert list(back.iterdir()) == []


def test_an_entry_inside_a_folder_is_extracted(flows, tmp_path):
    archive = tmp_path / "inside.zip"
    archive.write_bytes(_zip_bytes([("a/b/c.txt", b"deep"), ("top.txt", b"top")]))
    back = tmp_path / "back"
    back.mkdir()
    runs = run_all(flows, [extract_flow("inside", archive, back)])
    assert not runs[0].exceptions, runs[0].steps
    assert (back / "a" / "b" / "c.txt").read_bytes() == b"deep"
    assert (back / "top.txt").read_bytes() == b"top"


def test_an_existing_file_of_the_folder_is_replaced_by_the_archive(flows, tmp_path):
    archive = tmp_path / "over.zip"
    archive.write_bytes(_zip_bytes([("same.txt", b"new")]))
    back = tmp_path / "back"
    back.mkdir()
    (back / "same.txt").write_bytes(b"old")
    runs = run_all(flows, [extract_flow("over", archive, back)])
    assert not runs[0].exceptions, runs[0].steps
    assert (back / "same.txt").read_bytes() == b"new"


def test_a_destination_with_a_percent_sign_is_refused(flows, tmp_path):
    archive = tmp_path / "p.zip"
    archive.write_bytes(_zip_bytes([("x.txt", b"x")]))
    folder = tmp_path / "100%"
    folder.mkdir()
    runs = run_all(flows, [extract_flow("pct_folder", archive, folder)])
    assert "cannot be passed to tar.exe" in message_of(runs[0])
    assert list(folder.iterdir()) == []
