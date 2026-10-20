# WI-0113 Window of an unhandled error with the variables of the branch (REQ-USE-080 part 2)

Size: M · Depends on: – · Blocks: WI-0114

## Goal

The notice of an unhandled error opens a window with the message, the element and the variables of the branch at the moment of the error. The window is read-only and blocks nothing (E0072). Requirements: REQ-USE-080 (part 2).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0072; `doc/PROTOCOL.md` 4.7, 4.8 (the notices of the manager); `doc/EXPRESSION-LANGUAGE.md` section 18 (scopes); `src/engine/Executor.ahk` (where a branch ends with an unhandled exception), `src/manager/NoticeWindow.ahk`.

## Tasks

1. **Docs first:** PROTOCOL 4.7: what the engine keeps, the command that asks for it (for example `cmd.flow.error.get {flowId, errorId}`), and the `errorId` in the notice.
2. **Engine:** at an unhandled exception it takes a copy of the variables of the branch: instance, thread and loop variables (decide about the hidden ones and document it), values as text, objects as shortened JSON. The copy is bounded (proposal: the last 5 errors per flow, 200 variables and 64 KB per error) and is dropped with the flow. Nothing is added to the hot path when there is no error.
3. **Manager:** the window shows the message, the flow, the element, the time, and the variables in a list. It is read-only and blocks nothing. It opens from the list of notices, and from the click on the tray notice if WI-0103 made that possible. A new error updates the open window, as in v1.
4. **Tests:** integration (an error keeps its variables; the bounds hold; a deleted flow drops them); the manager headless; a gui test (owner).

## Acceptance criteria

- The tests of task 4 are green (gui: written). PROTOCOL is updated. REQ-USE-080 is updated.

## Not part of this

Changing the variables (the debugger, REQ-DBG-060, phase 4); the switch per flow (WI-0109).
