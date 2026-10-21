# WI-0117 Seam `SystemOps` for the actions that disturb the computer (E0103)

Size: M · Depends on: – · Blocks: WI-0121 to WI-0124, WI-0126, WI-0127, WI-0131

## Goal

The elements that shut the computer down, eject a drive, empty the recycle bin, change the screen, play sound, block the input or move the mouse can be tested headless without doing it. They call their system functions through a seam, as the dialogs do (E0038); a test entry registers a provider that records the calls and answers from a script. Requirements: REQ-TST-030 (the method); the element requirements follow in their packages.

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0038, E0103; `doc/ELEMENT-API-V2.md` 3.3; `doc/TEST-STRATEGY.md` 9a; `doc/CONVENTIONS.md` 3 (rule `dialog-seam`); `src/elements/base/Dialogs.ahk`; `tests/integration/helpers/TestDialogProvider.ahk`, `tests/support/dialogs.py`; `tools/arch_check.py` (the rule `dialog-seam` and its self-test).

## Tasks

1. **Docs first:** ELEMENT-API-V2 3.3 gets a section on `SystemOps`: the list of functions, their arguments and return values (those of the AutoHotkey functions of the same name where one exists), the rule that an element never calls them directly.
2. **`src/elements/base/SystemOps.ahk`:** the functions the packages of S0008 need, grouped: power and session (`Shutdown` with its flags, lock, hibernate, suspend), drives (eject, label, lock, `DriveEject`/`DriveSetLabel`/`DriveLock`), recycle bin (`FileRecycleEmpty`), screen settings (resolution, orientation, brightness as far as WI-0127 needs), sound (`SoundSetVolume`, `SoundSetMute`, `SoundPlay`, `SoundBeep`, speech through SAPI), input (`BlockInput`, `Send` with its mode, `Click`, `MouseMove`, `MouseClickDrag`, `SetCapsLockState` and the other lock keys), idle time (`A_TimeIdle`, `A_TimeIdlePhysical`). The product provider calls the real function. A package that needs one more function adds it here (the file is shared; keep it sorted by group).
3. **Test provider:** a provider for the test entries of the worker and the trigger host that records every call (function, arguments, the element and the flow) and answers from a script (a return value, an error, or an idle time that grows with the clock of the test). The pytest side reads the record (`tests/support/`, next to `dialogs.py`).
4. **Architecture check:** a rule `system-seam` forbids the direct calls of task 2 in `src/elements/` (except in `SystemOps.ahk`) and `SystemOps.UseProvider` everywhere in `src/`; the self-test of the tool covers it; CONVENTIONS 3 gets the row.
5. **Tests:** the provider records a call from a worker element and from a trigger; a product entry cannot register a provider (the check); a test element of the test package uses one function of each group.

## Acceptance criteria

- The tests of task 5 and the architecture check are green. ELEMENT-API-V2, TEST-STRATEGY 9a and CONVENTIONS 3 are updated.

## Not part of this

The elements themselves (their packages); the real behaviour (the `gui` tests and manual check 12 of the owner, WI-0135).
