# WI-0089 Live states, marks and the event load

Size: M · Depends on: WI-0088 · Blocks: WI-0092

## Goal

The editor shows what happens in the flow, as v1 did and a bit more: running elements, the recently run elements and connections fading out, the enabled state of every trigger, exceptions, the warnings of the evaluation and the MIGRATION places. A flow that runs as fast as the engine allows does not stall the editor or the hub. Requirements: REQ-EDT-040, REQ-EDT-150, REQ-VAR-100 (display), REQ-EXE-140 (editor), REQ-PRF-060.

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 2.1, 9; `doc/PROTOCOL.md` (the editor section of WI-0088, 4.3); `doc/MIGRATION.md` (the IDs that the `migration` key names); WI-0085, WI-0086, WI-0088 (results); `v1/Source_Draw/GDIp/GDIp.ahk` (`lastRun`, the tint of 1 s); `tests/stress/stresskit.py`.

## Tasks

1. **Running and recently run:** an element is tinted while `countRuns` > 0; after its end, and a connection after a thread took it (`connectionId`), the tint fades over 1 s (v1). The fading timer runs only while a tint fades.
2. **Triggers:** the switch mark per trigger from `evt.trigger.state` (enabled or not); an arming error marked, its text for the tooltip (WI-0090); the star of the default manual trigger.
3. **Exception:** the element keeps the exception look until its next start; the message for the tooltip.
4. **Warnings and MIGRATION places** (REQ-EDT-150): a badge with the count of warnings at the element (from `evt.element.warning` and the runstate), another badge for MIGRATION places (from the `migration` key of the element); the texts for the tooltip and the status bar.
5. **Event load** (stress tier): a flow at the limit of the runaway guard (a loop of inline elements, 50,000 element starts per minute, two events each) with the editor open: the editor answers the pings, draws at most 30 frames per second, its queue in the hub does not grow without bound (snapshot of the hub), and after the stop it shows the right counts and states.
6. **REQ-PRF-060:** the time from the event of the engine to the end of the frame that shows it, median and p95, headless (the event carries no time stamp: measure from the arrival at the editor plus the hub latency of PROTOCOL measurements, or add the time of the engine; decide and say so); with a window in the `gui` variant.

## Acceptance criteria

- E2e tests (headless, probes and model state) for each of tasks 1 to 4 are green; the stress test of task 5 is green; the measurement of task 6 is recorded and REQ-PRF-060 updated.

## Not part of this

The tooltip itself (WI-0090); selecting and editing (S0006).
