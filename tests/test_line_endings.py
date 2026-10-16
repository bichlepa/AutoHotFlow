"""Line endings of the repository: LF only, except where a file is byte for byte by design.

The repository stores text files with LF (`.gitattributes`: `* text=auto eol=lf`). A CRLF or a mix of both in a text
file is an error: it shows as a changed line in every diff, and an AHK or Python file with mixed endings is a sign of
a broken edit. Files marked `-text` (test data, language files of v1) are compared byte for byte and are exempt.

Checked: the index (what is committed) for all text files. The working tree is not checked: `.gitattributes` makes git
convert CRLF to LF when a file is staged, so CRLF on disk never reaches the repository, and a test must not fail on the
uncommitted edits of another agent or editor. `v1/` keeps the CRLF it has on disk (AGENTS.md rule 4); its index must be LF.

The check uses `git ls-files --eol`. It is skipped when git is not available.
"""

import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]

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


def test_text_files_are_lf_in_the_index():
    problems = []
    for index, worktree, attr, path in _eol_records():
        if attr == "-text":
            continue  # byte for byte by design (see .gitattributes)
        if index in ("crlf", "mixed"):
            problems.append(f"{path}: index is {index} (committed with CR)")
    assert not problems, "CRLF or mixed line endings in the index (expected LF):\n" + "\n".join(problems)


def test_gitattributes_forces_lf_checkout():
    text = (REPO / ".gitattributes").read_text(encoding="utf-8")
    assert "* text=auto eol=lf" in text.splitlines(), "`.gitattributes` must set `* text=auto eol=lf`"
