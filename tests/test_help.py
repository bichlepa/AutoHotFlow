"""The help pages (WI-0112, E0100, REQ-ELM-020, REQ-LNG-040): every core element has its page, the generated HTML is
current, the links resolve, and the generator does what its documentation says (tools/gen_help.py).
"""

import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import gen_help  # noqa: E402

ELEMENTS = ROOT / "src" / "elements" / "Default"
HELP = ELEMENTS / "help" / "en"

# The 29 elements of the core set (README of phase 3, S0002, the owner's count of 2026-10-16), by class name.
CORE_SET = [
    "Action_New_variable", "Condition_Expression", "Condition_Variable_content_is", "Condition_NumberIs",
    "Condition_Variable_Is_Empty", "Action_Do_nothing", "Condition_Do_nothing", "Action_Trace_Point",
    "Action_Trace_Point_Check",
    "Action_New_List", "Action_Add_To_List", "Action_Get_List_Info", "Condition_List_Contains_Element",
    "Action_Delete_from_list", "Action_Get_index_of_element_in_list", "Action_Shuffle_list",
    "Loop_SimpleLoop", "Loop_Condition", "Loop_Work_through_a_list", "Loop_Parse_A_String",
    "Action_Execute_Flow", "Action_Stop_Flow", "Condition_Flow_Running",
    "Action_Message_Box", "Condition_Confirmation_Dialog", "Condition_Debug_Dialog", "Action_Tooltip",
    "Action_Sleep", "Trigger_Manual",
]

KIND_FOLDERS = {"Action": "Actions", "Condition": "Conditions", "Loop": "Loops", "Trigger": "Triggers"}


def _kind_and_name(class_name):
    prefix, _, name = class_name.partition("_")
    return KIND_FOLDERS[prefix], name


def _has_source(kind, name):
    """The Markdown source `<name>.md` of a kind folder, with the exact spelling (a case-insensitive file system
    would otherwise hide a wrong case that breaks on Linux)."""
    folder = HELP / kind
    return folder.is_dir() and (name + ".md") in os.listdir(folder)


def test_the_core_set_has_29_elements():
    assert len(CORE_SET) == 29
    assert len(set(CORE_SET)) == 29


@pytest.mark.parametrize("class_name", CORE_SET)
def test_every_core_element_has_a_help_source_of_its_own(class_name):
    kind, name = _kind_and_name(class_name)
    assert (ELEMENTS / kind / (class_name + ".ahk")).exists(), "the element file is missing"
    assert _has_source(kind, name), "write the page as src/elements/Default/help/en/%s/%s.md" % (kind, name)


def test_every_element_file_of_the_default_package_has_a_help_source():
    missing = []
    for folder in ("Actions", "Conditions", "Loops", "Triggers"):
        for element in sorted((ELEMENTS / folder).glob("*.ahk")):
            kind, name = _kind_and_name(element.stem)
            if not _has_source(kind, name):
                missing.append(element.name)
    assert missing == [], "element files without a help page (write it in S0008 with the element)"


def test_the_general_pages_exist():
    for name in ("Welcome", "Variables", "Key_list", "Color_chart"):
        assert (ROOT / "assets" / "help" / "en" / (name + ".md")).exists(), name


def test_the_generated_pages_are_current_and_the_links_resolve():
    # the same check as the VS Code task `Tool: check help pages (no write, --check)`
    assert gen_help.main(["--check"]) == 0, "run: python tools/gen_help.py"


def test_every_page_is_self_contained_and_marked_for_the_classic_viewer():
    expected, errors = gen_help.build(ROOT)
    assert errors == []
    assert expected, "no help page found"
    for page, text in expected.items():
        assert '<meta http-equiv="X-UA-Compatible" content="IE=edge">' in text, page
        assert "<link " not in text, "a page must not depend on an external stylesheet: %s" % page
        assert "<title>" in text, page


def test_a_link_to_a_general_page_is_html_in_the_generated_page():
    page = (HELP / "Conditions" / "Expression.html").read_text(encoding="utf-8")
    assert 'href="../../../../../../assets/help/en/Variables.html"' in page
    assert ".md\"" not in page


# --- the generator, on a small tree of its own -------------------------------------------------------------------

def _tree(tmp_path, files):
    (tmp_path / "assets" / "help").mkdir(parents=True)
    (tmp_path / "assets" / "help" / "help.css").write_text("p { color: red; }\n", encoding="utf-8")
    for name, text in files.items():
        path = tmp_path / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")
    return tmp_path


def test_a_link_between_pages_becomes_html_and_an_anchor_is_kept(tmp_path):
    root = _tree(tmp_path, {
        "assets/help/en/a.md": "# Page A\n\nSee [B](b.md#part) and [site](https://example.com).\n",
        "assets/help/en/b.md": "# Page B\n\n## Part\n\ntext\n",
    })
    expected, errors = gen_help.build(root)
    assert errors == []
    page = expected[root / "assets/help/en/a.html"]
    assert 'href="b.html#part"' in page
    assert 'href="https://example.com"' in page
    assert "<title>Page A</title>" in page
    assert "p { color: red; }" in page


def test_a_broken_link_is_reported(tmp_path):
    root = _tree(tmp_path, {"assets/help/en/a.md": "# A\n\n[gone](missing.md)\n"})
    _, errors = gen_help.build(root)
    assert any("broken link to missing.md" in e for e in errors)


def test_a_page_without_a_title_is_reported(tmp_path):
    root = _tree(tmp_path, {"assets/help/en/a.md": "text only\n"})
    _, errors = gen_help.build(root)
    assert any("no title" in e for e in errors)


def test_check_fails_on_a_stale_or_superfluous_page_and_write_repairs_both(tmp_path):
    root = _tree(tmp_path, {"assets/help/en/a.md": "# A\n\ntext\n"})
    assert gen_help.main(["--check"], root=root) == 1          # the page is missing
    assert gen_help.main([], root=root) == 0                   # write
    assert gen_help.main(["--check"], root=root) == 0
    (root / "assets/help/en/a.md").write_text("# A\n\nchanged\n", encoding="utf-8", newline="\n")
    assert gen_help.main(["--check"], root=root) == 1          # stale
    assert gen_help.main([], root=root) == 0
    (root / "assets/help/en/orphan.html").write_text("<p>x</p>\n", encoding="utf-8")
    assert gen_help.main(["--check"], root=root) == 1          # superfluous
    assert gen_help.main([], root=root) == 0
    assert not (root / "assets/help/en/orphan.html").exists()
