# WI-0129 `Action_Set_element_parameter`

Size: M · Depends on: WI-0107 (the editor's lists of other flows and elements) · Blocks: WI-0135

## Goal

A flow can change a parameter of an element, of its own flow or of another one, while it runs. The change is an edit of the flow: it takes effect at the next start of that element (E0001), is saved automatically (E0065), re-arms a changed trigger, and an open editor shows it. Requirements: REQ-ELM-250 (the row).

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Set_element_parameter` | inline | sends a patch to the engine it runs in; the dialog lists flows, elements and parameters (v1 `CheckSettings` with `staticValues`) |

## Read first

The common part of the element packages (README S0008); `doc/ARCHITECTURE.md` 4.2 (editing model); `doc/PROTOCOL.md` 4.2 (`cmd.flow.patch`, the operations, automatic saving), 4.11 (how the editor receives a foreign change); `src/core/FlowPatch.ahk`; the engine code of patches (WI-0093) and of edited triggers (WI-0094); the editor's `ctx` of WI-0107; v1: `Set_element_parameter.ahk`, `xx_setElementPar` (`v1/Source_Common/Multithreading/API for Elements.ahk`).

## Tasks

The common tasks (README S0008) for the class, and:

1. **Engine side:** a context function (`ctx.SetElementPar(flowId, elementId, parameterId, value)`, ELEMENT-API-V2 3) that commits an `element.update` on the newest revision of the flow, with the new name of the element when its name is the standard name (`GenerateName` of the class, under `try/catch`). It goes through the same path as a patch of the editor (checks, revision, saving, triggers) and is marked as coming from an element (no backup of an editing session; PROTOCOL 4.2 says how). Errors: no such flow, element or parameter.
2. **Editor:** an open editor of that flow gets the new revision as a foreign change (as after a rename); its draft and its undo stack follow the rules of WI-0096 (write down what happens to a step that touched the same element).
3. **Dialog:** the lists of flows, elements and parameters come from the editor's `ctx` (WI-0107); the value field follows the type of the chosen parameter, as v1.
4. **Tests:** the own flow and another flow; a running element sees the old value until its next start; a changed trigger fires with the new parameter; the file has the new value after the automatic save; an open editor shows it.

## Acceptance criteria

Those of every element package (README S0008); PROTOCOL 4.2 and ELEMENT-API-V2 3 are updated.

## Not part of this

Changing the connections or adding elements from a flow.
