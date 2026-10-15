"""Tray menu of the manager (owner's request 2026-10-15, E0014, E0046, REQ-MGR-090).

These are static checks on the source: a desktop test of the real tray menu is not possible without a GUI test.
What they prove: the tray entry and the Beenden button use the same label and call the same method (UserExit,
which sends cmd.app.exit), and the standard items (above all AutoHotkey's own "Exit", which ends the process
without the shutdown of the supervisor) are removed before the own entry is added. That Start() runs the tray
setup without an error is covered by every e2e test that starts the manager (headless).
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANAGER = (ROOT / "src" / "manager" / "StubManager.ahk").read_text(encoding="utf-8")
GUI = (ROOT / "src" / "manager" / "StubGui.ahk").read_text(encoding="utf-8")


def _method_body(source, name):
    m = re.search(r"^    " + re.escape(name) + r"\(\) \{\n(.*?)^    \}", source, re.S | re.M)
    assert m, name
    return m.group(1)


def test_the_tray_menu_entry_and_the_button_call_the_same_method_with_the_same_label():
    tray = _method_body(MANAGER, "_SetupTray")
    assert "A_TrayMenu.Add(StubManager.EXIT_LABEL, (*) => this.UserExit())" in tray
    assert 'AddButton("x+8 yp w100", StubManager.EXIT_LABEL)' in GUI
    assert 'btnExit.OnEvent("Click", (*) => this.manager.UserExit())' in GUI
    assert re.search(r'static EXIT_LABEL := "Beenden"', MANAGER)
    assert 'cmd.app.exit' in _method_body(MANAGER, "UserExit")


def test_the_standard_tray_items_are_removed_so_exit_cannot_bypass_the_shutdown():
    tray = _method_body(MANAGER, "_SetupTray")
    assert tray.index("A_TrayMenu.Delete()") < tray.index("A_TrayMenu.Add(")
    assert "A_TrayMenu.Default" not in tray          # no default item: a double click does nothing
    assert len(re.findall(r"A_TrayMenu\.Add\(", tray)) == 1
    assert re.search(r"^        this\._SetupTray\(\)$", _method_body(MANAGER, "Start"), re.M)
