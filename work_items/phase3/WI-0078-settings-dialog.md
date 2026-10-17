# WI-0078 Settings dialog, change of language without a restart, about window

Size: M · Depends on: WI-0077 · Blocks: WI-0082

## Goal

The manager has the settings dialog (tabs as v1: General, Flow settings, Appearance, Debugging, plus the new keys), every open window of the manager and the tray menu change their language without a restart, and the about window shows the versions, the license and the project site. Requirements: REQ-SET-010, REQ-SET-020, REQ-SET-050, REQ-SET-070, REQ-LNG-020, REQ-MGR-140 (language follows), REQ-MGR-100, REQ-USE-010 (setting).

## Read first

As WI-0077, plus `v1/Source_Manager/User Interface/Global_Settings.ahk`, `v1/Source_Manager/User Interface/About.ahk`, WI-0069 (dialogs, `UiTexts`), `src/core/AhfVersion.ahk`.

## Tasks

1. **Dialog:** every key of WI-0077 that the user sets (not the window positions), with its check; OK applies, Cancel discards; a key that needs a restart (if any remains) says so and offers it. The working directory with a folder dialog. The limits with a note that 0 means no limit.
2. **Language:** the list of the language files found; "Windows language" as the first entry; the change reloads every window of the manager and the tray menu.
3. **About window:** version of AutoHotFlow (`AhfVersion`) and AutoHotkey (`A_AhkVersion`), the license, the project site as a link.
4. **Tests:** headless through the driver: a set through the dialog model reaches the engine, invalid values are refused with the message; the language change in the manager model and in the tray menu (a test hook lists the texts of the menu). `gui` test of the dialog (owner).

## Acceptance criteria

- The headless tests are green; the `gui` test exists with a VS Code task.

## Not part of this

The autostart entry and the elevation (WI-0079).
