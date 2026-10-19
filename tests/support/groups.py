"""Test selection by groups: which tests a change needs (doc/TEST-GROUPS.md). The data is in group_table.py.

select(paths) maps changed paths to a Selection; Selection.accepts(key, func) tells whether a test is part of it.
conftest.py uses this for `--changed-from REF` and `--groups a,b`; tools/verify.py --auto and tools/select_tests.py use
it too. A test that the table does not list is always accepted (a forgotten entry costs time, never a missed test).
"""

import fnmatch
import subprocess
from pathlib import Path

from support.group_table import COVERS, NODE_GROUPS, OWN_TEST_GROUPS, SMOKE_FOR, SOURCE_AREAS, TEST_GROUPS

REPO = Path(__file__).resolve().parents[2]

IGNORED_PREFIXES = ("work_items/", ".claude/", "NEEDS-ATTENTION.md")   # no test reads them
ALWAYS_GROUPS = ("docs", "architecture")        # cheap (about 2 s together), run for every change that tests may read
ELEMENT_SMOKE = "ahk/element_smoke.test.ahk"    # every registered element: runs for every element change
EVERYTHING_AREA = "base-hub"

# Paths outside src/ that name test groups. First match wins. "*" matches a path separator too.
OTHER_RULES = [
    ("tests/support/group_table.py", ["architecture"]),
    ("tests/support/groups.py", ["architecture"]),
    ("tests/ahk/helpers/render_bench.ahk", ["render", "tools"]),   # the renderer bench, driven by tools/measure_render.py
    ("tests/golden/*", ["expr"]),
    ("tests/oracle/*", ["expr"]),
    ("doc/PROTOCOL.md", ["transport", "docs"]),
    ("doc/*", ["docs"]),
    ("tools/ahkrun.py", None),                                  # None: every test runs it
    ("tools/gen_element_includes.py", ["element-units", "architecture"]),
    ("tools/arch_check.py", ["architecture"]),
    ("tools/doc_index.py", ["docs"]),
    ("tools/req_index.py", ["docs"]),
    ("tools/golden_*.py", ["expr"]),
    ("tools/*", ["tools"]),
    (".vscode/*", ["tools"]),
    (".gitattributes", ["architecture"]),
    (".editorconfig", ["architecture"]),
]
ROOT_DOCS = ("AGENTS.md", "README.md", "CLAUDE.md")


class Selection:
    def __init__(self):
        self.everything = False
        self.groups = set()          # test groups that run in full
        self.files = set()           # test files (keys of TEST_GROUPS) that run in full
        self.nodes = set()           # single test functions (`file::function`) that run
        self.smoke_areas = set()     # source areas whose smoke tests run
        self.reasons = []            # (path, text) for the explanation

    def accepts(self, key, func=None):
        """key: test file relative to tests/ (an AHK unit: ahk/<name>.test.ahk); func: the test function name."""
        if self.everything:
            return True
        node = (key + "::" + func) if func else None
        own = NODE_GROUPS.get(node) or TEST_GROUPS.get(key)
        if own is None or key in self.files or node in self.nodes or self.groups.intersection(own):
            return True
        for smoke_key in ((key + "::" + func) if func else None, key):
            if smoke_key and self.smoke_areas.intersection(SMOKE_FOR.get(smoke_key, ())):
                return True
        return False

    def is_empty(self):
        return not (self.everything or self.groups or self.files or self.nodes or self.smoke_areas)


def area_of(path):
    """The source area of a file under src/, or None when no rule matches (the guard test fails on that)."""
    for area, patterns in SOURCE_AREAS:
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns):
            return area
    return None


def smoke_tests(areas):
    return sorted(key for key, values in SMOKE_FOR.items() if set(values) & set(areas))


def _add_source(sel, path):
    area = area_of(path)
    if area is None or area == EVERYTHING_AREA:
        sel.everything = True
        sel.reasons.append((path, "everything" if area else "no source area (everything)"))
    elif area == "element":
        covered = COVERS.get(path) or []
        sel.nodes.update(c for c in covered if "::" in c)
        sel.files.update(c for c in covered if "::" not in c)
        sel.files.add(ELEMENT_SMOKE)
        sel.smoke_areas.add("element")
        if "/Triggers/" in path:
            sel.smoke_areas.add("element-trigger")
        if not covered:
            sel.groups.add("element-units")
        sel.reasons.append((path, "element: %d own tests%s, smoke" % (
            len(covered), "" if covered else " (none: the element units run)")))
    else:
        own = OWN_TEST_GROUPS.get(area, [area])
        sel.groups.update(own)
        sel.smoke_areas.add(area)
        sel.reasons.append((path, "area %s: groups %s, smoke" % (area, ", ".join(own))))


def _add_test_path(sel, path):
    key = path[len("tests/"):]
    if path == "tests/test_ahk_runner.py":
        sel.everything = True
        sel.reasons.append((path, "the runner of all AHK units (everything)"))
    elif key in TEST_GROUPS or key.endswith(".test.ahk") or Path(key).name.startswith("test_"):
        sel.files.add(key)
        sel.reasons.append((path, "the test itself"))
    else:       # the table itself, golden and oracle data have rules; conftest, support, helpers, test data and AHK
        _add_other(sel, path)       # libraries may be read by any test, so they select everything


def _add_other(sel, path):
    for pattern, groups in OTHER_RULES:
        if fnmatch.fnmatchcase(path, pattern):
            if groups is None:
                sel.everything = True
                sel.reasons.append((path, "everything"))
            else:
                sel.groups.update(groups)
                sel.reasons.append((path, "groups %s" % ", ".join(groups)))
            return
    if "/" not in path and path in ROOT_DOCS:
        sel.reasons.append((path, "documentation"))
        return
    sel.everything = True
    sel.reasons.append((path, "no rule: any test may read it (everything)"))


def select(paths):
    """The Selection for a list of changed paths (repo-relative, forward slashes)."""
    sel = Selection()
    relevant = [p for p in paths if not p.startswith(IGNORED_PREFIXES)]
    for path in relevant:
        if path.startswith("src/"):
            _add_source(sel, path)
        elif path.startswith("tests/"):
            _add_test_path(sel, path)
        else:
            _add_other(sel, path)
    if relevant:
        sel.groups.update(ALWAYS_GROUPS)
    return sel


def select_groups(names):
    """A Selection of explicitly named test groups (for --groups)."""
    sel = Selection()
    sel.groups.update(names)
    return sel


def changed_paths(ref, repo=REPO):
    """Files that differ from ref in the working tree of repo (committed, staged, unstaged and untracked)."""
    def run(*args):
        proc = subprocess.run(["git", *args], cwd=str(repo), capture_output=True)
        if proc.returncode != 0:
            raise RuntimeError("git %s failed: %s" % (" ".join(args), proc.stderr.decode("utf-8", "replace").strip()))
        return proc.stdout.decode("utf-8", "replace").splitlines()
    paths = run("diff", "--name-only", "--no-renames", ref)
    paths += run("ls-files", "--others", "--exclude-standard")
    return sorted({p for p in paths if p})


def test_key(rel_path, ahk_file=None):
    """The table key of a collected test: the AHK unit for the items of the runner, the file otherwise."""
    if ahk_file is not None:
        return "ahk/" + Path(str(ahk_file)).name
    return rel_path


def describe(sel):
    """Text lines that explain a Selection (used by tools/select_tests.py)."""
    lines = []
    for path, text in sel.reasons:
        lines.append("  %-60s %s" % (path, text))
    if sel.everything:
        lines.append("=> everything")
    else:
        lines.append("=> test groups: %s" % (", ".join(sorted(sel.groups)) or "-"))
        if sel.files:
            lines.append("=> test files: %s" % ", ".join(sorted(sel.files)))
        if sel.nodes:
            lines.append("=> test functions: %d" % len(sel.nodes))
        if sel.smoke_areas:
            lines.append("=> smoke tests for: %s" % ", ".join(sorted(sel.smoke_areas)))
            for key in smoke_tests(sel.smoke_areas):
                lines.append("     " + key)
    return lines
