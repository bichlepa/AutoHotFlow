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
