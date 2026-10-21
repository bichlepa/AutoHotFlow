# WI-0135 Acceptance S0008

Size: M · Depends on: WI-0116 to WI-0134 · Blocks: S0009

## Goal

S0008 is demonstrably finished: every element of v1 exists in v2, the v1 test flows run green, and the documents match the code. Afterwards S0009 is detailed.

## Tasks

1. **Criteria:** go through "Acceptance S0008" in `work_items/phase3/README.md` point by point, with the evidence in the result.
2. **All classes:** a test compares the class lists of `v1/Source_Elements/Default/` and `src/elements/Default/` (every v1 class is registered, without regard to case); the smoke test and the schema check of WI-0116 cover all of them; every class has `ActsOnSystem` set on purpose (a list in the result: which act on the system and why).
3. **Corpus:** "_AutomaticTest starter" (`Flow 65341778`) starts the other 15 flows; it runs headless and green with its fixes (its sound through `SystemOps`; the "Dialog test" part that needs a real window counts by the owner's `gui` run). `PENDING` is empty.
4. **Memory and start** with all real classes (R0003, REQ-PRF-030): the background processes (MS-0042 again), a worker, the engine and one editor; the start of a worker (MS-0029 again). Compare with the budget of E0040 and write the result into MEASUREMENTS; a budget that is exceeded is a finding for the owner.
5. **Manual check 12** (new section in `doc/MANUAL-CHECKS.md` with VS Code tasks): the owner runs the elements behind `SystemOps` for real where it is safe (sound, speech, volume, mouse and keys into a test window, a screenshot, the screen settings read, the input block for a few seconds), the dialogs of WI-0128 and the "Dialog test" flow, the demo flows, a shortcut of `Trigger_Shortcut` on the desktop, and the `gui` tests of S0008. Power and session elements only by the owner's own choice (not part of the check list).
6. **Documents:** REQUIREMENTS (every requirement of S0008 with `v2`, `Plan`, `Evidence`), ELEMENT-API-V2, PROTOCOL, ARCHITECTURE 8, MIGRATION, TEST-STRATEGY, MANUAL-CHECKS, `.vscode/tasks.json`; `python tools/doc_index.py --check`.
7. **Retrospective:** what was hard (HOW-TO entries); what S0009 needs: the files that are fetched by setup tools and must be shipped, the minimum version of `tar.exe` (WI-0122), the interpreter of the script elements in the compiled program (WI-0130), the command of the shortcut trigger (WI-0133), the language keys that are missing in ko and ru.
8. **Runs:** serial, parallel, `-m stress`, foundation and slow green.

## Acceptance criteria

- Every point of the S0008 acceptance has its evidence; the owner closed manual check 12.

## Not part of this

Detailing S0009 (its own session with the owner).
