# WI-0135 Result: acceptance of S0008 (agent part, 2026-11-02)

Branch `wip/wi0135` on `v2-port` a45631b0. Status words: verified (read or run), assumed, not checked.

**Verdict.** S0008 is **not accepted**. Done: all 152 classes exist and the tests for the class list, the memory and the documents are in. Open: manual check 12 (the owner), 3 of the 16 "Automatic tests" flows are not run headless (F-9000*, owner decision), and the big tiers (stress of the whole suite, foundation, slow) are run by the orchestrator, not by this item.

## 1. Acceptance criteria

| # | Criterion (README "Acceptance S0008") | Evidence | Status |
|---|---|---|---|
| 1 | All 152 v1 classes are registered; smoke test covers all; no schema difference outside MIGRATION | `tests/test_element_classes.py` (6 tests, 152 = 152, case-insensitive); smoke test `tests/ahk/element_smoke.test.ahk`; `tests/schema/test_v1_schema.py` (allow list with M-IDs) | **met** (class list and ActsOnSystem run: 55 passed with test_groups; the smoke and schema tests ran in the work items WI-0116 to WI-0134, not rerun here) |
| 2 | Every element has end-to-end tests; elements behind the seam by the test provider; real behaviour by the owner | each of the 152 classes is named by a test that builds or runs flows (`test_every_element_class_is_named_by_a_test_that_builds_or_runs_flows`; a heuristic) | **met headless**; real behaviour: manual check 12 open |
| 3 | The 16 "Automatic tests" flows run green, `PENDING` is empty | 13 run green (`tests/integration/test_corpus.py`, run 20261102-202856-e1cdd6eb: 30 passed, 2 failed under load, both green in recheck 20261102-204256-recheck); 3 stay in `PENDING` with a reason | **not met**: F-9000* |
| 4 | Every element has its help page | `tests/test_help.py` (every element file has a help source, pages current) | **met for existence**; correctness read for the 29 core pages and by the work items for the rest (REQ-ELM-020 stays partial) |
| 5 | Demo flows are shown, run and cannot be changed; shortcut starts its flow | `tests/integration/test_demo_flows.py`, `test_demo_flows_run.py`, `tests/e2e/test_manager_demo.py`, `test_editor_demo.py`; `tests/integration/test_shortcut_trigger.py` | **met headless**; the look and the desktop shortcut: manual check 12 parts A and E |
| 6 | Memory measured again with all real classes and the editor | MS-0059, MS-0060 in `doc/MEASUREMENTS.md` (run 20261102-204556-49a76b6b): background 60.5 to 61.3 MB, with editor 79.3 to 79.8 MB; worker start median 216 ms | **met**; budget of E0040 (below 100 MB) kept; F-9002* for the pool of 8 |
| 7 | Serial, parallel, stress, foundation and slow runs are green | see section 6 | **not done by this item** (orchestrator) |

## 2. All classes and ActsOnSystem (task 2)

152 classes in v2 = 152 in v1; 26 more `.ahk` files in the folders are helpers, not classes. Every class sets `static ActsOnSystem` (tested). 78 act on the system, 74 do not.

**Acting (true), by reason.**
- Files and folders (read or write the disk): Copy_File, Copy_Folder, Create_Folder, Create_Shortcut, Delete_File, Delete_Folder, Delete_From_Ini, Move_File, Move_Folder, Read_From_File, Read_From_Ini, Rename_File, Rename_Folder, Write_To_File, Write_to_ini, Get_File_Attributes, Get_File_Size, Get_File_Time, Get_shortcut_information, Set_file_attributes, Set_file_time, Empty_Recycle_Bin, Compress_files, Extract_files, Loop_Through_Files, Condition File_Exists, File_Has_Attribute.
- Drives: Change_Drive_Label, Eject_Drive, Lock_Or_Unlock_Drive.
- Network: Download_File, HTTP_Request.
- Programs and processes: Run, Kill_Process, Set_Process_Priority, Condition Process_Is_Running (reads the process list; counted acting as v1 groups it with the process elements), AutoHotkey_script (action and trigger: runs code).
- Keys, mouse and input: Send_Keystrokes, Send_Keystrokes_To_Control, Click, Move_Mouse, Drag_With_Mouse, Get_Mouse_Position, Set_Lock_Key, Block_User_Input, Condition Key_Is_Down, Triggers Hotkey, Hotstring.
- Windows and controls: Activate_Window, Close_Window, Hide_Window, Show_Window, Move_Window, Minimize_all_windows, Get_Control_Text, Set_control_text, Condition Window_Active, Window_Exists.
- Sound and screen: Beep, Play_Sound, Stop_Sound, Speech_output, Set_Volume, Set_Screen_Settings, Screenshot.
- Clipboard: Get_Clipboard, Set_Clipboard.
- Power and session: Shutdown, Reboot_Computer, Hibernate_Computer, Suspend_Computer, Log_Off, Lock_Computer.
- Other flows and the flow itself: Execute_Flow, Set_Flow_Status, Set_element_parameter (they start, enable or change other flows, which can act on the system).
- Trigger Shortcut (writes a file and starts the program).

**Not acting (false), by reason.**
- Pure computation: Absolute_number, Exponentiation, Random_number, Rounding_A_Number, Square_Root, Trigonometry, Time_Calculation, Time_Difference, New_Time, Script (expressions only), Change_character_case, Encode_string, Get_String_Length, Search_in_a_string, Split_a_string, Split_path, Substring, Substring2, Trim_a_string, replace_in_a_string, Convert_list_to_string, Convert_string_to_list.
- Variables and lists: New_variable, New_List, Add_To_List, Delete_from_list, Get_From_List, Get_List_Info, Get_index_of_element_in_list, Shuffle_list, Do_nothing, Trace_Point, Trace_Point_Check, and the conditions Do_nothing, Expression, List_Contains_Element, NumberIs, String_Contains_Text, Variable_Is_Empty, Variable_content_is, Flow_Enabled, Flow_Running; loops Condition, Parse_A_String, SimpleLoop, Work_through_a_list.
- Only show or wait: Sleep, Tooltip, Message_Box, Input_Box, Select_file, Select_Folder (the user picks a path; nothing is written), Condition Confirmation_Dialog and Debug_Dialog, Stop_Flow (stops the own flow).
- Only read the system: Get_Drive_Information, List_drives, Get_Pixel_Color, Get_Screen_Settings, Get_Volume, Search_Image, Search_pixel; triggers Clipboard_Changes, Time_Of_Day, User_Idle_Time, Process_starts, Process_Closes, Window_Closes, Window_Gets_Active, Window_Gets_Inactive, Window_Opens, Periodic_Timer, Start_up, Manual.

Owner decision to confirm (none was needed to proceed): the reading-only elements (Get_Pixel_Color, Search_Image, Get_Volume, the file-time getters) are split by whether they read user files (acting) or the screen and settings (not acting).

## 3. Corpus (task 3)

13 flows run: variable test, List test, Loop test, Trigger test, maths test, string test, ini file test, HTTP Request, file test, external script test, User idle test, Process Test, File link test. Run 20261102-202856-e1cdd6eb (the file `test_corpus.py` at the first commit of this branch): 30 passed, 2 failed (`test_v1_process_test_runs_green_with_an_own_process`: variable not yet written under 52 to 92 % machine load; `test_6_a_loop_over_a_list_is_left_early_with_a_break`: engine did not load, load 56 to 96 %); recheck `20261102-204256-recheck` serially and alone: both green. Not hidden: both are load flakes, their run history is in `temp/history`.

Not run: Dialog test (real windows), Hotkey test (real keys), starter (starts all). `PENDING` has them with a reason; a test counts 16 = 13 + 3. Decision F-9000*.

## 4. Memory and start (task 4)

MS-0059 and MS-0060, see `doc/MEASUREMENTS.md`. Budget of E0040 is met (61 MB for the background processes with one worker). The start of a worker is 216 ms median, +66 ms against N=0 of MS-0029 (threshold +150 ms not reached). Two growth points are findings: engine 12.6 to 18.9 MB and worker 6.7 to 10.0 MB since MS-0042 (all classes are loaded), F-9002* for the pool size.

## 5. Documents (task 6)

REQUIREMENTS updated: REQ-ELM-020, REQ-ELM-270 (Evidence), REQ-TRG-200 (done), REQ-TRG-240 (partial, Evidence), REQ-DST-040, REQ-DIA-020, REQ-LNG-030, REQ-TST-030 (done), REQ-TST-040 (13 of 16), REQ-PRF-030 (done). ELEMENT-API-V2 (ActsOnSystem for all classes), ARCHITECTURE 8 (`ChildLauncher`, `ChildPipe` in `src/core`), TEST-STRATEGY 8d, MANUAL-CHECKS section 12 (39 steps) and the template line, `.vscode/tasks.json` (3 tasks). PROTOCOL and MIGRATION: read and current for WI-0133 (4.1, 4.2, 4.6, `--app-script`), WI-0134 (demo mark) and M-0179 to M-0189; no change needed (assumed complete: not read line by line). `python tools/doc_index.py --check` green.

## 6. Runs (task 8)

| Run | Result |
|---|---|
| `tests/test_element_classes.py`, `test_groups`, `test_requirements`, `test_open_items_ids` | 70 passed, 1 skipped (serial) |
| `tests/test_manual_check.py`, `tests/integration/test_manual_flows.py` | 13 passed |
| corpus file, slow (run_suite, 3 workers) | 30 passed, 2 failed under load; recheck both green |
| stress file `tests/stress/test_all_classes_start.py` (run_suite, alone) | 4 passed, run 20261102-204556-49a76b6b |
| **not run here** | the full fast tier, foundation, slow, the whole stress tier, serial run of the whole suite: the orchestrator runs them; gui tests: never by agents |

## 7. Retrospective and S0009 needs (task 7)

- **Hard:** the 26 helper files among the element files (HOW-TO), the corpus flows that need real desktop (HOW-TO), load flakes in corpus tests under a parallel verify run.
- **Files fetched by setup tools that S0009 must ship:** the WebView2 loader DLL (`tools/fetch_webview2_loader.py`, F-0186: hashes come from one download); `tar.exe` is part of Windows (not shipped); the demonstration flows (`assets/demo_flows/`), help pages (`src/elements/Default/help/`, generated HTML), language files (`src/elements/Default/language/*.ini`), icons and the GDI+ code are in the repository.
- **Minimum version of `tar.exe` (WI-0122):** the elements were tested with bsdtar 3.8.9 (libarchive 3.8.9) on Windows build 10.0.26300. `tar.exe` exists since Windows 10 build 17063. The zip, 7z, xz and lzma formats need the libarchive of the build: not checked on older builds; S0009 should name a minimum build and test one old one. A single compressed file (.gz, .bz2) is not supported by `tar.exe` (HOW-TO processes-pipes-messages).
- **Interpreter of the script elements in the compiled program (WI-0130):** the host starts `A_AhkPath` with `*` and `/ErrorStdOut=UTF-8`; in a compiled program `A_AhkPath` is the program itself, so S0009 must start the compiled exe with `/script` or ship an interpreter. Not tried.
- **Command of the shortcut trigger (WI-0133):** the shortcut runs the interpreter with the program script (`--app-script`), `--session`, `--data` and `--command=Trigger|<flow>|<element>`. The compiled program needs its own command line there (exe with the same options); it is built from `ctx.launch`.
- **Language keys missing:** package Default: ko 939, ru 983 of 1,054 (F-9001*); editor texts F-0172.
- **Open questions for the owner:** F-9000*, F-9002*, the F-0211 to F-0213 items, the manual check 12 result.

## 8. Decisions taken by the implementer

- The starter flow is not run headless (safer: it would press real keys). Alternative: a reduced test copy (F-9000*).
- The manual check 12 flows are generated with the flow builder and tested only for loading (running them headless would beep, speak and click).
- The stress test of memory is a new file and not a change of `test_background_memory.py`, so MS-0042 stays reproducible.
- `manual_check.py --flow` takes a comma list (small, needed for four flows).

## 9. Not checked

Manual check 12 (all steps); the real behaviour behind the seam; the generated flows of check 12 in the real engine (their pars follow the element schemas; the owner finds out); PROTOCOL and MIGRATION line by line; three workers or more in memory; the complete suite.
