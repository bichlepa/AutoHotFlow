# WI-0120 Files and folders I: read, write, copy, move, rename, delete, exists

Size: L · Depends on: WI-0116 · Blocks: WI-0121, WI-0125 (corpus "file test"), WI-0133, WI-0135

## Goal

The basic file and folder elements of v1 exist in v2. Every element that touches a file is a worker (rule `inline-element`); `Action_Split_path` only computes. Requirements: REQ-ELM-300 (these rows).

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Read_From_File` | worker | encodings of v1 (`FileRead` with options) |
| `Action_Write_To_File` | worker | append or overwrite, encoding, line ends |
| `Action_Copy_File` | worker | wildcards, overwrite; the help has `%name%` examples (WI-0112 list) |
| `Action_Move_File` | worker | the same |
| `Action_Rename_File` | worker | |
| `Action_Delete_File` | worker | wildcards; to the recycle bin if v1 had the option |
| `Action_Create_Folder` | worker | |
| `Action_Copy_Folder` | worker | |
| `Action_Move_Folder` | worker | |
| `Action_Rename_Folder` | worker | |
| `Action_Delete_Folder` | worker | with or without contents |
| `Condition_File_Exists` | worker | |
| `Action_Split_path` | inline | `SplitPath`, no file access |

## Read first

The common part of the element packages (README S0008); `doc/ELEMENT-API-V2.md` 3.1 (the `file` and `folder` field types: a relative path is below the working directory of the flow); `src/elements/base/ParamEvaluator.ahk`; AutoHotkey docs: `FileCopy`, `FileMove`, `DirCopy`, `DirMove`, `FileDelete`, `DirDelete`, `FileRead`, `FileAppend`, `FileOpen`, `FileExist`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **Errors:** the number of files that failed (v1 reported it), a missing source, a target that exists, a file in use, a path that is too long; each is an `exception` with the v1 text or a clear v2 text (MIGRATION).
2. **Tests** in a temporary folder of the test only (never the user's folders); a file in use is made by the test itself.

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

Attributes, sizes, times, shortcuts, the file loop and ini files (WI-0121).
