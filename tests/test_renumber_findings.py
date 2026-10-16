"""tools/renumber_findings.py on a temporary git repository: mapping, references, line endings, refusals, commit.

The provisional IDs are built with "F-%04d" so that no source file of the repository contains a literal provisional
ID (the tool would renumber it)."""

import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import renumber_findings  # noqa: E402


V1_DIR = "v1"


def prov(n):
    return "F-%04d" % n


def git(repo, *args):
    return subprocess.run(["git", *args], cwd=str(repo), check=True, capture_output=True).stdout.decode("utf-8")


def write(repo, rel, data):
    path = repo / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data if isinstance(data, bytes) else data.encode("utf-8"))


def make_repo(root, files):
    root.mkdir(parents=True, exist_ok=True)
    git(root, "init", "-q")
    git(root, "config", "user.name", "t")
    git(root, "config", "user.email", "t@example.invalid")
    for rel, data in files.items():
        write(root, rel, data)
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "base")
    return root


OPEN_CRLF = (
    "# Open\r\n\r\n"
    "| ID | Title |\r\n|---|---|\r\n| F-0086 | old |\r\n\r\n"
    "### F-0086: old finding\r\n\r\nText.\r\n\r\n"
    "### %s*: new finding\r\n\r\nSee %s and %s*.\r\n\r\n"
    "### %s*: second finding\r\n\r\nText.\r\n" % (prov(9000), prov(9000), prov(9000), prov(9001))
)
CLOSED_LF = "# Closed\n\n### F-0085: closed one\n\n### %s: closed provisional\n\nText %s.\n" % (prov(9002), prov(9001))


@pytest.fixture
def repo(tmp_path):
    return make_repo(tmp_path / "ws", {
        "doc/OPEN-ITEMS.md": OPEN_CRLF.encode("utf-8"),
        "doc/CLOSED-ITEMS.md": CLOSED_LF,
        "tests/t.py": "# refers to %s and %s*\nX = 1\n" % (prov(9001), prov(9002)),
        "assets/x.bin": b"\x00\x01" + prov(9000).encode("ascii") + b"\x00",
        V1_DIR + "/old.txt": "left alone %s\n" % prov(9000),
    })


def test_mapping_follows_the_order_of_the_headings(repo):
    result = renumber_findings.plan(repo)
    mapping, _ = result
    assert {k.decode(): v for k, v in mapping.items()} == {"9000": "F-0087", "9001": "F-0088", "9002": "F-0089"}


def test_references_are_replaced_and_line_endings_kept(repo, capsys):
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
    body = git(repo, "log", "-1", "--format=%b")
    assert "Co-Authored-By" not in body
    assert git(repo, "status", "--porcelain").strip() == ""


def test_no_provisional_heading_means_nothing_to_renumber(tmp_path, capsys):
    root = make_repo(tmp_path / "ws", {
        "doc/OPEN-ITEMS.md": "### F-0001: a\n",
        "doc/CLOSED-ITEMS.md": "### F-0002: b\n",
        "work_items/old.md": "history mentions %s\n" % prov(9000),   # a stray reference is not a reason to refuse
    })
    assert renumber_findings.main([], repo=root) == 0
    assert "nothing to renumber" in capsys.readouterr().out


def test_dirty_working_tree_is_refused(repo, capsys):
    write(repo, "doc/OPEN-ITEMS.md", "changed\n")
    assert renumber_findings.main([], repo=repo) == 2
    assert "working tree" in capsys.readouterr().out


def test_reference_without_heading_refuses_and_changes_nothing(repo, capsys):
    write(repo, "tests/extra.py", "# %s has no heading\n" % prov(9009))
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "extra")
    before = {rel: (repo / rel).read_bytes() for rel in ("doc/OPEN-ITEMS.md", "doc/CLOSED-ITEMS.md")}
    assert renumber_findings.main([], repo=repo) == 1
    assert "tests/extra.py:1: %s" % prov(9009) in capsys.readouterr().out
    assert {rel: (repo / rel).read_bytes() for rel in before} == before


def test_used_final_number_refuses(repo, capsys):
    write(repo, "notes.txt", "the number F-0087 is taken\n")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "notes")
    assert renumber_findings.main([], repo=repo) == 1
    out = capsys.readouterr().out
    assert "F-0087 is already used" in out and "notes.txt" in out


def test_gap_in_the_final_series_refuses(tmp_path, capsys):
    """The existing series F-0086, F-0088 has a gap, so the renumbering would not pass the ID test."""
    root = make_repo(tmp_path / "ws", {
        "doc/OPEN-ITEMS.md": "### F-0086: a\n\n### F-0088: b\n\n### %s: c\n" % (prov(9000) + "*"),
        "doc/CLOSED-ITEMS.md": "",
    })
    assert renumber_findings.main([], repo=root) == 1
    assert "gap" in capsys.readouterr().out


def test_both_option_is_a_usage_error(repo):
    assert renumber_findings.main(["--dry-run", "--commit"], repo=repo) == 2
