"""Static checks of the role tray (WI-0072, E0075, E0014, E0046, REQ-MGR-090, REQ-MGR-140).

The tray icon and the tray menu of the application are the role tray's (src/tray/Tray.ahk), not the supervisor's and not
the manager's. These checks read the source: the e2e tests (tests/fault/test_tray_role.py) start the role and click the menu
entries through the test driver, the real icon and an open menu are checked by the gui test there.
What they prove: the standard items of AutoHotkey (above all its own "Exit", which ends the process without the shutdown
of the application) are removed before the own entries are added; the menu has the two entries, "Show manager" as the
default entry; the handlers only send a request; the manager has no tray menu any more.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRAY = (ROOT / "src" / "tray" / "Tray.ahk").read_text(encoding="utf-8")
MANAGER = (ROOT / "src" / "manager" / "StubManager.ahk").read_text(encoding="utf-8")


def _method_body(source, name):
    m = re.search(r"^    " + re.escape(name) + r"\([^\n]*\) \{\n(.*?)^    \}", source, re.S | re.M)
    assert m, name
    return m.group(1)


def test_the_standard_tray_items_are_removed_before_the_own_entries_are_added():
    build = _method_body(TRAY, "_BuildMenu")
    assert build.index("A_TrayMenu.Delete()") < build.index("A_TrayMenu.Add(")


def test_the_menu_has_show_manager_as_the_default_entry_and_exit():
    build = _method_body(TRAY, "_BuildMenu")
    assert len(re.findall(r"A_TrayMenu\.Add\(", build)) == 2
    assert "A_TrayMenu.Add(this.menuShow, (*) => this.ShowManager())" in build
    assert "A_TrayMenu.Add(this.menuExit, (*) => this.Exit())" in build
    assert "A_TrayMenu.Default := this.menuShow" in build
    assert 'KEY_SHOW := "Show_Manager"' in TRAY and 'KEY_EXIT := "Exit_#verb"' in TRAY


def test_the_handlers_only_send_a_request_to_the_supervisor():
    assert 'this._Send("cmd.app.command", Map("argv", []))' in _method_body(TRAY, "ShowManager")
    assert 'this._Send("cmd.app.exit", Map())' in _method_body(TRAY, "Exit")
    send = _method_body(TRAY, "_Send")
    assert 'this.peer.Request("supervisor", type, payload,' in send and "Tray.REQUEST_MS" in send
    for blocking in ("MsgBox", "RunWait", "Sleep(", "FileRead", "FileAppend"):
        assert blocking not in TRAY


def test_the_icon_is_shown_after_the_menu_is_built_and_stays_hidden_when_headless():
    start = _method_body(TRAY, "Start")
    assert start.index("this._BuildMenu()") < start.index("A_IconHidden := this.headless")
    assert 'static TIP := "AutoHotFlow"' in TRAY and "A_IconTip := Tray.TIP" in start


def test_the_manager_has_no_tray_menu_and_no_icon():
    assert "A_TrayMenu" not in MANAGER
    assert any(line.strip().lower() == "#notrayicon"
               for line in (ROOT / "src" / "entry" / "manager.ahk").read_text(encoding="utf-8").splitlines())


def test_the_supervisor_restarts_the_tray_role_and_ends_it_with_the_ui_roles():
    children = (ROOT / "src" / "supervisor" / "Children.ahk").read_text(encoding="utf-8")
    assert re.search(r'static AUTO_RESTART := Map\([^)]*"tray", 1', children)
    assert 'role = "tray"' in children          # shutdown rank 0, with the manager and the editors
