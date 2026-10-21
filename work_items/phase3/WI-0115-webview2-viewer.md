# WI-0115 Help viewer with WebView2

Size: L · Depends on: WI-0111 · Blocks: WI-0114

## Goal

The help window shows its pages with WebView2 (the engine of Edge) when the loader DLL and the runtime are available, behind the viewer interface of WI-0111 (E0099). When either is missing, the classic viewer is used. Requirements: REQ-LNG-040 (the look of the help).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0085 (own wrappers, no third-party library), E0099; WI-0111 (result: the viewer interface); AHK v2 docs `lib/ComCall.htm`, `lib/CallbackCreate.htm`, `lib/DllCall.htm`; the WebView2 documentation of Microsoft (`CreateCoreWebView2EnvironmentWithOptions`, `ICoreWebView2Controller`, `ICoreWebView2`).

## Tasks

1. **Spike first:** create an environment, a controller and a view in a Gui window from AutoHotkey v2 with an own small COM wrapper (`ComCall`; the completion handlers as COM objects built with `CallbackCreate`), and navigate to one generated page. Record what was hard in the HOW-TO. If this cannot be done in a few days of work, stop and report: the classic viewer stays the only embedded one.
2. **The loader DLL:** `WebView2Loader.dll` (x64) from the NuGet package `Microsoft.Web.WebView2`, a pinned version. `tools/fetch_webview2_loader.py` downloads it, checks its SHA-256 and puts it into a folder that git ignores (proposal `assets/bin/`), with a VS Code task `Setup: ...`. Shipping it with the program is S0009 (R0007). Check the license of the redistribution and record it in the result (assumed: allowed by the WebView2 SDK license).
3. **Availability:** "available" means the DLL loads and a runtime is found (`GetAvailableCoreWebView2BrowserVersionString`). The answer is cached for the process; WI-0111's choice `auto` asks it.
4. **The viewer:** the interface of WI-0111 (navigate, back, resize, close, link event), the DPI of the window, a user data folder below the data folder of AutoHotFlow (`WebView2/`), no access to the network (the pages are local; a link to the web opens in the default browser).
5. **Errors:** every COM call under `try/catch`; a failure at start or later falls back to the classic viewer with a log line; the help window never crashes the role.
6. **Tests:** the availability check headless (with and without the DLL); a gui test (owner): the same three pages as in WI-0111, at 100 % and 225 %.

## Acceptance criteria

- The spike reached the stop or the viewer works; the tests of task 6 are green (gui: written); the HOW-TO has the COM and WebView2 entries; the setup task exists.

## Not part of this

Shipping the DLL (S0009); other uses of WebView2 in AutoHotFlow.

## Refinement from WI-0104 (proposal, not decided)

Written by the acceptance of S0006 (WI-0104, E0095). The project owner decides whether this stands; the package may refine it again and says so in its result.

- The spike decides on a COM wrapper of our own; if it stops, the classic viewer and the browser stay (the plan says so). Do not let the spike touch the editor's files.

## Result (haiku, 2026-10-21)

- **Spike (task 1): reached, worked.** The WebView2 runtime 155.0.4283.62 is on the test machine. Environment, controller, a
  generated page (`assets/help/en/Welcome.html`) and the title read back in a real window. The COM calls use the vtable
  of `WebView2.h` (1.0.2739.15), position + 3. Recorded in `doc/howto/com-and-native-calls.md`. The spike script is in
  `temp/wv2-spike/` (git-ignored, not committed).
- **Loader (task 2):** `tools/fetch_webview2_loader.py` (pinned 1.0.2739.15, SHA-256 of the package and of the DLL taken
  from the first download of nuget.org, not verified against a second source), VS Code task `Setup: WebView2 loader DLL`,
  DLL into `assets/bin/` (git-ignored). License: `LICENSE.txt` of the package allows binary redistribution with the
  copyright notice (verified in the file). Shipping is S0009.
- **Availability (task 3):** `WebView2Loader.Available` (DLL loads, both exports, runtime version), cached per process;
  `auto` asks it (HelpPages.WebView2Available). A start failure sets `webviewBroken` in the role.
- **Viewer (task 4):** `WebView2Viewer` behind the viewer interface (Navigate, Back, Resize, Close, onLink); user data
  folder `<data>/WebView2`; navigation to anything but `file:` is cancelled, web links open in the default browser; the
  location reaches onLink through `SourceChanged`. Checked once in a real window: index and a second page loaded, the
  location followed, the runtime created the folder. Checked once with the loader not loaded: the classic viewer shows the
  page, the role gets the reason.
- **Errors (task 5):** every COM call under try/catch; a failure at the start or later replaces the viewer with the classic
  one and logs `a0`; a callback never fails the COM caller (`ComHandler`).
- **Tests (task 6):** headless: `tests/ahk/help_webview2.test.ahk` (handler vtable, loader check, failure once),
  `tests/test_webview2_loader.py` (tool: hashes, refusals, redirect, task). Gui (owner, not run by the agent):
  `tests/fault/test_help_webview2_gui.py` with its VS Code task. The 100 % / 225 % check is the owner's.
- **Decisions taken here:** the COM wrapper stays (the spike worked, so the proposal of the WI-0104 refinement is not
  needed). The user data folder is created by the runtime, not by the role (rule `file-io`). Links: only http and https
  open in the default browser; other navigations are cancelled.
- **Not checked:** a link to the web in a page (no page has one), a request for a new window (target=_blank: not
  handled, the runtime would open a window of its own), the 100 % and 225 % look, the memory of the handlers (not freed on
  purpose), a stop of the window while WebView2 starts.
