# WI-0103 Notice of a crashed editor that reopens it (E0093)

Size: S · Depends on: – · Blocks: WI-0104

## Goal

When an editor ends unexpectedly, the user is told. A click on the notice opens the editor again. Nothing reopens it by itself (E0093). Requirements: REQ-ROB-120 (the user learns that the editor has ended).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0075, E0093; `doc/PROTOCOL.md` 4.1, 4.1a (process events), 4.7 (notices), 4.10 (tray role); `src/supervisor/Children.ahk` (editors are not restarted), `src/tray/Tray.ahk`, `src/manager/NoticeWindow.ahk`.

## Tasks

1. **Docs first:** PROTOCOL 4.7 gets a notice kind `editor` (key `Notice_editor_crashed`, args: the flow name; `flowId`). Today notices come from the engine, numbered with `epoch` and `seq`. Decide who sends this one (the supervisor sees the crash; or it asks the engine to send it) and document the choice.
2. **Tray:** a click on the balloon of this notice opens the editor again (`cmd.editor.open`), if the tray can tell the click (`NIN_BALLOONUSERCLICK`). If it cannot, the entry in the manager's list of notices carries the action, and the result says so.
3. **Manager:** the entry in the list of notices, with an action "Open editor".
4. **No notice** for a planned end: the close box, a deleted flow, `sys.shutdown`.
5. **Tests:** a killed editor gives the notice; a closed editor gives none; the reopen through the test path; a gui test (owner) for the click on the balloon.

## Acceptance criteria

- The tests of task 5 are green (gui: written). PROTOCOL is updated. REQ-ROB-120 is updated.

## Not part of this

An automatic reopen (not wanted, E0093).
