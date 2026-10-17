"""WI-0047-PREP (E0041) and WI-0047 (E0037, E0045): the element classes of each role, per package.

Checks, without a role process: the generated blocks are up to date, a stale or superfluous block fails the check,
each block holds exactly the classes of its row of the table (the expectation here is computed independently of the
generator), the generator stops on a class file or a package it cannot use, every role entry includes only the shared
boot code, its own role and its own block, and a block really registers only the classes of its modes, under their
qualified IDs, when AutoHotkey runs it. Two packages with a class of the same name load in one process.
"""

import json
import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import gen_element_includes as gen  # noqa: E402

ELEMENTS = ROOT / "src" / "elements"
TEST_ELEMENTS = ROOT / "tests" / "elements"
ENTRY_DIR = ROOT / "src" / "entry"
TEST_ENTRY_DIR = ROOT / "tests" / "integration" / "helpers" / "entry"
KINDS = {"Actions": "Action_", "Conditions": "Condition_", "Loops": "Loop_", "Triggers": "Trigger_"}

# The table of E0041 / WI-0047-PREP, written out once more here on purpose.
TABLE = {
    "supervisor": None, "storage": None, "debug": None, "manager": None, "tray": None,
    "engine": {"inline", "worker", "trigger"},
    "triggerhost": {"trigger"},
    "worker": {"worker"},
    "editor": {"inline", "worker", "trigger"},
}
ROLES_WITH_BLOCK = [r for r, m in TABLE.items() if m]


def classes_below(folder):
    """{qualified ID: mode} of the element files of the packages below `folder`: <package>/<kind>/<class>.ahk."""
    found = {}
    for desc in Path(folder).glob("*/package.json"):
        package = json.loads(desc.read_text(encoding="utf-8"))["name"]
        for kind in KINDS:
            for path in (desc.parent / kind).glob("*.ahk"):
                m = re.search(r'^\s*static\s+Mode\s*:=\s*"(\w+)"', path.read_text(encoding="utf-8"), re.M)
                assert m, path
                found["%s.%s" % (package, path.stem)] = m.group(1)
    return found


def product_classes():
    return classes_below(ELEMENTS)


def classes_of_the_test_set():
    return classes_below(TEST_ELEMENTS)


def includes_of(path):
    return [m.group(1) for m in re.finditer(r"^\s*#Include\s+(.+?)\s*$", Path(path).read_text(encoding="utf-8"), re.M)]


def block_classes(path):
    """Qualified IDs that a role block registers: the Register lines of the package blocks it includes."""
    out = []
    for inc in includes_of(path):
        pkg_block = (Path(path).parent / inc.replace("\\", "/")).resolve()
        out += re.findall(r"^ElementRegistry\.Register\((\w+\.\w+)\)", pkg_block.read_text(encoding="utf-8"), re.M)
    return sorted(out)


# --- the generator --------------------------------------------------------------------------------------------

def test_role_table_is_the_one_of_the_decision():
    assert {r: set(m) for r, m in gen.ROLE_MODES.items()} == {r: m for r, m in TABLE.items() if m}


def test_generated_blocks_are_up_to_date():
    assert gen.main(["--check"]) == 0, "run: python tools/gen_element_includes.py"


@pytest.mark.parametrize("role", ROLES_WITH_BLOCK)
def test_each_product_block_holds_exactly_the_classes_of_its_modes(role):
    expected = sorted(q for q, mode in product_classes().items() if mode in TABLE[role])
    assert block_classes(ENTRY_DIR / "generated" / ("Elements_%s.ahk" % role)) == expected


@pytest.mark.parametrize("role", ROLES_WITH_BLOCK)
def test_each_test_block_holds_exactly_the_test_classes_of_its_modes(role):
    expected = sorted(q for q, mode in classes_of_the_test_set().items() if mode in TABLE[role])
    assert block_classes(TEST_ENTRY_DIR / "generated" / ("TestElements_%s.ahk" % role)) == expected


@pytest.mark.parametrize("role", [r for r, m in TABLE.items() if not m])
def test_roles_without_classes_have_no_block(role):
    assert not (ENTRY_DIR / "generated" / ("Elements_%s.ahk" % role)).exists()
    assert not (TEST_ENTRY_DIR / "generated" / ("TestElements_%s.ahk" % role)).exists()
    assert not list(ELEMENTS.glob("*/_includes_%s.ahk" % role))


def test_the_product_has_the_package_default_and_no_test_class():
    assert {q.split(".")[0] for q in product_classes()} == {"Default"}
    assert not [q for q in product_classes() if q.split(".")[1].lower().startswith("action_test")]
    for role in ROLES_WITH_BLOCK:
        for q in block_classes(ENTRY_DIR / "generated" / ("Elements_%s.ahk" % role)):
            assert not q.split(".")[1].lower().startswith("action_test"), (role, q)
    # the test classes are in packages below tests/elements, and nothing of the product includes a file of tests/
    assert classes_of_the_test_set() and all(q.split(".")[1].lower().startswith(("action_test", "trigger_test")) for q in classes_of_the_test_set())
    for path in list(ENTRY_DIR.rglob("*.ahk")) + list(ELEMENTS.rglob("*.ahk")):
        for inc in includes_of(path):
            target = (path.parent / inc.split(";")[0].strip().replace("\\", "/")).resolve()
            assert target.relative_to(ROOT).parts[0] != "tests", (path, inc)


def test_every_icon_of_a_class_is_in_the_icons_of_its_package():
    for folder in (ELEMENTS, TEST_ELEMENTS):
        for desc in folder.glob("*/package.json"):
            for kind in KINDS:
                for path in (desc.parent / kind).glob("*.ahk"):
                    m = re.search(r'^\s*static\s+Icon\s*:=\s*"([^"]*)"', path.read_text(encoding="utf-8"), re.M)
                    if m and m.group(1):
                        assert (desc.parent / "Icons" / m.group(1)).is_file(), (path, m.group(1))


def test_the_package_default_has_the_language_files_of_v1():
    # copied unchanged from the v1 package (WI-0047): UTF-16 with BOM, CRLF (.gitattributes keeps them byte for byte)
    ours = ELEMENTS / "Default" / "language"
    assert sorted(p.name for p in ours.glob("*.ini")) == ["de.ini", "en.ini", "ko.ini", "ru.ini"]
    for path in ours.glob("*.ini"):
        data = path.read_bytes()
        assert data[:2] == bytes([0xFF, 0xFE]), path.name
        assert "[language_info]" in data.decode("utf-16"), path.name


def test_the_package_default_has_the_version_of_v1():
    desc = json.loads((ELEMENTS / "Default" / "package.json").read_text(encoding="utf-8"))
    assert desc["name"] == "Default" and desc["version"] == "1.2.1"


def test_the_trigger_and_worker_blocks_hold_only_their_own_mode():
    modes = product_classes()
    assert all(modes[q] == "trigger" for q in block_classes(ENTRY_DIR / "generated" / "Elements_triggerhost.ahk"))
    assert all(modes[q] == "worker" for q in block_classes(ENTRY_DIR / "generated" / "Elements_worker.ahk"))


@pytest.fixture
def small_tree(tmp_path, monkeypatch):
    """A tiny element tree for the generator (one package Pkg with the class Action_A), so that the failure cases can
    be created. The names of the code base are not scanned (NAME_SOURCES is the temporary folder). The base files are
    the real ones, so that AutoHotkey can run the blocks."""
    base = tmp_path / "elements"
    pkg = base / "Pkg"
    (pkg / "Actions").mkdir(parents=True)
    (pkg / "package.json").write_text('{"name": "Pkg", "version": "1.0"}')
    (pkg / "Actions" / "Action_A.ahk").write_text('class Action_A {\n    static Mode := "inline"\n}\n')
    monkeypatch.setattr(gen, "PRODUCT_DIR", base)
    monkeypatch.setattr(gen, "PRODUCT_OUT", tmp_path / "out")
    monkeypatch.setattr(gen, "TEST_DIR", tmp_path / "testelements")
    monkeypatch.setattr(gen, "TEST_OUT", tmp_path / "testout")
    monkeypatch.setattr(gen, "NAME_SOURCES", (tmp_path,))
    return pkg


def test_generator_works_on_a_small_tree(small_tree, tmp_path):
    assert gen.main([]) == 0
    assert block_classes(tmp_path / "out" / "Elements_engine.ahk") == ["Pkg.Action_A"]
    assert block_classes(tmp_path / "out" / "Elements_worker.ahk") == []
    text = (small_tree / "_includes_engine.ahk").read_text(encoding="utf-8")
    assert "class Pkg {" in text and "    #Include Actions\\Action_A.ahk" in text
    assert 'ElementRegistry.RegisterPackage("Pkg", "1.0")' in text
    assert gen.main(["--check"]) == 0


def test_a_stale_block_fails_the_check_and_is_written_again(small_tree, tmp_path, capsys):
    assert gen.main([]) == 0
    capsys.readouterr()
    # a new class file that the blocks do not know yet
    (small_tree / "Actions" / "Action_B.ahk").write_text('class Action_B {\n    static Mode := "worker"\n}\n')
    assert gen.main(["--check"]) == 1
    out = capsys.readouterr().out
    assert "out of date:" in out and "_includes_worker.ahk" in out and "_includes_engine.ahk" in out
    assert gen.main([]) == 0
    assert gen.main(["--check"]) == 0
    # a block edited by hand
    path = small_tree / "_includes_engine.ahk"
    path.write_text(path.read_text(encoding="utf-8") + "; my change\n", encoding="utf-8")
    capsys.readouterr()
    assert gen.main(["--check"]) == 1
    assert "_includes_engine.ahk" in capsys.readouterr().out
    # a block that no role needs (a role that does not exist)
    assert gen.main([]) == 0
    (small_tree / "_includes_nothing.ahk").write_text("old\n")
    capsys.readouterr()
    assert gen.main(["--check"]) == 1
    assert "not needed:" in capsys.readouterr().out
    assert gen.main([]) == 0
    assert not (small_tree / "_includes_nothing.ahk").exists()


@pytest.mark.parametrize("text, message", [
    ("class Action_B {\n}\n", "no `static Mode"),
    ("class Action_B {\n    static Mode := Action_A.Mode\n}\n", "not a literal"),
    ('class Action_B {\n    static Mode := "inline" . ""\n}\n', "not a literal"),
    ('class Action_B {\n    static Mode := "remote"\n}\n', "not one of"),
    ('class Action_B {\n    static Mode := "inline"\n    static Mode := "worker"\n}\n', "more than one"),
    ('class Action_C {\n    static Mode := "inline"\n}\n', "exactly one top-level class named Action_B"),
    ('class Action_B {\n    static Mode := "inline"\n}\nclass Action_X {\n}\n', "exactly one top-level class"),
    ('class Action_B {\n    static Mode := "inline"\n}\nElementRegistry.Register(Action_B)\n', "Register line"),
    ('class Action_B {\n    static Mode := "inline"\n    static Run(ctx, p) => Action_B.Go()\n}\n', "use `this`"),
    ('#IncludeAgain x.ahk\nclass Action_B {\n    static Mode := "inline"\n}\n', "#IncludeAgain"),
    ('#Include missing.ahk\nclass Action_B {\n    static Mode := "inline"\n}\n', "does not exist"),
])
def test_generator_fails_on_a_class_file_it_cannot_use_and_names_the_file(small_tree, capsys, text, message):
    (small_tree / "Actions" / "Action_B.ahk").write_text(text)
    assert gen.main([]) == 1
    err = capsys.readouterr().err
    assert "Action_B.ahk" in err and message in err, err


def test_a_mode_in_a_comment_does_not_count(small_tree, capsys):
    (small_tree / "Actions" / "Action_B.ahk").write_text('; static Mode := "worker"\nclass Action_B {\n}\n')
    assert gen.main([]) == 1
    assert "Action_B.ahk" in capsys.readouterr().err


def test_a_class_must_be_in_the_folder_of_its_kind(small_tree, capsys):
    (small_tree / "Actions" / "Trigger_B.ahk").write_text('class Trigger_B {\n    static Mode := "trigger"\n}\n')
    assert gen.main([]) == 1
    assert "must start with Action_" in capsys.readouterr().err
    (small_tree / "Actions" / "Trigger_B.ahk").unlink()
    (small_tree / "Action_C.ahk").write_text('class Action_C {\n    static Mode := "inline"\n}\n')
    assert gen.main([]) == 1
    assert "belongs in Actions/" in capsys.readouterr().err


def test_generator_refuses_a_class_file_that_includes_a_class_file(small_tree, capsys):
    # F-0081: the include would put the other class into every role that holds this file
    (small_tree / "Actions" / "Action_B.ahk").write_text(
        '#Include Action_A.ahk\nclass Action_B {\n    static Mode := "worker"\n}\n')
    assert gen.main([]) == 1
    err = capsys.readouterr().err
    assert "Action_B.ahk" in err and "Action_A.ahk" in err, err


def test_shared_code_in_lib_is_included_before_the_package_class(small_tree):
    (small_tree / "lib").mkdir()
    (small_tree / "lib" / "Kit.ahk").write_text("class Kit {\n}\n")
    (small_tree / "Actions" / "Action_B.ahk").write_text(
        '#Include ..\\lib\\Kit.ahk  ; comment\nclass Action_B {\n    static Mode := "worker"\n}\n')
    assert gen.main([]) == 0
    worker = (small_tree / "_includes_worker.ahk").read_text(encoding="utf-8")
    assert worker.index("#Include lib\\Kit.ahk") < worker.index("class Pkg {")
    assert "Kit" not in (small_tree / "_includes_triggerhost.ahk").read_text(encoding="utf-8")


@pytest.mark.parametrize("name, message", [
    ("My Pkg", "not an AutoHotkey class name"),
    ("1Pkg", "not an AutoHotkey class name"),
    ("Map", "reserved word or a built-in name"),
    ("Loop", "reserved word or a built-in name"),
    ("AhfTools", "prefix of the classes of AutoHotFlow"),
    ("Engine", "global class or function of the code"),
])
def test_a_package_name_must_be_a_safe_class_name(small_tree, tmp_path, capsys, name, message):
    (tmp_path / "code.ahk").write_text("class Engine {\n}\n")
    folder = small_tree.parent / name
    small_tree.rename(folder)
    (folder / "package.json").write_text(json.dumps({"name": name, "version": "1.0"}))
    assert gen.main([]) == 1
    assert message in capsys.readouterr().err


def test_the_package_name_is_the_folder_name_and_unique(small_tree, tmp_path, capsys):
    (small_tree / "package.json").write_text('{"name": "Other", "version": "1.0"}')
    assert gen.main([]) == 1
    assert "name of the folder" in capsys.readouterr().err
    (small_tree / "package.json").write_text('{"name": "Pkg"}')
    assert gen.main([]) == 1
    assert "\"version\" is missing" in capsys.readouterr().err
    (small_tree / "package.json").write_text('{"name": "Pkg", "version": "1.0"}')
    twin = tmp_path / "testelements" / "pkg"
    (twin / "Actions").mkdir(parents=True)
    (twin / "package.json").write_text('{"name": "pkg", "version": "1.0"}')
    assert gen.main([]) == 1
    assert "used twice" in capsys.readouterr().err


def test_a_test_class_in_the_product_is_refused(small_tree, capsys):
    (small_tree / "Actions" / "Action_TestX.ahk").write_text('class Action_TestX {\n    static Mode := "inline"\n}\n')
    assert gen.main([]) == 1
    assert "belongs in a package below tests/elements" in capsys.readouterr().err


# --- the entry scripts ----------------------------------------------------------------------------------------

ROLE_FILE = {"storage": r"storage\Storage.ahk", "engine": r"engine\Engine.ahk", "worker": r"worker\Worker.ahk",
             "manager": r"manager\StubManager.ahk", "debug": r"debugview\DebugView.ahk",
             "triggerhost": r"triggerhost\TriggerHost.ahk", "editor": r"core\PlaceholderRole.ahk",
             "tray": r"tray\Tray.ahk"}


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
        if role in ("engine", "worker"):
            expected.append(r"..\TestDialogProvider.ahk")      # answers the dialogs of elements (E0038, WI-0051)
    assert includes_of(TEST_ENTRY_DIR / (role + ".ahk")) == expected


# --- what a block registers when AutoHotkey runs it ---------------------------------------------------------

PROBE = """#Requires AutoHotkey v2.0
#Include {registry}
{includes}
ids := ""
for cls in ElementRegistry.All()
    ids .= ElementRegistry.IdOf(cls) ":" cls.Mode "`n"
FileAppend(ids, "*", "UTF-8-RAW")
"""


def probe(datadir, run_ahk, *blocks):
    """The `qualified ID:mode` lines that the blocks register when AutoHotkey runs them in one script."""
    script = datadir / "probe.ahk"
    script.write_text(PROBE.format(registry=ELEMENTS / "base" / "ElementRegistry.ahk",
                                   includes="\n".join("#Include %s" % b for b in blocks)), encoding="utf-8")
    res = run_ahk(script)
    assert res.returncode == 0, res.stderr
    return sorted(line for line in res.stdout.splitlines() if line)


@pytest.mark.parametrize("role", ROLES_WITH_BLOCK)
def test_a_block_registers_only_the_classes_of_its_modes(role, datadir, run_ahk):
    got = probe(datadir, run_ahk, ENTRY_DIR / "generated" / ("Elements_%s.ahk" % role))
    expected = sorted("%s:%s" % (q, m) for q, m in product_classes().items() if m in TABLE[role])
    assert got == expected


@pytest.mark.parametrize("role", ROLES_WITH_BLOCK)
def test_a_test_block_registers_only_the_test_classes_of_its_modes(role, datadir, run_ahk):
    # F-0081: the text check of the blocks does not see a class that comes in through an include, this probe does
    got = probe(datadir, run_ahk, TEST_ENTRY_DIR / "generated" / ("TestElements_%s.ahk" % role))
    expected = sorted("%s:%s" % (q, m) for q, m in classes_of_the_test_set().items() if m in TABLE[role])
    assert got == expected


def test_the_product_engine_block_knows_no_test_class(datadir, run_ahk):
    got = probe(datadir, run_ahk, ENTRY_DIR / "generated" / "Elements_engine.ahk")
    assert got and not [line for line in got if ".action_test" in line.lower()], got


def test_two_packages_with_a_class_of_the_same_name_load_in_one_process(small_tree, tmp_path, datadir, run_ahk):
    # E0045: the class name alone does not identify an element; Pkg.Action_A and Twin.Action_A are two classes
    for pkg in (small_tree, small_tree.parent / "Twin"):
        (pkg / "Actions").mkdir(parents=True, exist_ok=True)
        (pkg / "Actions" / "Action_A.ahk").write_text(
            'class Action_A extends AhfElement {\n    static Mode := "%s"\n}\n'
            % ("inline" if pkg == small_tree else "worker"))
    (small_tree.parent / "Twin" / "package.json").write_text('{"name": "Twin", "version": "2.0"}')
    assert gen.main([]) == 0
    got = probe(datadir, run_ahk, tmp_path / "out" / "Elements_engine.ahk")
    assert got == ["Pkg.Action_A:inline", "Twin.Action_A:worker"]
