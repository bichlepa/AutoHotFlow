# WI-0111 Help window: viewer interface, Shell.Explorer, browser, the setting

Size: M · Depends on: WI-0106 (the help button), WI-0112 (the first generated pages; a test page is enough to start) · Blocks: WI-0115, WI-0114

## Goal

The help is shown in a window of its own (E0098) through a viewer interface with three viewers (E0099). This package brings the interface, the classic viewer (`Shell.Explorer`, the browser control of Windows) and the option to open a page in the default browser; WI-0115 adds WebView2. A setting chooses the viewer. The help opens from the element settings, the manager and the editor. Requirements: REQ-LNG-040 (the window).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0075, E0098, E0099, E0100; `doc/ARCHITECTURE.md` 3 (roles); `doc/PROTOCOL.md` 4.2 (settings), 4.10 (the tray role as the pattern of a small role); `src/core/SettingsModel.ahk`, `src/manager/SettingsForm.ahk`; `doc/howto/gui-and-hotkeys.md` (DPI); v1: `v1/Source_Editor/User Interface/Help.ahk`.

## Tasks

1. **Docs first:**
   - PROTOCOL 4.2 gets the setting `helpViewer` (`auto`, `webview2`, `classic`, `browser`; default `auto`).
   - ARCHITECTURE 3 and 8 say where the help window lives: a role `help` of its own (one window for the application, started on demand by the supervisor like the tray role, so a hang of a browser engine does not touch an editor) or the editor process. Propose it and document it; the role is the default proposal.
   - PROTOCOL gets the message that opens a page (for example `cmd.help.show {page}`).
2. **Viewer interface:** `Navigate(path, anchor?)`, `Back()`, `Resize()`, `Close()`, and an event when a link is followed. The window (index, back, links between pages, an element page by its class) talks only to the interface.
3. **Classic viewer:** `Shell.Explorer` in its newest document mode (the generated pages carry `X-UA-Compatible: IE=edge`). Check the look at 100 % and 225 %; if the control does not scale, make it scale and write a HOW-TO entry.
4. **Browser:** `browser` opens the generated page in the default browser (`Run` of the file URL) and shows no window of our own.
5. **Choice:** `auto` takes WebView2 when WI-0115 says it is available, else the classic viewer. `webview2` falls back to the classic viewer with a log line when WebView2 cannot start. The settings dialog of the manager (WI-0078) gets the field.
6. **Opening:** from the settings dialog (Help: the page of the element, next to the dialog as in v1), from the manager (menu entry Help) and from the menu bar of the editor (Help).
7. **Language:** the page in the language of the user interface, else English (v1).
8. **Tests:** a headless model (which page for which element, language and setting; the fallback); `cmd.test.*` of the role; a gui test (owner) of the classic viewer and the browser option.

## Acceptance criteria

- The tests of task 8 are green (gui: written). PROTOCOL and ARCHITECTURE are updated. REQ-LNG-040 is updated.

## Not part of this

The WebView2 viewer (WI-0115); the content and the generator of the pages (WI-0112); translations (S0009).
