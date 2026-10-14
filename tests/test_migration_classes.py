"""WI-45: the mapping of deviation classes to MIGRATION IDs (src/expr/MigrationClasses.ahk) agrees with the class list of
the golden data (tools/golden_classes.py) and with doc/MIGRATION.md."""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import golden_classes  # noqa: E402

ENTRY = re.compile(r'"([^"]+)",\s*"(accept|rewrite|unsupported|failed)",\s*"(M-\d+)"')
# classes of the mapping that are not classes of the golden data: a text that the converter cannot read at all
EXTRA = {"unreadable text"}


def mapping():
    text = (REPO / "src" / "expr" / "MigrationClasses.ahk").read_text(encoding="utf-8")
    entries = ENTRY.findall(text)
    assert entries, "no entry found in MigrationClasses.ahk"
    return {cls: (handling, mid) for cls, handling, mid in entries}


def test_every_class_of_the_golden_data_has_an_id_and_the_same_handling():
    table = mapping()
    classes = golden_classes.CLASSES
    assert set(table) - EXTRA == set(classes), (sorted(set(classes) - set(table)), sorted(set(table) - set(classes) - EXTRA))
    for cls, (handling, _) in classes.items():
        assert table[cls][0] == handling, cls
    assert {table[c][0] for c in EXTRA} == {"failed"}


def test_every_id_is_an_entry_of_the_migration_document():
    ids = set(re.findall(r"^\| (M-\d+) \|", (REPO / "doc" / "MIGRATION.md").read_text(encoding="utf-8"), re.M))
    for cls, (_, mid) in mapping().items():
        assert mid in ids, "%s: %s is not in doc/MIGRATION.md" % (cls, mid)


def test_a_class_is_listed_once():
    text = (REPO / "src" / "expr" / "MigrationClasses.ahk").read_text(encoding="utf-8")
    names = [m[0] for m in ENTRY.findall(text)]
    assert len(names) == len(set(names))
