"""Creates, lists and removes workspaces: one git worktree and one branch per task or agent (doc/PARALLEL-WORK.md).

Usage:
    python tools/new_workspace.py <name> [--from REF]       create branch wip/<name> and the worktree <root>\\<name>
    python tools/new_workspace.py --list                    all workspaces: branch, commits ahead/behind the base, state
    python tools/new_workspace.py --remove <name> [--force] remove the worktree; the branch only when it is merged

Options: --base BRANCH (default v2-port, what "ahead/behind" and "merged" refer to), --repo PATH (default: the
repository of this file). The workspace root is the folder next to the repository, <repo name>-wt (override with
the environment variable AHF_WORKSPACES_DIR).

A workspace holds only what git tracks. Ignored files (v1 binaries, local data) are not copied; the tests do not
need them (tests/data). Long test runs from a workspace: python tools/run_suite.py --with-changes.

Exit codes: 0 done, 1 refused (the reason is printed), 2 usage error.
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$")
BRANCH_PREFIX = "wip/"


class Refused(Exception):
    pass


def git(repo, *args, check=True):
    proc = subprocess.run(["git", *args], cwd=str(repo), capture_output=True)
    out = proc.stdout.decode("utf-8", "replace").strip()
    if check and proc.returncode != 0:
        raise Refused("git %s: %s" % (" ".join(args), proc.stderr.decode("utf-8", "replace").strip() or out))
    return proc.returncode, out


def main_worktree(repo):
    """Root of the main working tree, also when repo is itself a linked worktree."""
    _, out = git(repo, "worktree", "list", "--porcelain")
    for line in out.splitlines():
        if line.startswith("worktree "):
            return Path(line[len("worktree "):])
    raise Refused("no worktree list from git")


def workspaces_root(main):
    env = os.environ.get("AHF_WORKSPACES_DIR")
    return Path(env) if env else main.parent / (main.name + "-wt")


def worktrees(repo):
    """[(path, branch or None)] of all worktrees."""
    _, out = git(repo, "worktree", "list", "--porcelain")
    found, path, branch = [], None, None
    for line in out.splitlines() + [""]:
        if line.startswith("worktree "):
            path = Path(line[len("worktree "):])
        elif line.startswith("branch "):
            branch = line[len("branch refs/heads/"):]
        elif line == "" and path is not None:
            found.append((path, branch))
            path, branch = None, None
    return found


def same_path(a, b):
    return os.path.normcase(os.path.abspath(str(a))) == os.path.normcase(os.path.abspath(str(b)))


def is_within(inner, outer):
    a, b = os.path.normcase(os.path.abspath(str(inner))), os.path.normcase(os.path.abspath(str(outer)))
    try:
        return os.path.commonpath([a, b]) == b
    except ValueError:          # different drives
        return False


def create(repo, main, root, name, ref):
    if not NAME.match(name):
        raise Refused("name '%s': 1 to 40 characters of A-Z a-z 0-9 . _ - and no leading . _ -" % name)
    branch = BRANCH_PREFIX + name
    path = root / name
    if path.exists():
        raise Refused("%s already exists" % path)
    if git(repo, "rev-parse", "--verify", "--quiet", "refs/heads/" + branch, check=False)[0] == 0:
        raise Refused("branch %s already exists (use another name, or remove the old workspace)" % branch)
    git(repo, "rev-parse", "--verify", ref + "^{commit}")
    root.mkdir(parents=True, exist_ok=True)
    git(repo, "worktree", "add", "-b", branch, str(path), ref)
    print("workspace %s ready" % name)
    print("  branch:   %s (from %s)" % (branch, ref))
    print("  folder:   %s" % path)
    print("  open:     code \"%s\"" % path)
    print("  tests:    python tools/run_suite.py --with-changes   (run it inside the workspace)")
    print("  finished: commit on the branch, then the integrator merges it into the base branch")
    return 0


def describe(main, path, branch, base):
    state = []
    if branch:
        _, counts = git(main, "rev-list", "--left-right", "--count", "%s...%s" % (base, branch), check=False)
        parts = counts.split()
        if len(parts) == 2:
            state.append("+%s/-%s vs %s" % (parts[1], parts[0], base))
    if path.exists():
        _, status = git(path, "status", "--porcelain", check=False)
        state.append("%d changed file(s)" % len(status.splitlines()) if status else "clean")
    else:
        state.append("folder missing (git worktree prune)")
    return ", ".join(state)


def list_workspaces(repo, main, root, base):
    # only the workspaces of this tool: worktrees of other tools (tools/run_suite.py) are not shown
    rows = [(p, b) for p, b in worktrees(repo) if not same_path(p, main) and is_within(p, root)]
    if not rows:
        print("no workspaces (root: %s)" % root)
        return 0
    for path, branch in rows:
        print("%-24s %-28s %s" % (path.name, branch or "(detached)", describe(main, path, branch, base)))
        print("    %s" % path)
    return 0


def remove(repo, main, root, name, force):
    path = root / name
    entry = [(p, b) for p, b in worktrees(repo) if same_path(p, path)]
    if not entry:
        raise Refused("no workspace '%s' below %s" % (name, root))
    branch = entry[0][1]
    if is_within(Path.cwd(), path):
        # Windows cannot delete a folder that is the current folder of a process (also of the calling shell)
        raise Refused("the current folder is inside the workspace %s; change to another folder (for example the "
                      "main checkout %s) and run --remove again" % (name, main))
    if path.exists() and not force:
        _, status = git(path, "status", "--porcelain")
        if status:
            raise Refused("%s has uncommitted changes (commit or stash them, or use --force):\n%s" % (name, status))
    git(main, "worktree", "remove", "--force", str(path))
    git(main, "worktree", "prune", check=False)
    print("worktree %s removed" % path)
    if branch and branch.startswith(BRANCH_PREFIX):
        code, out = git(main, "branch", "-d", branch, check=False)
        if code == 0:
            print("branch %s deleted (it was merged)" % branch)
        else:
            print("branch %s kept: it has commits that are not merged yet" % branch)
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("name", nargs="?", help="workspace name (create)")
    parser.add_argument("--from", dest="ref", default="HEAD", help="start point of the new branch (default HEAD)")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--remove", metavar="NAME")
    parser.add_argument("--force", action="store_true", help="with --remove: also when there are uncommitted changes")
    parser.add_argument("--base", default="v2-port", help="branch the work is merged into (default v2-port)")
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parents[1]))
    args = parser.parse_args(argv)
    try:
        repo = Path(args.repo)
        main_tree = main_worktree(repo)
        root = workspaces_root(main_tree)
        if args.list:
            return list_workspaces(repo, main_tree, root, args.base)
        if args.remove:
            return remove(repo, main_tree, root, args.remove, args.force)
        if args.name:
            return create(repo, main_tree, root, args.name, args.ref)
        parser.print_usage(sys.stderr)
        return 2
    except Refused as e:
        print("refused: %s" % e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
