# WI-0069 `ui_common/`: window base, DPI, dialogs that do not block, language reload

Size: M · Depends on: – · Blocks: WI-0073

## Goal

The UI roles (manager now, editor from S0005) get a shared library `src/ui_common/` (ARCHITECTURE 8: "GUI helpers"). It gives a window that is sharp at every scaling, small dialogs that never block the message path (rule 3), and a way to change the language of an open window. A spike settles whether the modal standard dialogs of AutoHotkey (`FileSelect`, `DirSelect`, `MsgBox`) keep the pipe handling of a role going. Requirements: REQ-USE-090 (part), REQ-USE-040 (part), REQ-LNG-010 (part).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 3, 8 (folder rules: `ui_common/` for UI roles only); `doc/CONVENTIONS.md`; `doc/howto/gui-and-hotkeys.md` (DPI entry, tray menu entry); `src/elements/base/DialogWindow.ahk` (the DPI handling of the dialog elements, manual check 3); `src/core/Lang.ahk`, `src/core/LangTable.ahk`; `src/core/ipc/Wake.ahk`; `src/supervisor/Heartbeat.ahk`; AHK v2 docs `lib/Gui.htm`, `lib/FileSelect.htm`, `lib/DirSelect.htm`, `misc/Threads.htm`.

## Tasks

1. **Spike (first, result in a HOW-TO entry):** a test role (test entry, `--test-roles`) opens `FileSelect`, `DirSelect` and `MsgBox` on a request and keeps them open for 10 s; the test sends `sys.ping` meanwhile and measures the answers. Run in the `gui` tier only if a window must be seen; otherwise the dialog is opened and closed by the test through its window handle (the dialog guard of `ahkrun.py` must not close it: start the role without it, or with a way to keep the dialog). Result: which standard dialogs may be used in a UI role. If one blocks the pings, `ui_common/` offers an own replacement (or the role reports `sys.busy` around it, as the workers do); report the choice in the result.
2. **Window base** `ui_common/UiWindow.ahk`: per-monitor DPI awareness before the first `Gui` (move the code of `DialogWindow` here and let `DialogWindow` use it; elements may include `ui_common/` only if the architecture rule allows it, otherwise a shared file in `core/`; decide and document), position and size kept per window name (the values are UI state; where they are saved is decided in WI-0073), a reaction to `WM_DPICHANGED`.
3. **Dialogs that do not block** `ui_common/UiDialogs.ahk`: confirm (with a text and two or three buttons), text input with a check function (for names: forbidden characters, an existing name; the check is passed in), choose one from a list (for the target category). Each answers through a callback, never by a return value that waits. One dialog of a kind per owner window at a time.
4. **Language reload:** a window registers its texts as keys (`Lang` keys, not the texts), and a call `UiTexts.Reload()` after a change of `LangTable.Code` sets every registered control again. Used by WI-0078.
5. **Tests:** AHK unit tests of the dialog logic without a window where possible (the check function, the callbacks); the windows in the `gui` tier (owner) or by a manual check step in WI-0076.

## Acceptance criteria

- The spike result is in `doc/howto/gui-and-hotkeys.md` with its status.
- The unit tests are green; `python tools/arch_check.py` is green (folder rule for `ui_common/`).
- The dialog elements still work (`tests/e2e` dialog tests green) after `DialogWindow` uses the shared DPI code.

## Not part of this

The manager windows themselves (WI-0073, WI-0074); the editor (S0005).
