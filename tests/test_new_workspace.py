"""tools/new_workspace.py: one worktree and one branch per task (doc/PARALLEL-WORK.md). Works on a throw-away repo."""

import os
import subprocess
import sys
from pathlib import Path

import pytest

TOOL = Path(__file__).resolve().parents[1] / "tools" / "new_workspace.py"

pytestmark = pytest.mark.slow      # about 2 s per test: git on Windows


def git(cwd, *args):
    proc = subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args], cwd=str(cwd),
                          capture_output=True)
    assert proc.returncode == 0, proc.stderr.decode("utf-8", "replace")
    return proc.stdout.decode("utf-8", "replace").strip()


@pytest.fixture
def repo(tmp_path):
    main = tmp_path / "proj"
    main.mkdir()
    git(main, "init", "-q", "-b", "v2-port")
    (main / "a.txt").write_text("1\n", encoding="utf-8")
    git(main, "add", "a.txt")
    git(main, "commit", "-q", "-m", "first")
    return main


def tool(repo, *args, expect=0):
    env = dict(os.environ, AHF_WORKSPACES_DIR=str(repo.parent / "ws"))
    proc = subprocess.run([sys.executable, str(TOOL), "--repo", str(repo), *args], capture_output=True, env=env)
    out = proc.stdout.decode("utf-8", "replace") + proc.stderr.decode("utf-8", "replace")
    assert proc.returncode == expect, "exit %d, expected %d:\n%s" % (proc.returncode, expect, out)
    return out


def test_create_gives_a_worktree_on_its_own_branch(repo):
    out = tool(repo, "bugfix-1")
    ws = repo.parent / "ws" / "bugfix-1"
    assert (ws / "a.txt").is_file()
    assert git(ws, "rev-parse", "--abbrev-ref", "HEAD") == "wip/bugfix-1"
    assert git(repo, "rev-parse", "--abbrev-ref", "HEAD") == "v2-port", "the main checkout is not touched"
    assert "wip/bugfix-1" in out


@pytest.mark.parametrize("name", [".hidden", "a b", "a/b", "x" * 41])
def test_bad_names_are_refused(repo, name):
    out = tool(repo, name, expect=1)
    assert "refused" in out


def test_existing_workspace_is_refused(repo):
    tool(repo, "one")
    assert "already exists" in tool(repo, "one", expect=1)


def test_list_shows_commits_and_changes(repo):
    tool(repo, "one")
    ws = repo.parent / "ws" / "one"
    (ws / "b.txt").write_text("x", encoding="utf-8")
    git(ws, "add", "b.txt")
    git(ws, "commit", "-q", "-m", "second")
    (ws / "a.txt").write_text("changed\n", encoding="utf-8")
    out = tool(repo, "--list")
    assert "wip/one" in out and "+1/-0 vs v2-port" in out and "1 changed file" in out


def test_remove_refuses_uncommitted_work_and_keeps_an_unmerged_branch(repo):
    tool(repo, "one")
    ws = repo.parent / "ws" / "one"
    (ws / "b.txt").write_text("x", encoding="utf-8")
    git(ws, "add", "b.txt")
    out = tool(repo, "--remove", "one", expect=1)
    assert "uncommitted" in out and ws.exists()
    git(ws, "commit", "-q", "-m", "work")
    out = tool(repo, "--remove", "one")
    assert not ws.exists() and "kept" in out
    assert "wip/one" in git(repo, "branch", "--list")


def test_remove_deletes_a_merged_branch(repo):
    tool(repo, "two")
    ws = repo.parent / "ws" / "two"
    (ws / "c.txt").write_text("y", encoding="utf-8")
    git(ws, "add", "c.txt")
    git(ws, "commit", "-q", "-m", "work")
    git(repo, "merge", "-q", "--ff-only", "wip/two")
    out = tool(repo, "--remove", "two")
    assert "deleted" in out and "wip/two" not in git(repo, "branch", "--list")


def test_remove_of_an_unknown_workspace_is_refused(repo):
    assert "no workspace" in tool(repo, "--remove", "nothere", expect=1)


def test_the_tool_works_from_inside_a_workspace(repo):
    """repo may itself be a linked worktree (an agent runs the tool from its workspace)."""
    tool(repo, "one")
    inside = repo.parent / "ws" / "one"
    env = dict(os.environ, AHF_WORKSPACES_DIR=str(repo.parent / "ws"))
    proc = subprocess.run([sys.executable, str(TOOL), "--repo", str(inside), "--list"], capture_output=True, env=env)
    assert proc.returncode == 0 and b"wip/one" in proc.stdout
