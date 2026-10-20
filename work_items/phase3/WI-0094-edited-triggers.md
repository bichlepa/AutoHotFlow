# WI-0094 Engine: triggers of an edited flow

Size: M · Depends on: WI-0093 · Blocks: WI-0104

## Goal

After every patch, the trigger host holds what the definition says. A changed trigger of an enabled flow is armed again with its new parameters, a removed one is disarmed and leaves the state file, and a new one is enabled by E0092. S0003 left this work to S0006. Requirements: REQ-TRG-030, REQ-TRG-050, REQ-EXE-070.

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 4 (the target state of the triggers); `doc/PROTOCOL.md` 4.2 (trigger switches), 4.4; `doc/DECISIONS.md` E0056, E0057, E0092; `src/engine/TriggerArms.ahk` (`Changed`), `src/engine/FlowRecord.ahk`, `src/engine/FlowStateFile.ahk`; WI-0060 and WI-0062 (results); v1: `v1/Source_Common/Flows/States.ahk` (`findEnabledTriggersWhichHaveBeenChanged`).

## Tasks

1. **Docs first:** PROTOCOL 4.2 and 4.4 say what a patch does to the triggers. Add E0092 to MIGRATION (v1 starts every new trigger disabled).
2. **Difference of the triggers** between two revisions: added, removed, changed (class, package, parameters, `followsFlow`). A change of the position, the name or `StandardName` only is not a change.
3. **Effects:** a changed trigger that is enabled is armed again (a new generation, so fired events of the old one are dropped). A removed trigger is disarmed and leaves the state file (write-behind). An added trigger is enabled when it follows the flow and the flow is active; otherwise it starts disabled (E0092); it is armed when it is enabled. `Trigger_Start_up` added later does not fire (S0003 rule). The same rules apply to undo, which adds the trigger again with its old ID.
4. **Flow state:** after a patch that changes triggers, update `active` and `independentActive` and send `evt.flow.state` and `evt.trigger.state`.
5. **Tests** (integration, with a timer trigger): a changed interval of an enabled trigger fires at the new interval; a removed trigger fires no more and is gone from the state file; a trigger added to an active flow is enabled and armed, one added to an inactive flow is disabled; an undo of a removal; a move does not arm again (the generation stays the same).

## Acceptance criteria

- The tests of task 5 are green. PROTOCOL and MIGRATION are updated. REQ-TRG-030 and REQ-TRG-050 are updated.

## Not part of this

The checkbox "Switch with the flow" (S0007, WI-0107); the trigger buttons in the canvas (WI-0102).
