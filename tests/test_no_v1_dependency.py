"""The v1 folder is a temporary reference and is removed after the port (AGENTS.md). Nothing that runs may depend on it.

Tests read their data from tests/data (flows, variables) and create everything else in a fresh temporary directory.
Exception: tests/golden generates reference data with the v1 interpreter (work_items/phase3/WI-36); its results are
checked in, so the normal test run does not need v1 either.
"""

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# a path into the v1 tree: v1/..., v1\..., "v1" / "..." (pathlib) or ..\v1\...
V1_PATH = re.compile(r'''(?:^|[\s"'\\/(=])v1[\\/]|["']v1["']\s*/''')

SCANNED = [("src", "*.ahk"), ("tests", "*.py"), ("tests", "*.ahk"), ("tools", "*.py"), ("tools", "*.ahk")]
EXEMPT_PREFIXES = ("tests/golden/",)
# the two tools of the golden data read v1 on purpose (WI-36); their results are checked in
EXEMPT_FILES = {"tests/test_no_v1_dependency.py", "tools/golden_v1.py", "tools/golden_corpus.py"}


def is_comment(line):
    stripped = line.strip()
    return stripped.startswith((";", "#", "//", "*", '"""'))


def test_no_code_or_test_reads_the_v1_folder():
    hits = []
    for folder, pattern in SCANNED:
        for path in sorted((REPO / folder).rglob(pattern)):
            rel = path.relative_to(REPO).as_posix()
            if rel in EXEMPT_FILES or rel.startswith(EXEMPT_PREFIXES) or "__pycache__" in rel:
                continue
            for number, line in enumerate(path.read_text(encoding="utf-8-sig", errors="replace").splitlines(), 1):
                if V1_PATH.search(line) and not is_comment(line):
                    hits.append("%s:%d: %s" % (rel, number, line.strip()[:120]))
    assert not hits, "dependency on the v1 folder (use tests/data instead):\n" + "\n".join(hits)


def test_example_data_is_present():
    flows = list((REPO / "tests" / "data" / "flows" / "v1_examples").glob("Flow *.json"))
    assert len(flows) >= 20, "example flows missing in tests/data/flows/v1_examples"
    assert list((REPO / "tests" / "data" / "variables").rglob("*.ahfvar")), "synthetic variables missing"
