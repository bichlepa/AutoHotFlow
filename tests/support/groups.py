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

# Paths outside src/ that name test groups. First match wins (put the specific patterns first). "*" matches a path
# separator too. A group list of None means: every test may depend on the path (explicit everything, commented);
# an empty list means: no test reads it. A path that matches no rule is an error (UnknownPathError), never a full run.
# The groups of a helper or a data file are the groups of the tests that read it (grep the tests before you change one).
FAULT_GROUPS = ["diagnosis", "engine", "expr", "manager", "recovery", "settings", "storage", "supervisor", "transport",
                "tray", "triggers", "variables", "workers"]     # the union of the fault tests (faultkit is used by most)
ROLE_TESTS = ["diagnosis", "recovery", "storage", "supervisor", "transport", "workers"]   # the test roles (entry/test/)
EXECUTOR_KIT_USERS = ["engine", "element-units", "triggers", "variables", "expr"]   # the users of ExecutorKit/EngineOwner
OTHER_RULES = [
    # tests/: shared infrastructure (explicit everything), helpers and data (the tests that read them)
    ("tests/support/group_table.py", ["architecture"]),
    ("tests/support/groups.py", ["architecture"]),
    ("tests/golden/*", ["expr"]),                        # the golden data of the expression language (frozen)
    ("tests/oracle/*", ["expr"]),                        # the oracle corpus and harness of the expression language
    ("tests/conftest.py", None),                         # fixtures, options and the run record of every test
    ("tests/support/*", None),                           # process kit, admission, history, dialogs: any test may use them
    ("tests/requirements.txt", None),                    # pinned test dependencies: a new version may break any test
    ("tests/ahk/lib/Assert.ahk", None),                  # the assertions of every AHK unit test
    ("tests/ahk/lib/ElementSmoke.ahk", ["element-units"]),
    ("tests/ahk/lib/EvalCheck.ahk", ["expr"]),
    ("tests/ahk/lib/ExprCheck.ahk", ["expr"]),
    ("tests/ahk/lib/ExprDump.ahk", ["expr"]),
    ("tests/ahk/lib/ExprTestResolver.ahk", ["expr"]),
    ("tests/ahk/helpers/ExecutorKit.ahk", EXECUTOR_KIT_USERS),
    ("tests/ahk/helpers/EngineOwner.ahk", EXECUTOR_KIT_USERS),
    ("tests/ahk/helpers/render_bench.ahk", ["render", "tools"]),   # the renderer bench, driven by tools/measure_render.py
    ("assets/icons/*", ["render"]),                                # the icons of the editor drawing (WI-0085)
    ("assets/help/*", ["help"]),                                   # the general help pages and their stylesheet (WI-0112)
    ("tests/ahk/helpers/renderer_bench.ahk", ["render", "tools"]),   # the renderer measurement (VS Code task, WI-0085)
    ("tests/ahk/helpers/render_samples.ahk", ["render", "tools"]),   # the editor screenshots (VS Code task, WI-0085)
    ("tests/ahk/helpers/element_rate_bench.ahk", ["element-units", "engine"]),   # benches: run by hand (VS Code tasks)
    ("tests/ahk/helpers/loop_bench.ahk", ["element-units", "engine"]),
    ("tests/ahk/helpers/flow_patch_bench.ahk", ["engine"]),   # the patch cost (WI-0093, MS-0051), run by hand
    ("tests/ahk/helpers/evalparams_bench.ahk", ["element-units", "expr"]),
    ("tests/ahk/helpers/expr_bench.ahk", ["expr"]),
    ("tests/ahk/helpers/assist_gui_probe.ahk", ["editor-assist"]),   # the gui probe of the window assistant (WI-0110, owner)
    ("tests/ahk/helpers/expr_eval_bench.ahk", ["expr"]),
    ("tests/ahk/helpers/json_bench.ahk", ["base"]),      # used by tests/test_json_flows.py
    ("tests/ahk/helpers/json_flows.ahk", ["base"]),
    ("tests/ahk/helpers/hub_frame_cost.ahk", ["transport"]),     # used by the stress tests (not selected)
    ("tests/ahk/helpers/modal_spike.ahk", ["ui"]),
    ("tests/ahk/helpers/tray_menu_probe.ahk", ["tray"]),
    ("tests/ahk/helpers/ui_dialog_text.ahk", ["manager", "ui"]),  # used by tests/fault/test_manager_window.py
    ("tests/integration/helpers/AutoHotFlowTest.ahk", None),      # the test entry of every role
    ("tests/integration/helpers/entry/generated/*", ["element-units"]),
    ("tests/integration/helpers/entry/test/*", ROLE_TESTS),       # echo, crasher, hanger, slow_shutdown
    ("tests/integration/helpers/entry/debug.ahk", ["diagnosis"]),
    ("tests/integration/helpers/entry/editor.ahk", ["editor"]),
    ("tests/integration/helpers/entry/engine.ahk", ["engine"]),
    ("tests/integration/helpers/entry/help.ahk", ["help"]),
    ("tests/integration/helpers/entry/manager.ahk", ["manager"]),
    ("tests/integration/helpers/entry/storage.ahk", ["storage"]),
    ("tests/integration/helpers/entry/tray.ahk", ["tray"]),
    ("tests/integration/helpers/entry/triggerhost.ahk", ["triggers"]),
    ("tests/integration/helpers/entry/worker.ahk", ["workers"]),
    ("tests/integration/helpers/CrasherRole.ahk", ["diagnosis", "storage", "supervisor", "workers"]),
    ("tests/integration/helpers/HangerRole.ahk", ["diagnosis", "storage", "supervisor", "workers"]),
    ("tests/integration/helpers/SlowShutdownRole.ahk", ["recovery", "supervisor"]),
    ("tests/integration/helpers/EchoRole.ahk", ["diagnosis", "recovery", "storage", "supervisor", "transport"]),
    ("tests/integration/helpers/RegisterFailure.ahk", ["supervisor"]),
    ("tests/integration/helpers/IconProbe.ahk", ["supervisor", "tray"]),
    ("tests/integration/helpers/IconProbeShown.ahk", ["supervisor", "tray"]),
    ("tests/integration/helpers/PipeTestKit.ahk", ["transport"]),
    ("tests/integration/helpers/peer_probe.ahk", ["transport"]),
    ("tests/integration/helpers/pipe_client.ahk", ["transport"]),
    ("tests/integration/helpers/pipe_echo_server.ahk", ["transport"]),
    ("tests/integration/helpers/rawpipe.py", ["transport"]),
    ("tests/integration/helpers/TestDialogProvider.ahk", ["element-units", "elements-e2e", "engine", "ui", "workers"]),
    ("tests/integration/helpers/hotkey_window.ahk", ["triggers"]),
    ("tests/integration/helpers/key_observer.ahk", ["triggers"]),
    ("tests/fault/faultkit.py", FAULT_GROUPS),
    ("tests/fault/faultfixtures.py", FAULT_GROUPS),
    ("tests/stress/stresskit.py", []),                   # read by the stress tests only, which the selection never runs
    ("tests/elements/TestTwin/*", ["element-units", "packages"]),
    ("tests/elements/Test/*", ["element-units", "elements-e2e", "engine", "expr", "packages", "triggers", "ui", "workers"]),
    ("tests/data/README.md", ["docs"]),
    ("tests/data/skeleton_flow.json", ["engine", "manager", "recovery", "storage", "tools", "triggers"]),
    ("tests/data/flows/v1_examples/*", ["base", "elements-e2e", "engine", "expr", "manager", "storage"]),
    ("tests/data/flows/personal/*", ["base", "storage"]),
    ("tests/data/flows/s1_acceptance/*", ["engine"]),
    ("tests/data/flows/v2_adapted/*", ["engine", "expr"]),
    ("tests/data/ahf/*", ["manager", "storage"]),
    ("tests/data/variables/*", ["engine", "storage", "variables"]),
    ("tests/data/manual/*", ["elements-e2e", "manager", "storage", "tools", "ui"]),
    # doc/, tools/, root and the language texts of the program
    ("doc/PROTOCOL.md", ["transport", "docs"]),
    ("doc/*", ["docs"]),
    ("tools/ahkrun.py", None),                                  # every test runs it
    ("tools/gen_element_includes.py", ["element-units", "architecture"]),
    ("tools/gen_help.py", ["help", "tools"]),                    # the HTML of the help pages (WI-0112)
    ("tools/convert_v1_help.py", ["tools"]),                     # one-time conversion of the v1 help (WI-0112)
    ("tools/arch_check.py", ["architecture"]),
    ("tools/doc_index.py", ["docs"]),
    ("tools/req_index.py", ["docs"]),
    ("tools/golden_*.py", ["expr"]),
    ("tools/*", ["tools"]),
    (".vscode/*", ["tools"]),
    (".gitignore", ["tools"]),                                  # run_suite copies the files that are not ignored
    (".gitattributes", ["architecture"]),
    (".editorconfig", ["architecture"]),
    ("pytest.ini", None),                                       # the options of every run
    ("assets/language/*", ["lang", "manager", "settings", "tray", "ui"]),   # the texts the dialogs and the tray show
    # v1/: the reference code, changed never (AGENTS.md rule 4); only the golden data and the element smoke test read it
    ("v1/Source_Elements/*", ["element-units", "lang"]),         # ElementSmoke, core_lang
    ("v1/AutoHotKey/*", ["expr", "tools"]),                     # the v1 interpreter of the golden data
    ("v1/*", []),
]
ROOT_DOCS = ("AGENTS.md", "README.md", "CLAUDE.md")


class UnknownPathError(ValueError):
    """A changed path that no rule classifies. The selection refuses to guess: a run of everything would hide the gap
    and a silent skip would hide the missing test (doc/TEST-GROUPS.md, section 6)."""

    def __init__(self, path):
        super().__init__(
            "%s is not classified by any test rule. Add a rule: a source file needs an area in SOURCE_AREAS, a test "
            "file an entry in TEST_GROUPS (tests/support/group_table.py); any other path needs a rule in OTHER_RULES "
            "(tests/support/groups.py) with the groups of the tests that read it, None when every test may depend on "
            "it, or [] when no test reads it. See doc/TEST-GROUPS.md, section 6." % path)
        self.path = path


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


def _unknown(sel, path, removed):
    """A path without a rule. A path that the ref deleted has nothing left to classify: no test can read it through its
    own rule, but a deletion can break any test, so it selects everything. Any other unknown path is an error."""
    if path not in removed:
        raise UnknownPathError(path)
    sel.everything = True
    sel.reasons.append((path, "deleted and no rule: everything"))


def _add_source(sel, path, removed=()):
    area = area_of(path)
    if area is None:
        _unknown(sel, path, removed)
        return
    if area == EVERYTHING_AREA:
        sel.everything = True
        sel.reasons.append((path, "base-hub: everything"))
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


def is_test_file(path):
    key = path[len("tests/"):]
    return key in TEST_GROUPS or key.endswith(".test.ahk") or Path(key).name.startswith("test_")


def _add_test_path(sel, path, removed=()):
    key = path[len("tests/"):]
    if path == "tests/test_ahk_runner.py":
        sel.everything = True
        sel.reasons.append((path, "the runner of all AHK units (everything)"))
    elif is_test_file(path):
        sel.files.add(key)
        sel.reasons.append((path, "the test itself"))
    else:       # helpers, data, support and AHK libraries: OTHER_RULES says which tests read them
        _add_other(sel, path, removed)


def other_rule(path):
    """(pattern, groups) of the OTHER_RULES entry that classifies a path outside src/, ("documentation", []) for a
    root document, or None when no rule knows the path."""
    for pattern, rule_groups in OTHER_RULES:
        if fnmatch.fnmatchcase(path, pattern):
            return pattern, rule_groups
    if "/" not in path and path in ROOT_DOCS:
        return "documentation", []
    return None


def _add_other(sel, path, removed=()):
    rule = other_rule(path)
    if rule is None:
        _unknown(sel, path, removed)
        return
    pattern, rule_groups = rule
    if rule_groups is None:
        sel.everything = True
        sel.reasons.append((path, "everything (%s)" % pattern))
    else:
        sel.groups.update(rule_groups)
        sel.reasons.append((path, "groups %s (%s)" % (", ".join(rule_groups) or "none", pattern)))


def classified(path):
    """True when a rule knows the path (ignored paths count as known: no test reads them). tests/test_groups.py checks
    every tracked file with it, so a new file cannot be selected silently."""
    if path.startswith(IGNORED_PREFIXES):
        return True
    if path.startswith("src/"):
        return area_of(path) is not None
    if path.startswith("tests/") and (path == "tests/test_ahk_runner.py" or is_test_file(path)):
        return True
    return other_rule(path) is not None


def select(paths, removed=()):
    """The Selection for a list of changed paths (repo-relative, forward slashes). removed: the paths that the change
    deletes (removed_paths); a deleted path needs no rule of its own (see _unknown)."""
    sel = Selection()
    removed = set(removed)
    relevant = [p for p in paths if not p.startswith(IGNORED_PREFIXES)]
    for path in relevant:
        if path.startswith("src/"):
            _add_source(sel, path, removed)
        elif path.startswith("tests/"):
            _add_test_path(sel, path, removed)
        else:
            _add_other(sel, path, removed)
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


def removed_paths(ref, repo=REPO, base=None):
    """Files that the change deletes: deleted in the working tree against ref (base None), or between base and ref.
    A rename shows as a deletion of the old path (changed_paths uses --no-renames)."""
    args = ["diff", "--name-only", "--diff-filter=D", "--no-renames"]
    args += [base + ".." + ref] if base else [ref]
    proc = subprocess.run(["git", *args], cwd=str(repo), capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError("git %s failed: %s" % (" ".join(args), proc.stderr.decode("utf-8", "replace").strip()))
    return sorted({p for p in proc.stdout.decode("utf-8", "replace").splitlines() if p})


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
