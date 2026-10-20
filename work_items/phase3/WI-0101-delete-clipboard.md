# WI-0101 Editor: delete, cut, copy, paste (Windows clipboard, E0091)

Size: M · Depends on: WI-0098 · Blocks: WI-0102

## Goal

The user deletes the selection after a question, and cuts, copies and pastes elements, also from one flow into another, which is another editor process. Requirements: REQ-EDT-080.

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0091, E0092; `doc/howto/gui-and-hotkeys.md`; AHK v2 docs `lib/A_Clipboard.htm`, `lib/ClipboardAll.htm`, `lib/DllCall.htm` (the Win32 calls `RegisterClipboardFormat`, `SetClipboardData`); v1: `v1/Source_Editor/Elements/Clipboard.ahk`, `Editor GUI User Input.ahk` (`key_del`, the trash button about lines 360 to 400).

## Tasks

1. **Delete:** Del and the trash button ask first (one question for the selection, a `ui_common/` dialog), then one patch removes the elements with their connections and the selected connections. One undo step.
2. **Copy:** the selected elements and the connections between them, as JSON `{formatVersion, elements, connections}` in a registered clipboard format of AutoHotFlow only, no text (E0091). Ctrl+C. Ctrl+X copies and then deletes without a question (as v1).
3. **Paste (Ctrl+V):** new IDs; the position is under the mouse, or in the middle of the view when the mouse is outside (v1). A pasted manual trigger is not the default when the flow has one (v1). Unknown classes are kept as they are; the engine sets the state of pasted triggers (E0092). The pasted elements are selected. One patch, one undo step. A clipboard without our format does nothing.
4. **Two flows:** copy in one editor and paste in another (two processes), tested e2e.
5. **No blocking:** the clipboard is opened with a short bounded retry, never with a wait loop on the message path (rule 3). If it stays busy, a text in the status bar says so.
6. **Tests:** headless for every case, e2e with two editors; the real keys are part of the gui test of WI-0102.

## Acceptance criteria

- The tests of task 6 are green. REQ-EDT-080 is updated. MIGRATION has the change of the clipboard (E0091).

## Not part of this

Pasting text or elements from outside AutoHotFlow (not wanted, E0091).
