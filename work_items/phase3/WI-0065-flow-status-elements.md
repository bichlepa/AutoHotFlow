# WI-0065 `Action_Set_Flow_Status` and `Condition_Flow_Enabled`

Size: M · Depends on: WI-0060, WI-0062 · Blocks: WI-0067

## Goal

A flow switches flows and triggers and asks whether they are enabled, under the model of E0056. Both elements are used by the v1 flow "Trigger test" and `Action_Set_Flow_Status` by eight of the pending flows. Requirement: REQ-ELM-250 (two rows).

## Read first

As WI-0055 (porting an inline flow control element, `ctx.CallFlow`, `ctx.DefaultTrigger`), WI-0060 (the model), the v1 classes `v1/Source_Elements/Default/Actions/Set_Flow_Status.ahk` and `v1/Source_Elements/Default/Conditions/Flow_Enabled.ahk`, their help texts, the v1 helpers `x_flowEnable`, `x_flowDisable`, `x_triggerEnable`, `x_triggerDisable`, `x_isFlowEnabled` or similar in `v1/Source_Execution/API/API for Elements.ahk`.

## Tasks

1. **`ctx` functions** (inline only, ELEMENT-API 3): enable or disable a flow (its following triggers, as `cmd.flow.enable/disable`), enable or disable one trigger, ask whether a flow is active and whether a trigger is enabled. They use the engine functions of WI-0060, so the switch is saved and arms through WI-0062.
2. **`Action_Set_Flow_Status`:** parameters as v1 (`ThisFlow`, `flowID`, `WhichTrigger`, `triggerID`, `Enable`). The choice `WhichTrigger` goes beyond v1, because of the model of E0056 (REQ-TRG-050); the v1 values keep their enum value, so v1 flows load unchanged:
   - `Any` (label "The flow"): the triggers that switch with the flow, as `cmd.flow.enable/disable`. For a v1 flow, where every trigger switches with the flow, this is the v1 behaviour.
   - `All` (new, label "All triggers"): every trigger, those of their own included. Disabling with it is the complete switch-off; an element never asks.
   - `Independent` (new, label "Triggers of their own"): every trigger that does not switch with the flow.
   - `Default` and `Specified`: one trigger, of either kind.
   A flow or trigger that does not exist: `exception` with a message that names it (v1 texts where they fit). A choice that matches no trigger (`Independent` in a flow without one) ends `normal` with an `f1` log.
3. **`Condition_Flow_Enabled`:** the same parameters, with its own choice:
   - `Any` (label "The flow is active"): at least one trigger that switches with the flow is enabled; for a v1 flow the v1 behaviour.
   - `AnyTrigger` (new): any trigger is enabled, those of their own included.
   - `AllTriggers` (new): every trigger is enabled.
   - `AnyIndependent` (new): any trigger of its own is enabled.
   - `Default` and `Specified`: the target state of that trigger (not whether it is armed).
   Check the help texts of both elements and write the new choices into the v2 help (S0008 or the help step); a deviation goes into MIGRATION. The new labels get language keys in `src/elements/Default/language/en.ini` and `de.ini` (the other languages fall back to English).
4. Switching the trigger that started the own instance does not stop the instance (as v1, REQ-EXE-070).
5. **Tests:** smoke test; e2e through the flow builder: every choice of both elements for enable, disable and the query, own and other flow, independent triggers, a flow without following triggers, a missing flow or trigger; the switch arms a test timer trigger (WI-0061) and is kept after a restart of the session.

## Acceptance criteria

The tests of task 5 are green, serial and parallel. The table `PENDING` no longer lists the two classes.

## Docs

`doc/ELEMENT-API-V2.md` 3, `doc/MIGRATION.md` (differences to v1, also M-0064-like names in `GenerateName`), `doc/REQUIREMENTS.md` REQ-ELM-250 (rows `Action_Set_Flow_Status`, `Condition_Flow_Enabled`) and REQ-TRG-050 (the elements), then `python tools/doc_index.py`.

## Not part of this

Lists of flows and triggers in the settings dialog (S0007); `Action_Set_element_parameter` (S0008).
