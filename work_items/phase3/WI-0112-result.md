# WI-0112 result: help content (S0007)

Branch `wip/wi-112`. Acceptance: the tests of task 6 are green (`tests/test_help.py`, 39 tests); the list of task 7 is below; ELEMENT-API-V2 section 2 and REQ-ELM-020, REQ-LNG-040 are updated.

## What was built

- **Layout:** element pages in `src/elements/Default/help/en/<Kind>/<Name>.md` (`<Name>` = class name without the kind prefix); general pages in `assets/help/en/`; one stylesheet `assets/help/help.css`, copied into every generated page, so each page is self-contained.
- **Generator:** `tools/gen_help.py` (Markdown to HTML, `--check` fails on a missing, stale or superfluous page, a broken link or a missing title). VS Code tasks: generate, check, and the one-time converter.
- **Conversion:** `tools/convert_v1_help.py` converted 149 element pages and 4 general pages (Welcome, Variables, Key list, Color chart; the last three from the owner's working copy, see F-9000*).
- **Core set:** the 29 pages of the core set (README, S0002) are corrected for v2 by reading against each element (parameters, results, MIGRATION places). `Variables.md` is rewritten for the v2 expression language.

## List for S0008 (task 7)

Found by a grep for `%name%`, `AutoHotkey` and `thread`, not by reading. The other pages are converted and unchecked. One line per page:

- `Actions/AutoHotkey_script.md`, `Triggers/AutoHotkey_Script.md`: code is AutoHotkey v1 (M-0049, E0039); "thread" wording.
- `Actions/Block_User_Input.md`, `Click.md`, `Drag_with_mouse.md`, `Move_Mouse.md`, `Send_Keystrokes.md`, `Triggers/Hotstring.md`: mention AutoHotkey; check key and command names against v2.
- `Actions/Copy_file.md`, `Copy_folder.md`, `Move_File.md`, `Move_Folder.md`, `Delete_folder.md`, `Set_file_attributes.md`, `Run.md`: `%name%` in examples; check what v2 does with `%` in text fields.
- `Actions/Split_a_string.md`, `Trim_a_string.md`: `%a_space%`-style examples in the fields.

## Not done or not checked

- The 120 non-core pages were not read one by one; the list above is only a search.
- The Key list (60 KB) was not read in full.
- No viewer was run: the look in the classic viewer, WebView2 and a browser is not checked (WI-0111, WI-0115).
- No MIGRATION entry: the deviations the core pages describe are already in M-0024 to M-0067 (M-0038, M-0047, M-0049, M-0051, M-0060, M-0065, M-0067).
