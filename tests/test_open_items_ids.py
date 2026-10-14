"""No provisional finding IDs (F-nn*) in doc/OPEN-ITEMS.md on the main checkout.

Agents write provisional IDs with a star and the orchestrator renumbers them
before its commit (doc/ORCHESTRATOR.md section 2). Such an ID left in the main
checkout is an error. In a worktree (an agent's workspace) the check is skipped:
there the provisional IDs are expected.
"""
import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
OPEN_ITEMS = REPO / "doc" / "OPEN-ITEMS.md"
PROVISIONAL = re.compile(r"F-\d+\*")


def _is_workspace():
    # In a git worktree `.git` is a file; in the main checkout it is a directory.
    return not (REPO / ".git").is_dir()


def test_open_items_has_no_provisional_ids():
    if _is_workspace():
        pytest.skip("workspace: provisional IDs are expected here")
    found = []
    for number, line in enumerate(OPEN_ITEMS.read_text(encoding="utf-8").splitlines(), 1):
        for match in PROVISIONAL.finditer(line):
            found.append(f"line {number}: {match.group(0)}")
    assert not found, (
        "provisional finding IDs in doc/OPEN-ITEMS.md (renumber them to final IDs before the commit, "
        "see doc/ORCHESTRATOR.md section 2): " + "; ".join(found)
    )
