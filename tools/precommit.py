#!/usr/bin/env python
"""Pre-commit hook: regenerates the generated indexes and adds them to the commit.

The line ranges in doc/DOC-INDEX.md and doc/REQUIREMENTS-INDEX.md move with every change of the documents they
list, and a fast-tier test fails when an index is outdated. This hook runs tools/doc_index.py before every commit
and adds the indexes to the commit when they changed, so nobody has to remember it.

Install once per clone (the setting is shared by all worktrees; the path is relative to each worktree, so a
workspace uses the hook of its own branch):

    git config core.hooksPath tools/hooks          (VS Code task "Setup: git hooks (core.hooksPath)")

What it does, by case:
  * normal commit and `git commit -a`: regenerate; add an index that changed.
  * an input document (or an index) has unstaged changes: the regenerated index would describe the working tree,
    not the commit, so nothing is written; a note says to run python tools/doc_index.py.
  * a partial commit (`git commit --only <paths>` / `git commit <paths>`, used by the orchestrator for its own
    files): nothing is written, because the working tree must not change behind the commit; only a note when an
    index is outdated.

The hook never blocks a commit (exit 0 always; a failing requirement check is printed as a warning, the fast tier
reports it). Bypass: `git commit --no-verify`.
Not covered: rebase and cherry-pick do not run pre-commit hooks; after a rebase run python tools/doc_index.py.
"""

import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import doc_index  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
INDEXES = ("doc/DOC-INDEX.md", "doc/REQUIREMENTS-INDEX.md")


def git(repo, *args):
    return subprocess.run(["git", *args], cwd=str(repo), capture_output=True, text=True, check=True).stdout


def index_inputs(repo):
    """The documents whose content the indexes describe, as repository paths."""
    inputs = set(doc_index.HEADING_DOCS) | {"doc/REQUIREMENTS.md"}
    inputs |= {p.relative_to(repo).as_posix() for p in (repo / doc_index.HOWTO_DIR).glob("*.md")}
    return inputs


def regenerate(repo, check):
    return doc_index.run(check=check, source=repo / "doc" / "REQUIREMENTS.md",
                         index=repo / "doc" / "REQUIREMENTS-INDEX.md", repo=repo, out=_Quiet())


class _Quiet:
    """Collects the tool's output; the hook prints only what matters."""
    def __init__(self):
        self.lines = []

    def write(self, text):
        self.lines.append(text)

    def flush(self):
        pass


def is_partial_commit():
    # git commit --only / git commit <paths> runs the hook on a temporary index named next-index-<pid>.lock
    return os.path.basename(os.environ.get("GIT_INDEX_FILE", "")).startswith("next-index")


def run(repo=REPO, regen=regenerate, partial=None, out=None):
    out = out or sys.stdout
    if partial is None:
        partial = is_partial_commit()
    if not git(repo, "diff", "--cached", "--name-only").strip():
        return 0
    if partial:
        if regen(repo, True) != 0:
            print("pre-commit: an index is outdated or a requirement check fails; "
                  "run python tools/doc_index.py and commit the indexes", file=out)
        return 0
    # untracked documents count too: a new how-to entry that is not part of the commit would be listed in the index
    unstaged = set(git(repo, "diff", "--name-only").split()) | set(
        git(repo, "ls-files", "--others", "--exclude-standard").split())
    dirty = sorted(unstaged & (index_inputs(repo) | set(INDEXES)))
    if dirty:
        if regen(repo, True) != 0:
            print("pre-commit: indexes not regenerated, unstaged changes in %s; "
                  "run python tools/doc_index.py when they are staged" % ", ".join(dirty), file=out)
        return 0
    before = {p: (repo / p).read_bytes() if (repo / p).exists() else None for p in INDEXES}
    code = regen(repo, False)
    changed = [p for p in INDEXES if ((repo / p).read_bytes() if (repo / p).exists() else None) != before[p]]
    if changed:
        git(repo, "add", "--", *changed)
        print("pre-commit: regenerated and added %s" % ", ".join(changed), file=out)
    if code != 0:
        print("pre-commit: warning: python tools/doc_index.py --check fails (see its output); "
              "the commit goes on", file=out)
    return 0


def main():
    try:
        return run()
    except Exception as error:  # never block a commit because of the hook itself
        print("pre-commit: index hook skipped (%s)" % error, file=sys.stderr)
        return 0


if __name__ == "__main__":
    sys.exit(main())
