"""Line endings of the repository: LF only, except where a file is byte for byte by design.

The repository stores text files with LF (`.gitattributes`: `* text=auto eol=lf`). A CRLF or a mix of both in a text
file is an error: it shows as a changed line in every diff, and an AHK or Python file with mixed endings is a sign of
a broken edit. Files marked `-text` (test data, language files of v1) are compared byte for byte and are exempt.

Checked: the index (what is committed) for all text files, and the working tree for all text files except `v1/`.
`v1/` is the frozen reference (AGENTS.md rule 4): its files keep the CRLF they have on disk, but the index must still
be LF there.

The check uses `git ls-files --eol`. It is skipped when git is not available.
"""

import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]

# top-level folder whose working tree is not checked (the index still is)
WORKTREE_EXEMPT_FOLDER = "v1"


def _eol_records():
    """Yields (index_eol, worktree_eol, attr, path) for every tracked file."""
    git = shutil.which("git")
    if git is None:
        pytest.skip("git is not available")
    out = subprocess.run([git, "ls-files", "--eol", "-z"], cwd=REPO, capture_output=True, check=True).stdout
    for rec in out.decode("utf-8").split("\0"):
        if not rec:
            continue
        meta, path = rec.split("\t", 1)
        index, worktree, attr = meta.split(None, 2)  # attr may contain spaces ("text=auto eol=lf")
        yield index[2:], worktree[2:], attr.strip()[len("attr/"):], path


def _cr_lines(path, limit=5):
    """Line numbers (1-based) with a carriage return, at most `limit`."""
    found = []
    with open(REPO / path, "rb") as f:
        for number, line in enumerate(f, 1):
            if b"\r" in line:
                found.append(number)
                if len(found) >= limit:
                    break
    return found


def test_text_files_are_lf_in_the_index_and_in_the_working_tree():
    problems = []
    for index, worktree, attr, path in _eol_records():
        if attr == "-text":
            continue  # byte for byte by design (see .gitattributes)
        if index in ("crlf", "mixed"):
            problems.append(f"{path}: index is {index} (committed with CR)")
        if path.split("/", 1)[0] == WORKTREE_EXEMPT_FOLDER:
            continue
        if worktree in ("crlf", "mixed"):
            lines = ", lines " + ", ".join(map(str, _cr_lines(path)))
            problems.append(f"{path}: working tree is {worktree}{lines}")
    assert not problems, "CRLF or mixed line endings in text files (expected LF):\n" + "\n".join(problems)


def test_gitattributes_forces_lf_checkout():
    text = (REPO / ".gitattributes").read_text(encoding="utf-8")
    assert "* text=auto eol=lf" in text.splitlines(), "`.gitattributes` must set `* text=auto eol=lf`"
