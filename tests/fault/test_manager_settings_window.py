"""WI-0078: the settings dialog and the about window in the real manager window (gui tier; agents do not run it, the owner does).

What is checked: the button "Settings" opens the dialog with its texts, Cancel closes it, a change of the language while the
dialog is open makes it again in the new language (its title and buttons), the button of the manager window follows the
language too, and the button "About AutoHotFlow" opens the about window. The look (the heights of the texts at other DPI) is the owner's
manual check (doc/MANUAL-CHECKS.md, section 8).

The windows are found by their process and their titles (English, or German after the change), like test_manager_window.py.
"""

import pytest

from faultfixtures import chains  # noqa: F401  (fixture)
from faultkit import request_ok, wait_until
from test_manager_window import BM_CLICK, READY_S, _text, children_of, user32, visible, window_of, _window_titled

pytestmark = [pytest.mark.fault, pytest.mark.gui]

WAIT_S = 10.0


def button_texts(hwnd):
    found = {}
    for child in children_of(hwnd):
        found.setdefault(_text(child), child)
    return found


def click(hwnd):
    user32.PostMessageW(hwnd, BM_CLICK, 0, 0)


@pytest.fixture
def manager(chains):  # noqa: F811
    chain = chains("storage,engine,manager", [])
    chain.wait_ready(["storage", "engine", "manager"], timeout=READY_S)
    chain.wait_flows(timeout=READY_S)
    pid = chain.pid("manager")
    hwnds = wait_until(lambda: window_of(pid), WAIT_S)
    assert hwnds, "no manager window"
    return chain, pid, hwnds[0]


def test_settings_opens_its_dialog_and_cancel_closes_it(manager):
    chain, pid, hwnd = manager
    assert wait_until(lambda: visible(hwnd), WAIT_S)
    click(button_texts(hwnd)["Settings"])
    dialogs = wait_until(lambda: _window_titled(pid, "Settings"), WAIT_S)
    assert dialogs, "the settings dialog did not open"
    dlg = dialogs[0]
    assert wait_until(lambda: visible(dlg), WAIT_S)
    texts = [_text(c) for c in children_of(dlg)]
    for expected in ("Language", "Working directory", "Start with windows", "Run as admin", "OK", "Cancel"):
        assert expected in texts, (expected, texts)
    assert any(t.startswith("Browse") for t in texts), texts      # the button reads "Browse..."
    click(button_texts(dlg)["Cancel"])
    assert wait_until(lambda: not _window_titled(pid, "Settings"), WAIT_S), "Cancel did not close the dialog"
    assert chain.sup.proc.poll() is None, "the application ended"


def test_a_language_change_makes_the_open_dialog_and_the_manager_button_again(manager):
    chain, pid, hwnd = manager
    assert wait_until(lambda: visible(hwnd), WAIT_S)
    click(button_texts(hwnd)["Settings"])
    assert wait_until(lambda: _window_titled(pid, "Settings"), WAIT_S), "the settings dialog did not open"
    request_ok(chain.obs, "engine", "cmd.settings.set", {"settings": {"language": "de"}})
    german = wait_until(lambda: _window_titled(pid, "Einstellungen"), WAIT_S)
    assert german, "the open dialog did not take the language"
    # the controls are made after the window itself: wait for the German button, not only for the title
    assert wait_until(lambda: "Abbrechen" in button_texts(german[0]), WAIT_S), "its buttons are not German"
    assert wait_until(lambda: "Einstellungen" in button_texts(hwnd), WAIT_S), \
        "the button of the manager window did not change its text"
    click(button_texts(german[0])["Abbrechen"])
    request_ok(chain.obs, "engine", "cmd.settings.set", {"settings": {"language": ""}})


def test_about_opens_the_about_window_with_the_versions_and_the_site(manager):
    chain, pid, hwnd = manager
    assert wait_until(lambda: visible(hwnd), WAIT_S)
    click(button_texts(hwnd)["About AutoHotFlow"])
    about = wait_until(lambda: _window_titled(pid, "About AutoHotFlow"), WAIT_S)
    assert about, "the about window did not open"
    texts = [_text(c) for c in children_of(about[0])]
    assert any("AutoHotkey version" in t for t in texts), texts
    assert "https://github.com/bichlepa/AutoHotFlow" in texts, texts
