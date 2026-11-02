"""WI-0135 task 2: every element class of v1 is registered in v2, and every class says on purpose whether it acts on the system.

The v1 side is the class list of tests/data/v1_schema.json (written from the unchanged v1 code, 152 classes; the test does
not read the v1 folder, which goes away after the port). The v2 side is the element files of src/elements/Default/. Class names are compared without case,
because v1 compares them without case, too. The files of src/elements/Default/ that are not element classes (the helpers
of the shared code: *Ops, *Ident, ...) have no `static Mode` and no `ActsOnSystem` and are not counted.
"""

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
V1_SCHEMA = REPO / "tests" / "data" / "v1_schema.json"
V2_FOLDER = REPO / "src" / "elements" / "Default"
KINDS = ("Actions", "Conditions", "Loops", "Triggers")
PREFIX = {"Actions": "Action_", "Conditions": "Condition_", "Loops": "Loop_", "Triggers": "Trigger_"}


def v1_classes():
    data = json.loads(V1_SCHEMA.read_text(encoding="utf-8"))["classes"]
    return {name.split(".", 1)[-1].lower() for name in data}


def v2_element_files():
    """{class name without case: path} of the element classes (a file with `static Mode` or a class name of an element kind)."""
    found = {}
    for kind in KINDS:
        for path in sorted((V2_FOLDER / kind).glob("*.ahk")):
            if path.stem.startswith(PREFIX[kind]):
                found[path.stem.lower()] = path
    return found


def test_the_schema_file_lists_152_v1_classes():
    assert len(v1_classes()) == 152


def test_every_v1_class_is_registered_in_v2_without_regard_to_case():
    missing = sorted(v1_classes() - set(v2_element_files()))
    assert not missing, "v1 classes without a v2 file: %s" % ", ".join(missing)


def test_every_element_class_of_v2_has_a_v1_class_or_is_new_on_purpose():
    """v2 has no element class that v1 does not have (the 152 are the whole set; a new class needs a decision first)."""
    assert set(v2_element_files()) - v1_classes() == set()


def test_every_element_class_sets_acts_on_system_on_purpose():
    """The base class says true, so a class without the line counts as acting (the safe side) by accident. Every class of
    the 152 has the line itself. The list with the reasons is in work_items/phase3/WI-0135-result-s8.md."""
    pattern = re.compile(r"^\s*static\s+ActsOnSystem\s*:=\s*(true|false)\b", re.M)
    without = []
    for name, path in v2_element_files().items():
        if not pattern.search(path.read_text(encoding="utf-8")):
            without.append(name)
    assert not without, "no `static ActsOnSystem` in: %s" % ", ".join(without)


def test_every_element_class_is_named_by_a_test_that_builds_or_runs_flows():
    """REQ-TST-030: a heuristic, not a proof that the class is run. A class that no test file with a flow builder or a flow
    run names at all has no end-to-end test (the file test_element_classes.py, the schema and the help tests do not count)."""
    skip = ("test_element_classes", "test_v1_schema", "test_help")
    texts = []
    for path in (REPO / "tests").rglob("*.py"):
        rel = path.relative_to(REPO).as_posix()
        if rel.startswith("tests/data") or any(name in rel for name in skip):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if re.search(r"FlowBuilder|flows\.run|host_flows|run_all|\.run\(", text):
            texts.append(text.lower())
    unnamed = sorted(name for name in v2_element_files() if not any(name in text for text in texts))
    assert not unnamed, "no test that builds or runs flows names: %s" % ", ".join(unnamed)
