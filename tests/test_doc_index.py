"""Indexes of the repository: the one check of tools/doc_index.py (both indexes, the requirement checks included)
and the line-range logic of the tool.

The first test fails with the messages of the check: a format, evidence or reference error of the requirements,
or an index that is outdated (run python tools/doc_index.py). The other tests feed small example texts to the
functions of the tool.
"""

import io
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent.parent / "tools"
sys.path.insert(0, str(TOOLS_DIR))
import doc_index  # noqa: E0402


def lines_of(text):
    return text.split("\n")


def test_all_indexes_are_up_to_date_and_the_requirements_are_valid():
    out = io.StringIO()
    code = doc_index.run(check=True, out=out)
    assert code == 0, out.getvalue()


def test_nested_levels_end_at_the_next_heading_of_same_or_higher_level():
    text = "\n".join([
        "# Title",          # 1
        "intro",            # 2
        "## A",             # 3
        "text",             # 4
        "### A1",           # 5
        "text",             # 6
        "",                 # 7
        "### A2",           # 8
        "text",             # 9
        "## B",             # 10
        "text",             # 11
    ])
    got = doc_index.sections(lines_of(text), (2, 3))
    assert got == [
        (3, 9, 2, "A"),      # A includes its subsections, ends before ## B
        (5, 6, 3, "A1"),     # A1 ends before ### A2; the blank line before it is not counted
        (8, 9, 3, "A2"),
        (10, 11, 2, "B"),
    ]


def test_last_section_runs_to_the_end_of_the_file_without_trailing_blank_lines():
    text = "## Only\nline\nline\n\n\n"
    assert doc_index.sections(lines_of(text), (2,)) == [(1, 3, 2, "Only")]


def test_a_heading_inside_a_code_block_is_not_a_heading():
    text = "\n".join([
        "## Real",          # 1
        "```markdown",      # 2
        "## Not a heading", # 3
        "### Neither",      # 4
        "```",              # 5
        "text",             # 6
        "## Next",          # 7
    ])
    assert doc_index.sections(lines_of(text), (2,)) == [(1, 6, 2, "Real"), (7, 7, 2, "Next")]


def test_levels_not_listed_do_not_appear_but_still_end_a_section():
    text = "## A\ntext\n#### deep\ntext\n## B\n"
    assert doc_index.sections(lines_of(text), (2, 3)) == [(1, 4, 2, "A"), (5, 5, 2, "B")]


def test_how_to_status_follows_the_status_line():
    entry = lines_of("### Title\n\n- **Problem:** x\n- **Status:** verified (test)\n")
    assert doc_index.entry_status(entry, 1, 4) == "verified"
    partly = lines_of("### T\n- **Status:** verified; the order assumed\n")
    assert doc_index.entry_status(partly, 1, 2) == "partly verified"
    assert doc_index.entry_status(lines_of("### T\n- **Status:** assumed\n"), 1, 2) == "assumed"
    assert doc_index.entry_status(lines_of("### T\n- **Status:** not checked\n"), 1, 2) == "not checked"
