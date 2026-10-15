# WI-0051 Dialog indirection and test provider

Size: S · Depends on: WI-0047 · Blocks: WI-0056

## Goal

Elements never call `MsgBox`, `InputBox`, `ToolTip` and the like directly but through a small indirection (E0038). The product uses the real dialogs; the test entry point registers a provider with scripted answers. Dialog elements can then be tested headless, without the `gui` tier.

## Read first

README of this phase (E0038), `doc/TEST-STRATEGY.md` 6 (`gui` tier), `doc/ELEMENT-API-V2.md` 1 and 3, `tests/integration/helpers/AutoHotFlowTest.ahk`, `tools/ahf_dialogwatch.py`, the v1 elements of WI-0056 (which dialog functions and options they use: buttons, timeout, icon, owner window, position).

## Tasks

1. **Indirection** in `src/elements/base/` (for example `Dialogs.MsgBox(text, title, options)`), with the return values of the AHK v2 functions. Only the dialog functions the core set needs, extended in S0008.
2. **Test provider:** the test entry point registers a provider; a test sets the answers through a test command (for example `cmd.test.dialog.script` with a list "next dialog: answer `Yes` after 50 ms" or "no answer, wait for the timeout") and can read the dialogs that were requested (text, title, options).
3. The provider works in every process that runs elements (engine for inline, worker); the answers reach the right process.
4. An arch check rule: no direct `MsgBox(`, `InputBox(`, `ToolTip(` in `src/elements/` outside the indirection (exception mechanism of `arch_check.py`).
5. One `gui` test (marked, run only by the project owner) shows that the product path opens the real dialog.

## Acceptance criteria

- A test element in `tests/` that shows a dialog in the worker gets the scripted answer; its result is checked in an e2e test in the fast or slow tier.
- With the product entry the provider cannot be registered.

## Docs

`doc/ELEMENT-API-V2.md` (dialogs), `doc/TEST-STRATEGY.md` (dialog tests), `doc/CONVENTIONS.md` 3 (new arch rule).

## Not part of this

The dialog elements themselves (WI-0056).
