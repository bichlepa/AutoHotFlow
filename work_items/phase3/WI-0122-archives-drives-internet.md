# WI-0122 Archives, drives, internet

Size: L · Depends on: WI-0117 (drives); corpus "HTTP Request": WI-0119 · Blocks: WI-0134, WI-0135

## Goal

The archive, drive and internet elements of v1 exist in v2, as workers. Archives use `tar.exe` of Windows instead of the `7za.exe` of v1. Requirements: REQ-ELM-320, REQ-ELM-330, REQ-ELM-340.

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Compress_files` | worker | `tar.exe`; the formats of v1 (zip, 7z, xz, tar, gzip, BZIP2) |
| `Action_Extract_files` | worker | `tar.exe`; also Z and lzma, `*` = by the file |
| `Action_List_drives` | worker | `DriveGetList` with the types of v1 |
| `Action_Get_Drive_Information` | worker | |
| `Action_Change_Drive_Label` | worker | through `SystemOps` (E0103) |
| `Action_Eject_Drive` | worker | through `SystemOps`; v1 had its own `DllCall` code for USB drives |
| `Action_Lock_Or_Unlock_Drive` | worker | through `SystemOps` |
| `Action_Download_File` | worker | `JobTimeoutMs` or a timeout parameter; the target is a `file` field |
| `Action_HTTP_Request` | worker | WinHttp (COM) with the options of v1: method, headers, post data from a variable or a file, response to a variable or a file, proxy, user agent, code page |

## Read first

The common part of the element packages (README S0008); `src/storage/ArchiveTar.ahk`, `ArchivePack.ahk`, `ArchiveUnpack.ahk` (WI-0081: how `tar.exe` is called and its output read; F-0131 on names outside the ANSI code page; storage code, so it is read, not included); `doc/howto/` entries on COM; AutoHotkey docs: `RunWait`, `ComObject`, `Download`, `DriveGetList`, `DriveGet*`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **`tar.exe`:** a shared library in `lib/` that runs `tar.exe` without a window, waits in the worker, reads its exit code and its error output, and refuses names that it cannot pass. Check every v1 format for writing and reading; a format that `tar.exe` cannot do is a MIGRATION entry (this machine: bsdtar 3.8.9 writes 7z, zip, gz, bz2, xz). Write the minimum `tar.exe` version the elements need into the result (for S0009).
2. **HTTP:** a local HTTP server as a pytest fixture (no request leaves the computer, REQ-SEC-050) that records the requests: method, headers, body, and answers with status, headers and a body (text, binary, a redirect, a slow answer). Each option of the element is tested against it.
3. **Corpus:** "HTTP Request" (`Flow 100439537`) on a copy whose URLs point to the local server (fix list, MIGRATION ID).

## Acceptance criteria

Those of every element package (README S0008); no test of this package opens a connection to another host than `127.0.0.1`.

## Not part of this

Shipping a newer `tar.exe` (S0009, if the minimum version of Windows needs it).

## Result

- **Built:** 9 elements (`Action_Compress_files`, `Action_Extract_files`, `Action_List_drives`, `Action_Get_Drive_Information`, `Action_Change_Drive_Label`, `Action_Eject_Drive`, `Action_Lock_Or_Unlock_Drive`, `Action_Download_File`, `Action_HTTP_Request`), shared code `lib/TarOps.ahk`, `lib/DriveOps.ahk`, `lib/HttpOps.ahk`, seam function `DriveRetract` (E0103), local server `tests/support/localhttp.py`.
- **Deviations:** MIGRATION M-0136 to M-0147 (tar.exe reads and writes archives only; drive lists in the editor; eject method 1 not ported; job deadline 10 minutes; HTTP flags and charset names; proxy rules; corpus flow fixes).
- **Tests:** `test_archive_elements.py`, `test_drive_elements.py`, `test_internet_elements.py` (80 passed, commit 008b4cff, working tree at that time); corpus "HTTP Request" moved out of PENDING (test_corpus.py with --all: 33 passed incl. schema test). Fast tier: 2534 passed, 4 failed (editor tray load flake, doc index and help pages stale before regeneration, verify tier ordering); all four pass on rerun.
- **Minimum tar.exe version:** not checked (this machine: bsdtar 3.8.9; older Windows 10 builds not checked).
- **Not checked:** eject and lock on real hardware; automatic proxy; the 10-minute deadline; Z extraction.
