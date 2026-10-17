# How-to AHK v2: GUI and hotkeys

Entries of this category. Entry format, rules and index: [`../HOW-TO.md`](../HOW-TO.md).

### ListView: row clicks and selection after a rebuild

- **Problem:** The ListView help names the events (`Click`, `ItemFocus`, `ItemSelect`, ...) but does not list all parameters.
- **Right:** For row clicks: `lv.OnEvent("Click", (lv, row) => ...)`. After each rebuild mark the rows again with `Modify(row, "Select Focus")`; `Delete()` without parameters clears the list.
- **Status:** assumed (event names and parameters from the help; the click itself is not automated, only the start of the window was checked in a smoke run)
- **Source:** https://www.autohotkey.com/docs/v2/lib/ListView.htm

### Closing a Gui window does not end a role (`Persistent`)

- **Problem:** A window without its own reason to keep the main loop alive ends with the last window. The role keeps running through timers and the peer, but its display could disappear by accident.
- **Right:** `Role.Start` calls `Persistent()`. The real manager only hides its window on close (`UiWindow.hideOnClose`, E0014).
- **Status:** verified (smoke run: window open, supervisor answers, `cmd.app.exit` leads to exit 0)
- **Source:** `src/manager/ManagerWindow.ahk`

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

### A local variable named like a built-in function silently calls the variable (verified)

- **Problem:** In `_Register(key, full, mode, spec)` the local `hotIf` and the built-in `HotIf()` in the same function: AutoHotkey names are case-insensitive, so `HotIf()` called the local, which was `""` for "Everywhere". The error was `This value of type "String" has no method named "Call"`, far from the cause. The same name in a helper parameter (`_SetCriterion(hotIf)`) hid it again.
- **Wrong:** Naming a local `hotIf`, `hotkey` (built-in `Hotkey`), `p` next to a global `P()` in a test. The warnings `This local variable has the same name as a global variable` are printed at load time, and the run still goes on.
- **Right:** Name the local `criterion` (or any name that is not a built-in or a global function, compared without regard to case). Run the script once with `tools/ahkrun.py` and read the warnings of `#Warn All` before running the tests.
- **Status:** verified (`src/elements/Default/Triggers/Trigger_Hotkey.ahk`, found by `tests/ahk/element_hotkey.test.ahk`; the warnings were printed by `tools/ahkrun.py` on the first run)
- **Source:** `src/elements/Default/Triggers/Trigger_Hotkey.ahk` (`_Register`, `_SetCriterion`)

### `contains` is a reserved word in AutoHotkey v2 (verified)

- **Problem:** A unit test named a variable `contains`, and the script stopped at load time with `Unexpected reserved word`. The runner then reported every case as "not reported".
- **Right:** Do not use `contains`, `and`, `or`, `not`, `is`, `in`, `isset` as variable names. Check the message `Unexpected reserved word` first when all cases of a file are missing.
- **Status:** verified (`tests/ahk/element_window_ident.test.ahk`)
- **Source:** `tests/ahk/element_window_ident.test.ahk`

### An object literal with a lambda property is called with the object as an extra argument (verified)

- **Problem:** A test double `{Guard: (fn) => fn}` raised `Too many parameters passed to function` when the element called `ctx.Guard(fn)`. The cause is assumed: a function object stored in an object property is called with different arguments than a method of a class.
- **Right:** Build a small class with methods (`class FakeCtx { Guard(fn) => fn }`) for test doubles of a context.
- **Status:** verified that the class double works (`tests/ahk/element_hotkey.test.ahk`, `FakeCtx`); the cause is assumed
- **Source:** `tests/ahk/element_hotkey.test.ahk`

### An open menu stops timers and usually a running thread, but not the pings (verified)

- **Problem:** The AHK v2 docs say that a thread is uninterruptible while a menu of the script is shown (`misc/Threads.htm`, "Thread Interruptibility"), that timers do not run "when the user is navigating through one of the script's menus" (`lib/SetTimer.htm`), and that a posted message above 0x0311 may not be buffered while a menu's modal loop runs (`lib/OnMessage.htm`). The supervisor's tray menu (E0064) rests on the assumption that an open menu blocks nothing; the owner's check (2026-10-17) covered only an idle stub manager with the menu open for 10 s.
- **Right:** Measured with `tools/tray_menu_probe.py` (results in `doc/MEASUREMENTS.md`, "Open menus in a running process"): with light load (20 wake messages per second) a pinged process answers all of them while its tray or Gui menu is open. Its timers stop for the whole time of the menu (one tick in 6 s), and they stop for good while the user navigates. A running thread went on in one of five runs with a passive tray menu, and stalled in the other four and in every navigated run. Under a flood of wake messages (300 per second) the handling of the messages stopped until the menu closed. Plan for it: the hub does not run timers or threads of the process while a menu is open, so a tray or Gui menu in a process that must keep working (the supervisor) is only safe while the menu is short and the load is light. Do not rely on "a menu blocks nothing".
- **Not checked:** a menu open for minutes, several menus at once, a menu under a real user's navigation with the mouse (the probe uses Esc and three Down keys), other Windows versions. The mechanism is not known (assumed: a Gui menu runs as a new thread that interrupts the running one).
- **Consequence (E0075):** the tray icon and menu of the application are the role `tray`'s own process, so a menu never stops the supervisor. The idle tray role answered pings during an 8 s menu (longer than the pong timeout) and was not judged hung (gui test `tests/fault/test_tray_role.py`, one run). The context menus of the manager (WI-0074) still stop the manager's own threads.
- **Status:** verified (probe runs of WI-0072, one run per case, five for the passive tray case; the flood cases are one run each)
- **Source:** `tests/ahk/helpers/tray_menu_probe.ahk`, `tools/tray_menu_probe.py`, `doc/MEASUREMENTS.md`

### Standard dialogs (`FileSelect`, `DirSelect`, `MsgBox`) keep the message handling going, but stall the timers (verified)

- **Problem:** A UI role must answer `sys.ping` while a file or folder dialog is open. Those dialogs block the calling thread until the user answers. The question was whether the message handling and the timers of the same process keep running meanwhile.
- **Wrong:** Assuming that a blocked thread blocks the whole process, or that the timers work during a standard dialog as they do otherwise.
- **Right:** Measured with `tests/ahk/helpers/modal_spike.ahk` (`python tools/ahkrun.py --no-dialog-guard --timeout 40 tests/ahk/helpers/modal_spike.ahk <mode> 10000`): a ping posted every 500 ms to the script window (WM_AHF_WAKE) and a tick timer every 100 ms ran while the dialog was open for 10 s; the script closed the dialog itself. Results (one run each, `FileSelect` twice):
  - `none` (baseline): 20 pings answered, 91 ticks, longest tick gap 0 ms.
  - `FileSelect`: all pings answered (max answer latency 47 ms and 32 ms), 85 and 86 ticks, longest tick gap 718 ms and 640 ms.
  - `DirSelect`: all pings answered (max latency 16 ms), 89 ticks, longest tick gap 250 ms.
  - `MsgBox` (own timeout 10 s): all pings answered (max latency 0 ms), 91 ticks, longest tick gap 140 ms.
  So the pings are answered, but the timers stall for up to 0.7 s, and the thread that opened the dialog waits for the answer. Rule 3 still forbids standard dialogs on the message path: the answered pings do not show that nothing blocks there. The window class of all three is `#32770`; for `DirSelect` the window title is "Ordner suchen" (German Windows).
- **Status:** verified (one probe, 5 runs on this machine, Windows 11 with German UI; the dialog was closed by the probe with `WM_CLOSE`). Not checked: other Windows versions, a dialog opened from an element worker, a dialog at a DPI above 100 %, a dialog while the process is under load.
- **Decision (WI-0069):** `ui_common/` does not use the standard dialogs but its own non-blocking dialogs (`UiDialogs.ahk`). A UI role may use `FileSelect`/`DirSelect` for a dialog the user opened (E0076), only through `ui_common/UiFileDialogs.ahk`; the timer stall of up to 0.7 s is accepted there. `MsgBox` and `InputBox` stay replaced by `UiDialogs`.
- **Source:** `tests/ahk/helpers/modal_spike.ahk`, `tools/ahkrun.py` (`--no-dialog-guard`)

### A Gui created and closed without Show leaves no window and no remembered place (verified)

- **Problem:** The window base of the UI roles (`ui_common/UiWindow.ahk`) creates its `Gui` in the constructor, but it must not remember a position for a window that was never shown (the position of a hidden window is not a place the user chose).
- **Right:** A flag set by `Show` decides whether `Close` remembers the position (`UiWindow._shown`). A `Gui` created and destroyed without `Show` leaves no window behind, and the texts registered for it are removed again with `UiTexts.Forget`.
- **Status:** verified (probe with `tools/ahkrun.py`: create, place, register a text, close, close again; the registry is empty after the close and nothing is remembered; no window was shown). Not checked: the position and size of a shown window after a restart or a DPI change (owner's check, WI-0073/WI-0076).
- **Source:** `src/ui_common/UiWindow.ahk`

### A field and a method whose names differ only in case make the constructor fail with "Property is read-only" (verified)

- **Problem:** `ManagerModel` had a method `Trace(since)` and a field `this.trace := []`, and a method `TraceOn()` and a field `this.traceOn := false`. AHK v2 names are case-insensitive, so the assignment in `__New` hits the method property of the class and throws `Error: Property is read-only.` The role then ends with "manager failed to start", and the message does not name the property.
- **Wrong:** Naming a field like a method and relying on the different case (it is fine in languages with case-sensitive names).
- **Right:** Give fields and methods names that differ by more than case (`traceLog`, `recording`). When a constructor fails with "Property is read-only", look for a field that has the name of a method of the class or of its base class (for a `Role`, also the methods of `Role`).
- **Status:** verified (two failed runs of `tests/e2e/test_manager.py`, green after the rename, run 20261017-141607-14108).
- **Source:** `src/manager/ManagerModel.ahk`

### The close box hides a window only when its Close handler hides it and returns 1 (verified)

- **Problem:** The manager must stay alive when the user closes its window (E0014), and the window must come back at the same place and size.
- **Right:** `UiWindow` has `hideOnClose`: the Close event calls `Hide()` (remembers the place, `Gui.Hide()`) and returns 1, so Windows does not destroy the window; `Show()` later puts it back with `GuiLayout.Show`. A minimized or maximized window is not remembered (its position is not the one of the normal window).
- **Status:** verified (`tests/fault/test_manager_window.py`, run 20261017-142607-22544: WM_CLOSE hides the window, the process and the application run on, `cmd.manager.show` shows it again). Not checked: a window that was minimized when it was hidden.
- **Source:** `src/ui_common/UiWindow.ahk`

### `this.callback()` on a function stored in a property passes `this` as the first argument (verified)

- **Problem:** `UiWindow.Hide` called `this.onHide()` where `onHide` held a closure `() => ...`. AHK v2 treats `obj.name()` as a method call and passes `obj` as the first parameter, so the call failed with a parameter error inside the Close event: the window stayed visible, and the process snapshot showed no error (`errors.count` 0).
- **Right:** Copy the function object first (`hook := this.onHide`, then `hook()`), or give the closure a `*` parameter. A probe script with `tools/ahkrun.py` shows the error dialog that the role hides.
- **Status:** verified (probe script and `tests/fault/test_manager_window.py`, run 20261017-144622-6636).
- **Source:** `src/ui_common/UiWindow.ahk`

### Events of a tree that is built again arrive late; do not clear the selection in them (verified)

- **Problem:** The manager rebuilt its TreeView (`Delete()`, `Add()`, `Modify(..., "Select")`) in a timer on every model change, with a `filling` flag so the `ItemSelect` handler ignored the events of the rebuild. The user's selection still vanished within a second, and the Run button went disabled. A timer thread is uninterruptible for its first 15 ms (`Thread "Interrupt"`), so the GUI events of the rebuild were queued and ran after the timer function had ended: `filling` was `false` again, and the item IDs of the event no longer existed.
- **Wrong:** Trusting the `item` parameter of the event; guarding by a flag that is only set while the timer function runs; rebuilding the tree for changes that do not touch it (a flow state).
- **Right:** In the handler read the current selection with `tree.GetSelection()` and ignore the parameter. Rebuild only when the content changes (snapshot, categories). Same applies to other controls that raise events from a script-made change (`ListView`, `DropDownList`).
- **Status:** verified by the owner's manual check (2026-10-17); the regression test `tests/fault/test_manager_window.py::test_the_selection_survives_a_flow_run_and_the_run_button_stays_enabled` is a gui test and not run by an agent.
- **Source:** `src/manager/ManagerWindow.ahk`

### A tree drag is started by TVN_BEGINDRAG; the drop is found by a timer that reads the mouse button (assumed)

- **Problem:** The manager needs drag and drop of flows and categories in its TreeView. AutoHotkey has no drag event for a TreeView.
- **Right:** `OnMessage(0x4E, ...)` catches the WM_NOTIFY of the tree with code -456 (`TVN_BEGINDRAGW`, `lParam` is the NMHDR: the control handle at offset 0, the code at `2 * A_PtrSize`). The item under the cursor is found with `TVM_HITTEST` (0x1111) on the cursor position in client coordinates (`GetCursorPos`, `ScreenToClient`); the hit item is at offset 16 (64 bit) or 12 (32 bit) of the `TVHITTESTINFO`. A `SetTimer` of 30 ms ends the drag when `GetKeyState("LButton", "P")` is false, so no mouse capture is needed.
- **Status:** assumed (written in `src/manager/ManagerWindow.ahk`; the gui test `test_a_flow_dragged_onto_a_category_moves_into_it_and_the_engine_keeps_it` was run once and failed before the drag, at a setup step; the drag itself was not run). Not checked: the drop on a screen with a high DPI, a drag that leaves the tree.
- **Source:** `src/manager/ManagerWindow.ahk`, `tests/fault/test_manager_window.py`

### TVM_GETITEMW returned 0 for a tree item in a test helper; the cause is not found (not checked)

- **Problem:** A helper of the gui test read the text of a tree item with `TVM_GETITEMW` (0x113E) and a `TVITEMW` buffer (mask, hItem at 8, pszText at 24 on 64 bit). The message returned 0 for items that `TVM_GETNEXTITEM` had just returned.
- **Wrong:** Trusting the offsets alone; the test had no other way to read the text.
- **Right:** Probably the same cause as the entry below: `TVITEMW` and its text buffer are pointers into the test process, which Windows does not translate for a tree of another process. Not retried with remote memory. The helper was removed.
- **Status:** assumed (cause by analogy with the TVM_GETITEMRECT entry, which was verified; the text read itself was not retried).
- **Source:** `tests/fault/test_manager_window.py` (the helper is gone)

### A Ctrl click in a TreeView is read in the ItemSelect handler with GetKeyState (assumed)

- **Problem:** A multi-selection (several flows) needs the Ctrl key at the moment of the click. The TreeView itself selects one item only.
- **Right:** In the `ItemSelect` handler read `GetKeyState("Ctrl", "P")`; the model keeps the set of the selected flows, the native selection shows the focused item. A late event of a rebuilt tree is ignored by comparing the item with the model (see the entry above).
- **Status:** assumed (the model side is tested headless, `tests/e2e/test_manager_flows.py::test_ctrl_click_selects_several_flows_and_the_operations_act_on_them`; the Ctrl click itself is not automated). Not checked on screen: the item marks of the set (open finding F-0119).
- **Source:** `src/manager/ManagerWindow.ahk` (`_OnTreeSelect`), `src/manager/ManagerModel.ahk` (`SelectToggle`)

### TVM_GETITEMRECT (and other messages with a pointer) returns 0 for a tree of another process (verified)

- **Problem:** A gui test asked the tree of the manager process for the rectangle of a flow item (to drag it with the mouse). `TVM_GETITEMRECT` returned 0 ("no rect"), even for a visible, expanded item, while `TVM_GETNEXTITEM`/`TVM_GETCOUNT` worked.
- **Wrong:** Passing `ctypes.addressof(buffer)` of the test process as lParam. Windows marshals the pointer only for a few standard messages, not for common-control messages; the address means nothing in the other process.
- **Right:** Allocate the RECT in the process that owns the tree (`VirtualAllocEx`, `WriteProcessMemory` with the item handle in the first pointer-size bytes, send, `ReadProcessMemory`, `VirtualFreeEx`). Set `argtypes` for the kernel32 calls (64-bit pointers).
- **Status:** verified (`tests/fault/test_manager_window.py`: 7 gui tests pass; the drag test fails when the drop target is the start position).
- **Source:** `tests/fault/test_manager_window.py` (`_remote_item_rect`)

### A tray notice (TrayTip) is shown by the process that owns the tray icon (assumed)

- **Problem:** The notices of the engine should appear as tray notices. The supervisor has no icon; the icon belongs to the tray role.
- **Wrong:** Calling `TrayTip` in the supervisor, or in any role without an icon of its own. The balloon is attached to the icon of the calling script, and a script without an icon has none to attach it to.
- **Right:** The tray role subscribes to the notice topic and calls `TrayTip` itself (`src/tray/Tray.ahk`, `_OnNotice`), at most one per 5 s; headless it only counts.
- **Status:** assumed (the rule of the icon owner is from the Windows shell documentation as remembered; no test shows a real balloon, the headless tests count only). Not checked: the balloon on a real desktop.
- **Source:** `src/tray/Tray.ahk` (`_OnNotice`), `tests/integration/test_notices.py::test_an_unhandled_exception_gives_one_notice_marks_the_flow_and_reaches_the_tray`

### A Text control is clipped to its newlines when its height is counted from them (verified)

- **Problem:** The question dialogs of the manager showed only the first line of a text. The text is one line in the language file but wraps at the dialog width; the height was counted from the newlines (one line), so the control was 20 px for two lines of text.
- **Wrong:** Computing the height of a wrapped text from the number of lines (`` `n `` count) or from a fixed height per line. Such a height is right only for texts that the author has already broken into lines.
- **Right:** Measure the text as the control wraps it: `DrawTextW` with `DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX` (0xC10), the font of the control and the width of the control; the return value is the height of the text (the rectangle is not changed). Convert it to the 100 % sizes of the layout. In a probe, read the control with `ControlGetPos` (`Static1`) to compare the two heights.
- **Status:** verified at 96 dpi (`src/core/GuiLayout.ahk` `TextHeight`; probe `tests/ahk/helpers/ui_dialog_text.ahk` with `tools/ahkrun.py`: the delete question gave a 20 px control before the fix, 30 px (two lines of 15 px) after it; unit cases in `tests/ahk/core_gui_layout.test.ahk`). The gui test compares in pixels at the dialog DPI, so it discriminates at 96 dpi (run here) and, by the same arithmetic, at 225 % (old control 45 px, two lines about 68 px; not run). Not checked: the same control at 225 % on a real display.
- **Source:** `src/core/GuiLayout.ahk`, `src/ui_common/UiDialogs.ahk`

### The default button of a question was the first one, so a preselected "No" put No on the left (verified)

- **Problem:** The three questions of the import that are preselected "No" (`importCopies`, `autostartV1`, `importWarning`) were built with the buttons in the order No, Yes, because the default button of a Confirm was the first one in the list. Every other question of the manager shows Yes left, No right. The order of the buttons was used as the preselection, so the two could not be set apart.
- **Wrong:** Expressing the preselection by the order of the buttons (the first button gets the Enter key).
- **Right:** The buttons of a question stand in one fixed order, and the default is a flag on the button: `[id, labelKey, true]` (`UiDialogs.DefaultIndex`, pure, unit-tested in `tests/ahk/ui_common_dialogs.test.ahk`; the order per question in `ManagerWindow.ConfirmButtons`, `tests/ahk/manager_window.test.ahk`). Without any flag the first button is the default, as before.
- **Status:** verified by the unit tests (the Yes/No order of all manager questions and the default of each); the look of the dialog is not checked by hand (not checked).
- **Source:** `src/ui_common/UiDialogs.ahk` (`Confirm`, `DefaultIndex`), `src/manager/ManagerWindow.ahk` (`ConfirmButtons`)
