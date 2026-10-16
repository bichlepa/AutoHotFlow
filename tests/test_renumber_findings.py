"""tools/renumber_findings.py on a temporary git repository: mapping, references, line endings, refusals, commit.

The repository has a base branch "v2-port" with final IDs only; the work branch adds the provisional ones. The
provisional IDs are built with "F-%04d" so that no source file of the repository contains a literal provisional ID
(the tool would renumber it)."""

import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import renumber_findings  # noqa: E402

V1_DIR = "v1"
OPEN_BASE = b"# Open\r\n\r\n| ID | Title |\r\n|---|---|\r\n| F-0086 | old |\r\n\r\n### F-0086: old finding\r\n\r\nText.\r\n"
CLOSED_BASE = b"# Closed\n\n### F-0085: closed one\n"


def prov(n):
    return "F-%04d" % n


def git(repo, *args):
    return subprocess.run(["git", *args], cwd=str(repo), check=True, capture_output=True).stdout.decode("utf-8")


def write(repo, rel, data):
    path = repo / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data if isinstance(data, bytes) else data.encode("utf-8"))


def make_repo(root, base_files, branch_files):
    """Base commit on v2-port, then one commit on the branch "work" with branch_files (not empty)."""
    root.mkdir(parents=True, exist_ok=True)
    git(root, "init", "-q")
    git(root, "symbolic-ref", "HEAD", "refs/heads/v2-port")
    git(root, "config", "user.name", "t")
    git(root, "config", "user.email", "t@example.invalid")
    for rel, data in base_files.items():
        write(root, rel, data)
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "base")
    git(root, "checkout", "-q", "-b", "work")
    for rel, data in branch_files.items():
        write(root, rel, data)
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "branch")
    return root


OPEN_BRANCH = (
    "# Open\r\n\r\n"
    "| ID | Title |\r\n|---|---|\r\n| F-0086 | old |\r\n\r\n"
    "### F-0086: old finding\r\n\r\nText.\r\n\r\n"
    "### %s*: new finding\r\n\r\nSee %s and %s*.\r\n\r\n"
    "### %s*: second finding\r\n\r\nText.\r\n" % (prov(9000), prov(9000), prov(9000), prov(9001))
).encode("utf-8")
CLOSED_BRANCH = "# Closed\n\n### F-0085: closed one\n\n### %s: closed provisional\n\nText %s.\n" % (prov(9002), prov(9001))
BASE_FILES = {
    "doc/OPEN-ITEMS.md": OPEN_BASE,
    "doc/CLOSED-ITEMS.md": CLOSED_BASE,
    # old text in the history: provisional IDs, one without heading, in a file the branch does not change
    "work_items/old.md": "history mentions %s and %s\n" % (prov(9000), prov(9500)),
    "assets/x.bin": b"\x00\x01" + prov(9000).encode("ascii") + b"\x00",
    V1_DIR + "/old.txt": "left alone %s\n" % prov(9000),
}
BRANCH_FILES = {
    "doc/OPEN-ITEMS.md": OPEN_BRANCH,
    "doc/CLOSED-ITEMS.md": CLOSED_BRANCH,
    "tests/t.py": "# refers to %s and %s*\nX = 1\n" % (prov(9001), prov(9002)),
}


@pytest.fixture
def repo(tmp_path):
    return make_repo(tmp_path / "ws", BASE_FILES, BRANCH_FILES)


def test_mapping_follows_the_order_of_the_headings(repo):
    mapping, _ = renumber_findings.plan(repo, "v2-port")
    assert {k.decode(): v for k, v in mapping.items()} == {"9000": "F-0087", "9001": "F-0088", "9002": "F-0089"}


def test_references_in_changed_files_are_replaced_and_line_endings_kept(repo):
    assert renumber_findings.main([], repo=repo) == 0
    opened = (repo / "doc/OPEN-ITEMS.md").read_bytes()
    assert b"### F-0087: new finding" in opened
    assert b"\r\n" in opened and b"\n" not in opened.replace(b"\r\n", b"")
    assert b"See F-0087 and F-0087." in opened
    assert prov(9000).encode() not in opened
    closed = (repo / "doc/CLOSED-ITEMS.md").read_bytes()
    assert b"### F-0089: closed provisional" in closed and b"\r\n" not in closed
    assert b"Text F-0088." in closed
    assert (repo / "tests/t.py").read_text(encoding="utf-8").startswith("# refers to F-0088 and F-0089")


def test_provisional_id_in_an_untouched_file_is_left_alone_and_does_not_refuse(repo, capsys):
    """work_items/old.md is not changed by the branch: its references, one of them without heading, stay as they are."""
    before = (repo / "work_items/old.md").read_bytes()
    assert renumber_findings.main([], repo=repo) == 0
    assert (repo / "work_items/old.md").read_bytes() == before
    assert "work_items/old.md" not in capsys.readouterr().out


def test_binary_and_v1_files_are_not_touched(repo):
    before = {rel: (repo / rel).read_bytes() for rel in ("assets/x.bin", V1_DIR + "/old.txt")}
    renumber_findings.main([], repo=repo)
    assert {rel: (repo / rel).read_bytes() for rel in before} == before


def test_dry_run_changes_nothing(repo, capsys):
    before = (repo / "doc/OPEN-ITEMS.md").read_bytes()
    assert renumber_findings.main(["--dry-run"], repo=repo) == 0
    assert (repo / "doc/OPEN-ITEMS.md").read_bytes() == before
    out = capsys.readouterr().out
    assert prov(9000) + "* -> F-0087" in out and "dry run: nothing written" in out
    assert git(repo, "status", "--porcelain").strip() == ""


def test_commit_message_is_the_mapping(repo):
    assert renumber_findings.main(["--commit"], repo=repo) == 0
    subject = git(repo, "log", "-1", "--format=%s").strip()
    assert subject == ("Renumber provisional findings: %s* -> F-0087, %s* -> F-0088, %s* -> F-0089"
                       % (prov(9000), prov(9001), prov(9002)))
    assert "Co-Authored-By" not in git(repo, "log", "-1", "--format=%b")
    assert git(repo, "status", "--porcelain").strip() == ""


def test_no_provisional_heading_means_nothing_to_renumber(tmp_path, capsys):
    root = make_repo(tmp_path / "ws", {"doc/OPEN-ITEMS.md": "### F-0001: a\n", "doc/CLOSED-ITEMS.md": "### F-0002: b\n"},
                     {"work_items/new.md": "history mentions %s\n" % prov(9000)})   # a reference is not a reason
    assert renumber_findings.main([], repo=root) == 0
    assert "nothing to renumber" in capsys.readouterr().out


def test_dirty_working_tree_is_refused(repo, capsys):
    write(repo, "doc/OPEN-ITEMS.md", "changed\n")
    assert renumber_findings.main([], repo=repo) == 2
    assert "working tree" in capsys.readouterr().out


def test_reference_without_heading_in_a_changed_file_refuses(repo, capsys):
    write(repo, "tests/extra.py", "# %s has no heading\n" % prov(9009))
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "extra")
    before = {rel: (repo / rel).read_bytes() for rel in ("doc/OPEN-ITEMS.md", "doc/CLOSED-ITEMS.md")}
    assert renumber_findings.main([], repo=repo) == 1
    assert "tests/extra.py:1: %s" % prov(9009) in capsys.readouterr().out
    assert {rel: (repo / rel).read_bytes() for rel in before} == before


def test_used_final_number_anywhere_in_the_repository_refuses(tmp_path, capsys):
    root = make_repo(tmp_path / "ws", dict(BASE_FILES, **{"notes.txt": "the number F-0087 is taken\n"}), BRANCH_FILES)
    assert renumber_findings.main([], repo=root) == 1
    out = capsys.readouterr().out
    assert "F-0087 is already used" in out and "notes.txt" in out


def test_gap_in_the_final_series_refuses(tmp_path, capsys):
    """The series F-0086, F-0088 has a gap, so the renumbering would not pass the ID test."""
    root = make_repo(tmp_path / "ws", {"README.txt": "base\n"}, {
        "doc/OPEN-ITEMS.md": "### F-0086: a\n\n### F-0088: b\n\n### %s*: c\n" % prov(9000),
        "doc/CLOSED-ITEMS.md": "",
    })
    assert renumber_findings.main([], repo=root) == 1
    assert "gap" in capsys.readouterr().out


def test_both_option_is_a_usage_error(repo):
    assert renumber_findings.main(["--dry-run", "--commit"], repo=repo) == 2


def test_unknown_base_is_a_usage_error(repo):
    assert renumber_findings.main(["--base", "no-such-ref"], repo=repo) == 2
