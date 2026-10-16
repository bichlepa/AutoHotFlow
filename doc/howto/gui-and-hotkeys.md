# How-to AHK v2: GUI and hotkeys

Entries of this category. Entry format, rules and index: [`../HOW-TO.md`](../HOW-TO.md).

### ListView: row clicks and selection after a rebuild

- **Problem:** The ListView help names the events (`Click`, `ItemFocus`, `ItemSelect`, ...) but does not list all parameters.
- **Right:** For row clicks: `lv.OnEvent("Click", (lv, row) => ...)`. After each rebuild mark the rows again with `Modify(row, "Select Focus")`; `Delete()` without parameters clears the list.
- **Status:** assumed (event names and parameters from the help; the click itself is not automated, only the start of the window was checked in a smoke run)
- **Source:** https://www.autohotkey.com/docs/v2/lib/ListView.htm

### Closing a Gui window does not end a role (`Persistent`)

- **Problem:** A window without its own reason to keep the main loop alive ends with the last window. The role keeps running through timers and the peer, but its display could disappear by accident.
- **Right:** `Role.Start` calls `Persistent()`. In the stub, closing the window does the same as quitting (`cmd.app.exit`), so no state is lost.
- **Status:** verified (smoke run: window open, supervisor answers, `cmd.app.exit` leads to exit 0)
- **Source:** `src/manager/StubGui.ahk`

### Capture and operate a window of an AHK role without screen access

- **Problem:** `Graphics.CopyFromScreen` fails without an accessible desktop ("The handle is invalid"), and `keybd_event` does not reach a window that is not in the foreground.
- **Right:** `PrintWindow(hwnd, memDC, 2)` (`PW_RENDERFULLCONTENT`) draws the window into a bitmap (`GetWindowDC`, `CreateCompatibleDC`/`CreateCompatibleBitmap`, `GetDIBits` with 32-bit top-down, then `PIL.Image.frombuffer("RGBA", ..., "BGRA")`). Operate without keyboard: tabs with `SendMessage(tabHwnd, WM_KEYDOWN, VK_RIGHT)`, buttons with `BM_CLICK` (0xF5). Buttons on a tab are children of the main window: `EnumChildWindows` on the main window finds them, `FindWindowExW(tab, ...)` does not. Close like a user: `PostMessage(hwnd, WM_CLOSE)`.
- **Status:** verified (screenshots of all five tabs; `tests/fault/test_debug_role.py::test_the_window_opens_takes_events_and_closes_like_a_user_would`). Pillow is needed locally and is not in `tests/requirements.txt`.
- **Source:** `tests/fault/test_debug_role.py`

### InputBox and MsgBox are standard dialogs (window class `#32770`)

- **Problem:** A test element with `InputBox(...)` returned `Cancel` in the worker after 0.12 s. The dialog guard of `ahkrun.py` had closed the window and ended the run with exit 97.
- **Wrong:** Running dialog elements under `ahkrun.py` and expecting a real result.
- **Right:** Such elements cannot be tested under the guard. Test them without the guard, or abstract the dialog away.
- **Status:** verified (probe with `ahkrun.py`, exit 97)
- **Source:** `src/elements/skeleton` (element removed again)
