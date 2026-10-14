# WI-48 L1 smoke test of every registered element

Size: S · Depends on: WI-47 · Blocks: WI-52 to WI-56

## Goal

Every registered element is checked automatically, without its own test code: a new element is covered as soon as it is registered.

## Read first

`doc/ELEMENT-API-V2.md` 1 to 3 and 7, `doc/TEST-STRATEGY.md` 2 and 6, `src/elements/base/ElementRegistry.ahk`, result of WI-47.

## Tasks

1. An AHK test (`tests/ahk/`) walks over the registry of the product entry and checks per class:
   - metadata: `Mode` valid, `Level`, `Stability`, `Name()` and `Category()` give a text, `Icon` exists if set, `JobTimeoutMs` only for `worker`;
   - `Parameters("")` runs without the editor and returns a list; parameter ids are unique (case-insensitive); every `content` and `type` is known to `ctx.EvalParams` (ELEMENT-API 3.1); `result: "enum"` has `choices` and `enum` of the same length; `contentID` names an existing parameter;
   - `V1Syntax` names only existing parameters;
   - `GenerateName("", defaults)` with the defaults of `Parameters` gives a non-empty text;
   - the language keys used in `Name`, `Category`, `Parameters` and `GenerateName` exist in the English language file (no `f3` entry during the test);
   - the methods match the mode: `Run` for inline and worker, `Enable`/`Disable`/`TriggerVariables` for triggers.
2. The output names the class and the rule, so that a failure is clear without a debugger.
3. The test runs in the fast tier.

## Acceptance criteria

- Green for all elements after WI-47; a deliberately broken test element (in `tests/`) makes it fail with a clear message (test of the test).

## Docs

`doc/TEST-STRATEGY.md` (L1 smoke test), `doc/ELEMENT-API-V2.md` (what an element must fulfil).

## Not part of this

Behaviour of the elements (their own packages), `CheckSettings` (S7).
