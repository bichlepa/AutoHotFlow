# WI-0081 `.ahf` export and import with the warning of REQ-SEC-060

Size: M · Depends on: WI-0074, WI-0076 · Blocks: WI-0082

## Goal

The user exports selected flows to an `.ahf` file (a ZIP archive, as v1) and imports such a file through a file dialog or by dropping it on the manager. v1 files load. On a name conflict the user can rename. Before the import the user is told that a flow is a program with his rights, with the list of the elements that act on the system; imported flows are disabled. Requirements: REQ-MGR-050, REQ-SEC-060.

## Read first

As WI-0076, plus `v1/Source_Manager/User Interface/Import and export.ahk` (format, conflict handling), REQ-SEC-030 and REQ-SEC-060 in `doc/REQUIREMENTS.md`, `doc/ELEMENT-API-V2.md` (where an element could declare that it acts on the system); the help of the Windows `tar.exe` (`tar --help`, libarchive: `--format zip`, `-a`).

## Tasks

1. **Spike first:** `tar.exe` of Windows (`%SystemRoot%\System32\tar.exe`) writes a ZIP that v1 could read (7-Zip lists it) and reads an `.ahf` written by v1 (one from the owner or made with 7-Zip in the test). It is started without blocking (`Run` and a check of the process, never `RunWait` on the message path). If it fails: report to the owner with the alternatives (an own ZIP writer with "stored" entries plus a reader for "deflate", or PowerShell `Compress-Archive`).
2. **Docs first:** PROTOCOL (storage packs and unpacks in a temp folder of the data folder; the engine builds the list of the flows to export and receives the definitions of an import; the static variables of a flow go into the archive in a v2 export, read optionally at import), MIGRATION (what v2 adds to the archive).
3. **Export:** the selected flows (the files as saved), with their static variables in a subfolder; a file dialog for the target.
4. **Import:** the archive is unpacked by storage; every flow is checked (parse); a name conflict asks: rename (next free number, or a name the user types), skip, cancel (as v1, without "overwrite" unless the owner wants it); the flows are created through WI-0070 with new IDs when the ID exists; disabled.
5. **Warning (REQ-SEC-060):** before the import the user sees which flows contain elements that act on the system (files, programs, keys and mouse, network, AutoHotkey scripts); the engine computes the list from a property of the element classes (add it to the element API, set it for the core set and the triggers) and from the class name for unknown classes ("unknown element" counts as acting).
6. **Drop:** an `.ahf` dropped on the manager window starts the import.
7. **Tests:** export and import round trip (definitions equal, variables back), a v1 archive, a broken archive reported, a name conflict with each answer, the warning lists the right elements, imported flows disabled.

## Acceptance criteria

- The spike result is recorded; the tests of task 7 are green, serial and parallel.

## Not part of this

The deletion into the Windows recycle bin as an `.ahf` (REQ-MGR-150, `later`), which can reuse the export.
