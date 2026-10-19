# WI-0091 Tray icon and tray menu of the editor

Size: S · Depends on: WI-0088 · Blocks: WI-0092

## Goal

Every open editor has a tray icon of its own with the state of its flow, and the same icon on its window; the menu has the full set of entries already in S0005 (E0087): Show, Run, Enable or disable, Close. Requirements: REQ-EDT-230, REQ-EDT-110 (run and enable from the editor, part).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0046, E0075, E0077, E0087; `doc/PROTOCOL.md` 4.2 (`cmd.flow.start`, `cmd.flow.enable`, `cmd.flow.disable`), 4.10 (the tray role: headless, test command, notices); `src/tray/Tray.ahk`; `src/manager/ManagerOps.ahk` (the questions before disabling a flow with independent triggers and before `force`, E0056, E0063); `v1/Source_Editor/User Interface/Tray.ahk`.

## Tasks

1. **Icon:** `assets/icons/` `disabled.ico`, `enabled.ico`, `running.ico` by `evt.flow.state` (running wins over enabled); the same icon on the window (big and small, DPI sizes). Tooltip "Flow: <name>" (v1 key), renamed with the flow. `src/entry/editor.ahk` drops `#NoTrayIcon`; with `--headless` the icon stays hidden.
2. **Menu** (no standard entries of AutoHotkey): Show (default, double click), Run (`cmd.flow.start` without a trigger: the default trigger), Enable or Disable (by the state; the same questions as the manager for independent triggers and for an unknown state, with the texts of the manager), Close (as the close box). Every request has a timeout; an error answer (a start refused by a limit, a busy flow) is shown as a tray notice of this icon and logged. The entries are renamed on a language change.
3. **Menus pause only this editor** (E0077 applies to the editor): nothing to build, but a test like `tests/fault/test_tray_role.py` checks that an editor with an open menu is not judged hung (`gui` tier).
4. **Headless:** `cmd.test.command {item}` runs a menu entry as the tray role does; the snapshot names the icon state and the items.
5. **Tests** (e2e, headless): the icon state follows enable, disable, run and end; Run starts the flow; Enable and Disable switch it (with the question answered by the dialog provider); Close ends the editor cleanly.

## Acceptance criteria

- The tests of task 5 are green; REQ-EDT-230 done with its evidence after the manual check of WI-0092; REQ-EDT-110 partial (the tray menu).

## Not part of this

The menu bar of the editor window and the context menus (S0006).
