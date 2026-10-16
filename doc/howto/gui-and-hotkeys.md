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

### A Gui window needs a DPI awareness set before it is created (assumed)

- **Problem:** The real dialogs of the dialog elements must be sharp and correctly sized on a display with a scaling above 100 %. An AutoHotkey script is DPI unaware by default, so Windows scales its windows as bitmaps.
- **Wrong:** Creating the `Gui` and assuming it is sharp.
- **Right:** Before the first `Gui` of the thread: `DllCall("user32\SetThreadDpiAwarenessContext", "ptr", -4, "ptr")` (per monitor V2). Wrapped in `try`, because older Windows versions lack the function. It is only a claim until the owner has looked at the window at a scaling above 100 % (WI-0056 manual check).
- **Status:** assumed (the call is in `src/elements/base/DialogWindow.ahk`; no run on a scaled display)
- **Source:** `src/elements/base/DialogWindow.ahk`

### Per-monitor DPI awareness scales only the title bar, not the controls (verified by the owner, fix assumed)

- **Problem:** With `PER_MONITOR_AWARE_V2` and fixed pixel sizes, the text stays small, the window keeps its pixel size and the title bar grows with the scale. The client area shrinks and the lowest button is pushed out. Changing the scale while the window is open resizes the window but not the controls: empty space when it grows, cut off controls when it shrinks (manual check 3, screenshots of 2026-10-16).
- **Wrong:** Hard-coded pixel sizes (`x12 y12 w260`, `Show("w690 h430")`): Windows does not move or resize the controls of a Gui. Scaling them yourself and leaving the default `DPIScale` on is also wrong: AutoHotkey then scales again with `A_ScreenDPI` of the process start, so the window is double scaled when the process started at 225 % and wrong when the DPI changed after the start (owner's check, 2026-10-16).
- **Right:** Create the Gui with `-DPIScale` (pixels are then real pixels). Keep all sizes at 100 % in a list, scale them by `GetDpiForWindow / 96`, set the font again (`CreateFontW` with `-9 * dpi / 72`, `WM_SETFONT`) and show the window with the scaled client size (`Show("w.. h..")` is the client area). React to `WM_DPICHANGED` (`g.OnMessage(0x02E0, ...)`): apply the layout again and size the window with `AdjustWindowRectExForDpi`; return 0 so Windows does not resize it a second time.
- **Also wrong:** `Show("w.. h..")`, `Show("Center")` and even a `Show()` without options size the window again with the title bar and frame of the DPI that the process had at its start. The size is wrong whenever the DPI at the opening differs from the DPI at the process start, and right again after a DPI change. **Right:** show the window hidden (`Show("Hide Center w.. h..")`), set the outer size with `AdjustWindowRectExForDpi` and `SetWindowPos`, center it again with `Move`, and make it visible with `ShowWindow(hwnd, SW_SHOW)` and `WinActivate`, not with another `Show`.
- **Status:** verified by the owner (manual check 3 on 2026-10-16: message box, debug dialog and tooltip at 100 % and 225 %, with the process started at either; opening and changing the DPI while the window is open; no flicker seen when opening)
- **Source:** `src/elements/base/DialogWindow.ahk` (`_Apply`, `_OnDpiChanged`)
