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


CLOSED_ITEMS = REPO / "doc" / "CLOSED-ITEMS.md"
HEADING = re.compile(r"^### (F-\d{4}):", re.MULTILINE)
# Numbers up to this one were assigned before the rule of the dense series
# (doc/ORCHESTRATOR.md section 2) and may have gaps. Above it there are none.
DENSE_FROM = 86


def test_finding_ids_above_the_old_series_have_no_gaps_or_duplicates():
    ids = []
    for path in (OPEN_ITEMS, CLOSED_ITEMS):
        ids += HEADING.findall(path.read_text(encoding="utf-8"))
    duplicates = sorted({i for i in ids if ids.count(i) > 1})
    assert not duplicates, "finding IDs used twice: %s" % ", ".join(duplicates)
    numbers = sorted({int(i[2:]) for i in ids if int(i[2:]) >= DENSE_FROM})
    expected = list(range(DENSE_FROM, DENSE_FROM + len(numbers)))
    assert numbers == expected, (
        "finding IDs from F-%04d on have a gap (next free number is the highest plus one, "
        "see doc/ORCHESTRATOR.md section 2): %s" % (DENSE_FROM, numbers)
    )
