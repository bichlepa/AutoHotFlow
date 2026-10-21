# WI-0121 Files and folders II: attributes, sizes, times, shortcuts, recycle bin, file loop, ini files

Size: L · Depends on: WI-0117 (recycle bin), WI-0120 · Blocks: WI-0125 (corpus "file test"), WI-0135

## Goal

The remaining file elements, the loop over files and the ini elements of v1 exist in v2. The loop is the first worker loop: the worker job learns its entry point. Requirements: REQ-ELM-300 (these rows), REQ-ELM-240 (`Loop_Loop_Through_Files`), REQ-ELM-310 (ini).

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Get_File_Attributes` | worker | |
| `Action_Set_file_attributes` | worker | the help has `%name%` examples (WI-0112 list) |
| `Condition_File_Has_Attribute` | worker | |
| `Action_Get_File_Size` | worker | units of v1 |
| `Action_Get_File_Time` | worker | modified, created, accessed |
| `Action_Set_file_time` | worker | |
| `Action_Create_Shortcut` | worker | `FileCreateShortcut` with icon, arguments, working folder, run mode |
| `Action_Get_shortcut_information` | worker | `FileGetShortcut` |
| `Action_Empty_Recycle_Bin` | worker | through `SystemOps` (E0103) |
| `Loop_Loop_Through_Files` | worker | files, folders, recursion; the loop variables of v1 (`A_LoopFileName`, ...) |
| `Action_Read_From_Ini` | worker | a key, a section, all sections (v1 modes) |
| `Action_Write_to_ini` | worker | |
| `Action_Delete_From_Ini` | worker | |

## Read first

The common part of the element packages (README S0008); `doc/ELEMENT-API-V2.md` 7.1 (loop elements); `src/elements/Default/lib/LoopOps.ahk` and `Loop_Work_through_a_list` (the copy of the list at the head, one member per pass); `src/engine/Executor.ahk` (`_Dispatch`, `_DispatchWorker`), `src/worker/Worker.ahk`; `doc/PROTOCOL.md` 4.5 (`cmd.worker.run`).

## Tasks

The common tasks (README S0008) for every class, and:

1. **Entry point in the worker job:** `cmd.worker.run` carries the entry point of a loop (`env.entryPoint`), and the worker sets `ctx.entryPoint`; PROTOCOL 4.5 and ELEMENT-API-V2 7.1 say so. A test with a worker loop of the test package checks `head`, `tail` and `break`.
2. **The file loop** lists the files at the head once (one worker job) and keeps the list in a hidden loop variable as the list loops do, so a pass costs one job and no new listing; files created in the body do not change the passes (as the list loops, MIGRATION if v1 differed). Measure the cost of a pass and write it into the result.
3. **Ini files:** the encodings v1 wrote (UTF-16 with BOM by `IniWrite`), a missing file or key gives the default or the v1 error.
4. **Tests** in a temporary folder of the test only; shortcuts in that folder, never on the desktop.
5. **Corpus:** "ini file test" (`Flow 1587447767`).

## Acceptance criteria

Those of every element package (README S0008), and the test of task 1 is green.

## Not part of this

Watching a folder for changes (REQ-TRG-280, later).
