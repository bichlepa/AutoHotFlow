# WI-0100 Editor: connect, connection type, move the ends of a connection

Size: M · Depends on: WI-0098, WI-0099 · Blocks: WI-0102

## Goal

The user draws connections as in v1, chooses and changes their type, and moves the ends of a connection to other elements. Requirements: REQ-EDT-070.

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 7 (the keys of a connection: `fromPart`, `toPart`, `ConnectionType`); WI-0093 (the rules in `FlowPatch`); v1: `v1/Source_Editor/User Interface/Editor GUI User Input.ahk` (the plus buttons, about lines 250 to 360, and `ui_MoveConnection`), `Element settings other.ahk` (`ElementSettingsConnectionTypeSelector`).

## Tasks

1. **Plus of an element:** the plus button of the selected element starts a connection that follows the mouse; a loop has a plus for its head and one for its tail (`fromPart`). A release (or a click) on an element connects to it (the `toPart` of a loop by the place hit, as in v1). On an empty place it creates a new element there and connects it, through the steps of WI-0099 (kind, class). Esc cancels.
2. **Plus of a connection:** inserts an element in between, as v1 does (read `ui_MoveConnection` first and do what it does).
3. **Move buttons** of a selected connection: they move its start or its end to another element.
4. **Type:** the type selector (normal; yes or no from a condition; exception) when a connection is made and more than one type is possible, as in v1. A double click on a connection changes its type. A connection that breaks a rule of REQ-EDT-070 is refused with a text in the status bar, and no patch is sent.
5. **One patch per action**, one undo step.
6. **Tests** (headless) for every case and every rule.

## Acceptance criteria

- The tests of task 6 are green. REQ-EDT-070 is updated.

## Not part of this

The menus (WI-0102); the flow check (REQ-EDT-160, later).
