# WI-0102 Editor: menu bar, context menus, the trigger buttons

Size: M · Depends on: WI-0099, WI-0100, WI-0101 · Blocks: WI-0104, WI-0109

## Goal

The editor has the menu bar of v1, context menus in the canvas, all keyboard shortcuts, and working trigger buttons (switch and star). Requirements: REQ-EDT-110 (the menu bar), REQ-EXE-060 (editor part), REQ-TRG-030 (switching in the editor).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0077, E0087; `doc/howto/gui-and-hotkeys.md` (open menus); `src/editor/EditorTray.ahk`, `EditorFlowOps.ahk`; v1: `v1/Source_Editor/User Interface/Editor GUI Menu bar.ahk`.

## Tasks

1. **Menu bar** as in v1:
   - Save (Ctrl+S, `cmd.flow.save`)
   - Run
   - Stop (`cmd.flow.stop`)
   - Enable or Disable (the label follows the state; the questions of WI-0091)
   - Edit: Undo, Redo, Cut, Copy, Paste, Delete, Select all (each disabled when it is not possible)
   - Settings (the flow settings; disabled until WI-0109)
   - Exit (closes the editor)

   The labels follow the language and the flow state.
2. **Context menus** on a right click without a movement (a right drag still moves the view):
   - Element: Edit (disabled until S0007), Cut, Copy, Delete; on a trigger also Enable or Disable this trigger and Set as default trigger.
   - Connection: Change type, Delete.
   - Empty place: Paste, Select all, and a new action, condition, loop or trigger at that place.

   The menus run in the editor process (E0077).
3. **Trigger buttons** in the canvas: the switch sends `cmd.trigger.enable` or `cmd.trigger.disable`; the star moves `DefaultTrigger` with a patch (one undo step).
4. **Keys:** Ctrl+Z, Ctrl+Y and Ctrl+S go into the key table of WI-0098.
5. **Tests:** `cmd.test.command` is extended with the items of the menu bar and the context menus (headless). A gui test (owner) covers the real menu bar, a context menu and the shortcuts. An open menu does not make the editor hung (as the tray test).

## Acceptance criteria

- The tests of task 5 are green (gui: written, the owner runs them). REQ-EDT-110, REQ-EXE-060 and REQ-TRG-030 are updated.

## Not part of this

The flow settings dialog (WI-0109); the element settings (WI-0106).
