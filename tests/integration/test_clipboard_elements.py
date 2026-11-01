"""WI-0123: end-to-end tests of the clipboard elements of the package Default: Get clipboard and Set clipboard, on the real
Windows clipboard (no seam: other programs use it too). The fixture saves the text of the clipboard of the user before each
test and puts it back after it. All tests of this file share the xdist group `clipboard`, so they never use the clipboard
at the same time.

The busy-clipboard test holds the clipboard open in this test process (the owner's copy of the clipboard is kept the same
way, the content is restored at the end). A clipboard that another program holds is not touched by the tests.
"""

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.clipboard import open_clipboard, read_text, restore, set_text, snapshot
from support.flowrun import flows  # noqa: F401  (fixture)

pytestmark = pytest.mark.xdist_group("clipboard")

@pytest.fixture(autouse=True)
def clipboard_kept():
    """The clipboard of the user is put back after every test of this file."""
    items = snapshot()
    yield
    restore(items)


def element_flow(name, cls, probe=None, **pars):
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    parts = [fb.trigger(), el]
    if probe:
        parts.append(fb.probe(probe))
    fb.chain(*parts)
    return fb


def test_get_clipboard_reads_the_text_into_a_variable(flows):
    set_text("Hallo Welt, äöü")
    runs = run_all(flows, [element_flow("get_clipboard", "Action_Get_Clipboard", probe="x", Varname="x")])
    assert not runs[0].exceptions, runs[0].steps
    assert runs[0].seen["x"].text == "Hallo Welt, äöü"


def test_set_clipboard_puts_the_text_on_the_clipboard(flows):
    runs = run_all(flows, [element_flow("set_clipboard", "Action_Set_Clipboard", text="AHF clipboard 123")])
    assert not runs[0].exceptions, runs[0].steps
    assert read_text() == "AHF clipboard 123"


def test_set_clipboard_with_an_empty_text_clears_it(flows):
    set_text("to be cleared")
    runs = run_all(flows, [element_flow("clear_clipboard", "Action_Set_Clipboard", text="")])
    assert not runs[0].exceptions, runs[0].steps
    assert read_text() is None


def test_a_busy_clipboard_is_an_exception_and_nothing_changes(flows):
    """MIGRATION M-0122: this process holds the clipboard open while the element runs."""
    set_text("keep")
    with open_clipboard():
        runs = run_all(flows, [element_flow("busy_clipboard", "Action_Set_Clipboard", text="new")])
    assert runs[0].exceptions and "could not be used" in runs[0].exceptions[0], runs[0].steps
    assert read_text() == "keep"
