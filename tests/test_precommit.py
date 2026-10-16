"""Unit tests of the pre-commit hook tools/precommit.py (fast tier, temporary git repositories, no real index tool)."""

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import precommit  # noqa: E402

INDEX = "doc/DOC-INDEX.md"


def git(repo, *args):
    return subprocess.run(["git", *args], cwd=str(repo), capture_output=True, text=True, check=True).stdout


def make_repo(tmp_path):
    repo = tmp_path / "repo"
    (repo / "doc").mkdir(parents=True)
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "test@example.com")
    git(repo, "config", "user.name", "test")
    (repo / "doc" / "ARCHITECTURE.md").write_bytes(b"# A\n")
    (repo / INDEX).write_bytes(b"index old\n")
    (repo / "notes.txt").write_bytes(b"x\n")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "start")
    return repo


class FakeRegen:
    """Stands in for doc_index.run: writes 'index new' unless it only checks; reports outdated when it would."""
    def __init__(self, new=b"index new\n"):
        self.calls = []
        self.new = new

    def __call__(self, repo, check):
        self.calls.append(check)
        outdated = (repo / INDEX).read_bytes() != self.new
        if check:
            return 1 if outdated else 0
        (repo / INDEX).write_bytes(self.new)
        return 0


def staged(repo):
    return set(git(repo, "diff", "--cached", "--name-only").split())


def test_nothing_staged_does_nothing(tmp_path):
    repo, regen = make_repo(tmp_path), FakeRegen()
    assert precommit.run(repo, regen, partial=False) == 0
    assert regen.calls == []


def test_a_changed_index_is_regenerated_and_added(tmp_path):
    repo, regen = make_repo(tmp_path), FakeRegen()
    (repo / "doc" / "ARCHITECTURE.md").write_bytes(b"# A\n\n## new\n")
    git(repo, "add", "doc/ARCHITECTURE.md")
    assert precommit.run(repo, regen, partial=False) == 0
    assert regen.calls == [False]
    assert staged(repo) == {"doc/ARCHITECTURE.md", INDEX}


def test_an_unchanged_index_is_not_added(tmp_path):
    repo, regen = make_repo(tmp_path), FakeRegen(new=b"index old\n")
    (repo / "notes.txt").write_bytes(b"y\n")
    git(repo, "add", "notes.txt")
    assert precommit.run(repo, regen, partial=False) == 0
    assert staged(repo) == {"notes.txt"}


def test_unstaged_changes_in_an_input_only_check(tmp_path, capsys):
    repo, regen = make_repo(tmp_path), FakeRegen()
    (repo / "notes.txt").write_bytes(b"y\n")
    git(repo, "add", "notes.txt")
    (repo / "doc" / "ARCHITECTURE.md").write_bytes(b"# A\n\n## not staged\n")
    assert precommit.run(repo, regen, partial=False) == 0
    assert regen.calls == [True]
    assert (repo / INDEX).read_bytes() == b"index old\n"
    assert staged(repo) == {"notes.txt"}
    assert "unstaged changes in doc/ARCHITECTURE.md" in capsys.readouterr().out


def test_a_partial_commit_never_writes(tmp_path, capsys):
    repo, regen = make_repo(tmp_path), FakeRegen()
    (repo / "doc" / "ARCHITECTURE.md").write_bytes(b"# A\n\n## new\n")
    git(repo, "add", "doc/ARCHITECTURE.md")
    assert precommit.run(repo, regen, partial=True) == 0
    assert regen.calls == [True]
    assert (repo / INDEX).read_bytes() == b"index old\n"
    assert staged(repo) == {"doc/ARCHITECTURE.md"}
    assert "outdated" in capsys.readouterr().out


def test_a_failing_check_does_not_block(tmp_path, capsys):
    repo = make_repo(tmp_path)

    def failing(repo_, check):
        (repo_ / INDEX).write_bytes(b"index new\n")
        return 1

    (repo / "notes.txt").write_bytes(b"y\n")
    git(repo, "add", "notes.txt")
    assert precommit.run(repo, failing, partial=False) == 0
    assert INDEX in staged(repo)
    assert "warning" in capsys.readouterr().out


def test_partial_commit_is_recognized_by_the_index_file_name(monkeypatch):
    monkeypatch.setenv("GIT_INDEX_FILE", "C:/repo/.git/next-index-15216.lock")
    assert precommit.is_partial_commit()
    monkeypatch.setenv("GIT_INDEX_FILE", "C:/repo/.git/index.lock")
    assert not precommit.is_partial_commit()
    monkeypatch.delenv("GIT_INDEX_FILE")
    assert not precommit.is_partial_commit()


def test_an_untracked_input_document_only_checks(tmp_path, capsys):
    repo, regen = make_repo(tmp_path), FakeRegen()
    (repo / "doc" / "howto").mkdir()
    (repo / "doc" / "howto" / "NEW.md").write_bytes(b"# new entry\n")     # not added: not part of the commit
    (repo / "notes.txt").write_bytes(b"y\n")
    git(repo, "add", "notes.txt")
    assert precommit.run(repo, regen, partial=False) == 0
    assert regen.calls == [True]
    assert (repo / INDEX).read_bytes() == b"index old\n"
    assert "doc/howto/NEW.md" in capsys.readouterr().out
