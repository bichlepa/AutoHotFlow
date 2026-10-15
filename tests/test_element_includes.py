"""WI-0047-PREP (E0041): the element classes of each role are selected by the literal Mode of the class file.

Checks, without a role process: the generated blocks are up to date, each block holds exactly the classes of its
row of the table (the expectation here is computed independently of the generator), the generator stops on a class
file without a literal Mode, every role entry includes only the shared boot code, its own role and its own block,
and a block really registers only the classes of its modes when AutoHotkey runs it.
"""

import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import gen_element_includes as gen  # noqa: E402

ELEMENTS = ROOT / "src" / "elements"
ENTRY_DIR = ROOT / "src" / "entry"
TEST_ENTRY_DIR = ROOT / "tests" / "integration" / "helpers" / "entry"

# The table of E0041 / WI-0047-PREP, written out once more here on purpose.
TABLE = {
    "supervisor": None, "storage": None, "debug": None, "manager": None,
    "engine": {"inline", "worker", "trigger"},
    "triggerhost": {"trigger"},
    "worker": {"worker"},
    "editor": {"inline", "worker", "trigger"},
}


def product_classes():
    """{class name: mode}: the element files of src/elements outside base/ that are not test classes."""
    found = {}
    for path in ELEMENTS.rglob("*.ahk"):
        if "base" in path.relative_to(ELEMENTS).parts[:-1] or path.name.lower().startswith("action_test"):
            continue
        m = re.search(r'^\s*static\s+Mode\s*:=\s*"(\w+)"', path.read_text(encoding="utf-8"), re.M)
        assert m, path
        found[path.stem] = m.group(1)
    return found


def block_classes(path):
    return sorted(Path(m.group(1).replace("\\", "/")).stem
                  for m in re.finditer(r"^#Include\s+(.+?)\s*$", Path(path).read_text(encoding="utf-8"), re.M))


# --- the generator --------------------------------------------------------------------------------------------

def test_role_table_is_the_one_of_the_decision():
    assert {r: set(m) for r, m in gen.ROLE_MODES.items()} == {r: m for r, m in TABLE.items() if m}


def test_generated_blocks_are_up_to_date():
    assert gen.main(["--check"]) == 0, "run: python tools/gen_element_includes.py"


@pytest.mark.parametrize("role", [r for r, m in TABLE.items() if m])
def test_each_product_block_holds_exactly_the_classes_of_its_modes(role):
    expected = sorted(name for name, mode in product_classes().items() if mode in TABLE[role])
    assert block_classes(ENTRY_DIR / "generated" / ("Elements_%s.ahk" % role)) == expected


@pytest.mark.parametrize("role", [r for r, m in TABLE.items() if not m])
def test_roles_without_classes_have_no_block(role):
    assert not (ENTRY_DIR / "generated" / ("Elements_%s.ahk" % role)).exists()
    assert not (TEST_ENTRY_DIR / "generated" / ("TestElements_%s.ahk" % role)).exists()


def test_the_product_blocks_hold_no_test_class_and_the_test_blocks_only_test_classes():
    for role in (r for r, m in TABLE.items() if m):
        for name in block_classes(ENTRY_DIR / "generated" / ("Elements_%s.ahk" % role)):
            assert not name.lower().startswith("action_test"), (role, name)
        for name in block_classes(TEST_ENTRY_DIR / "generated" / ("TestElements_%s.ahk" % role)):
            assert name.lower().startswith("action_test"), (role, name)


def test_the_trigger_and_worker_blocks_hold_only_their_own_mode():
    # product: every class of the trigger block is a trigger, of the worker block a worker
    modes = product_classes()
    assert all(modes[n] == "trigger" for n in block_classes(ENTRY_DIR / "generated" / "Elements_triggerhost.ahk"))
    assert all(modes[n] == "worker" for n in block_classes(ENTRY_DIR / "generated" / "Elements_worker.ahk"))


@pytest.fixture
def small_tree(tmp_path, monkeypatch):
    """A tiny element tree for the generator, so that the failure cases can be created."""
    base = tmp_path / "elements"
    (base / "base").mkdir(parents=True)
    (base / "base" / "AhfElement.ahk").write_text('class AhfElement {\n    static Mode := "inline"\n}\n')
    (base / "Action_A.ahk").write_text('class Action_A {\n    static Mode := "inline"\n}\n')
    monkeypatch.setattr(gen, "PRODUCT_DIR", base)
    monkeypatch.setattr(gen, "PRODUCT_OUT", tmp_path / "out")
    monkeypatch.setattr(gen, "TEST_DIRS", (tmp_path / "none",))
    monkeypatch.setattr(gen, "TEST_OUT", tmp_path / "testout")
    return base


def test_generator_works_on_a_small_tree(small_tree, tmp_path):
    assert gen.main([]) == 0
    assert block_classes(tmp_path / "out" / "Elements_engine.ahk") == ["Action_A"]
    assert block_classes(tmp_path / "out" / "Elements_worker.ahk") == []


@pytest.mark.parametrize("text, message", [
    ("class Action_B {\n}\n", "no `static Mode"),
    ("class Action_B {\n    static Mode := Action_A.Mode\n}\n", "not a literal"),
    ('class Action_B {\n    static Mode := "inline" . ""\n}\n', "not a literal"),
    ('class Action_B {\n    static Mode := "remote"\n}\n', "not one of"),
    ('class Action_B {\n    static Mode := "inline"\n    static Mode := "worker"\n}\n', "more than one"),
])
def test_generator_fails_on_a_class_without_a_literal_mode_and_names_the_file(small_tree, capsys, text, message):
    (small_tree / "Action_B.ahk").write_text(text)
    assert gen.main([]) == 1
    err = capsys.readouterr().err
    assert "Action_B.ahk" in err and message in err, err


def test_a_mode_in_a_comment_does_not_count(small_tree, capsys):
    (small_tree / "Action_B.ahk").write_text('; static Mode := "worker"\nclass Action_B {\n}\n')
    assert gen.main([]) == 1
    assert "Action_B.ahk" in capsys.readouterr().err


def test_generator_refuses_a_class_file_that_includes_a_class_file(small_tree, capsys):
    # F-0398: the include runs the Register line of the included class in every role that holds this file
    (small_tree / "Action_B.ahk").write_text('#Include Action_A.ahk\nclass Action_B {\n    static Mode := "worker"\n}\n')
    assert gen.main([]) == 1
    err = capsys.readouterr().err
    assert "Action_B.ahk" in err and "Action_A.ahk" in err, err


def test_generator_allows_an_include_of_base_code(small_tree):
    # base/ holds shared code without element classes; the generator does not look into it for Mode lines
    (small_tree / "Action_B.ahk").write_text(
        '#Include base\\AhfElement.ahk  ; comment\nclass Action_B {\n    static Mode := "worker"\n}\n')
    assert gen.main([]) == 0


# --- the entry scripts ----------------------------------------------------------------------------------------

ROLE_FILE = {"storage": r"storage\Storage.ahk", "engine": r"engine\Engine.ahk", "worker": r"worker\Worker.ahk",
             "manager": r"manager\StubManager.ahk", "debug": r"debugview\DebugView.ahk",
             "triggerhost": r"core\PlaceholderRole.ahk", "editor": r"core\PlaceholderRole.ahk"}


def includes_of(path):
    return [m.group(1) for m in re.finditer(r"^#Include\s+(.+?)\s*$", Path(path).read_text(encoding="utf-8"), re.M)]


@pytest.mark.parametrize("role", sorted(ROLE_FILE))
def test_a_role_entry_includes_only_the_boot_code_its_role_and_its_block(role):
    expected = [r"..\AhfBoot.ahk", "..\\" + ROLE_FILE[role]]
    if TABLE[role]:
        expected.append(r"generated\Elements_%s.ahk" % role)
    assert includes_of(ENTRY_DIR / (role + ".ahk")) == expected
    text = (ENTRY_DIR / (role + ".ahk")).read_text(encoding="utf-8")
    assert re.findall(r'RoleRegistry\.Register\("(\w+)"', text) == [role]


def test_there_is_an_entry_for_every_role_and_no_other():
    assert sorted(p.stem for p in ENTRY_DIR.glob("*.ahk")) == sorted(ROLE_FILE)


def test_the_supervisor_entry_has_no_element_class_and_no_other_role():
    assert includes_of(ROOT / "src" / "AutoHotFlow.ahk") == ["AhfBoot.ahk", r"supervisor\Supervisor.ahk"]
    assert includes_of(ROOT / "src" / "AhfBoot.ahk") == [r"core\RoleRegistry.ahk"]


@pytest.mark.parametrize("role", sorted(ROLE_FILE))
def test_a_test_role_entry_adds_only_the_test_block_of_its_role(role):
    expected = [r"..\..\..\..\src\AhfBoot.ahk", "..\\..\\..\\..\\src\\" + ROLE_FILE[role]]
    if TABLE[role]:
        expected += [r"..\..\..\..\src\entry\generated\Elements_%s.ahk" % role,
                     r"generated\TestElements_%s.ahk" % role]
    assert includes_of(TEST_ENTRY_DIR / (role + ".ahk")) == expected


# --- what a block registers when AutoHotkey runs it ---------------------------------------------------------

PROBE = """#Requires AutoHotkey v2.0
#Include {registry}
#Include {block}
ids := ""
for cls in ElementRegistry.All()
    ids .= ElementRegistry.IdOf(cls) ":" cls.Mode "`n"
FileAppend(ids, "*", "UTF-8-RAW")
"""


def expected_test_classes():
    """{class name: mode} of the test elements: Action_Test* files outside base/ in src/elements and tests/elements."""
    found = {}
    for folder in (ELEMENTS, ROOT / "tests" / "elements"):
        for path in folder.rglob("*.ahk"):
            if "base" in path.relative_to(folder).parts[:-1] or not path.name.lower().startswith("action_test"):
                continue
            m = re.search(r'^\s*static\s+Mode\s*:=\s*"(\w+)"', path.read_text(encoding="utf-8"), re.M)
            assert m, path
            found[path.stem] = m.group(1)
    return found


@pytest.mark.parametrize("role", [r for r, m in TABLE.items() if m])
def test_a_test_block_registers_only_the_test_classes_of_its_modes(role, datadir, run_ahk):
    # F-0398: the text check of the blocks does not see a class that comes in through an include, this probe does
    script = datadir / "probe_test.ahk"
    script.write_text(PROBE.format(registry=ELEMENTS / "base" / "ElementRegistry.ahk",
                                   block=TEST_ENTRY_DIR / "generated" / ("TestElements_%s.ahk" % role)),
                      encoding="utf-8")
    res = run_ahk(script)
    assert res.returncode == 0, res.stderr
    got = sorted(line for line in res.stdout.splitlines() if line)
    expected = sorted("%s:%s" % (n, m) for n, m in expected_test_classes().items() if m in TABLE[role])
    assert got == expected


@pytest.mark.parametrize("role", [r for r, m in TABLE.items() if m])
def test_a_block_registers_only_the_classes_of_its_modes(role, datadir, run_ahk):
    script = datadir / "probe.ahk"
    script.write_text(PROBE.format(registry=ELEMENTS / "base" / "ElementRegistry.ahk",
                                   block=ENTRY_DIR / "generated" / ("Elements_%s.ahk" % role)), encoding="utf-8")
    res = run_ahk(script)
    assert res.returncode == 0, res.stderr
    got = sorted(line for line in res.stdout.splitlines() if line)
    expected = sorted("%s:%s" % (n, m) for n, m in product_classes().items() if m in TABLE[role])
    assert got == expected
