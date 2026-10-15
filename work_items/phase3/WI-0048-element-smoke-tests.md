# WI-0048 L0001 smoke test of every registered element

Size: S · Depends on: WI-0047 · Blocks: WI-0052 to WI-0056

## Goal

Every registered element is checked automatically, without its own test code: a new element is covered as soon as it is registered.

## Read first

`doc/ELEMENT-API-V2.md` 1 to 3 and 7, `doc/TEST-STRATEGY.md` 2 and 6, `src/elements/base/ElementRegistry.ahk`, result of WI-0047.

## Tasks

1. An AHK test (`tests/ahk/`) walks over the registry of the product entry and checks per class:
   - metadata: `Mode` valid, `Level`, `Stability`, `Name()` and `Category()` give a text, `Icon` exists if set, `JobTimeoutMs` only for `worker`;
   - `Parameters("")` runs without the editor and returns a list; parameter ids are unique (case-insensitive); every `content` and `type` is known to `ctx.EvalParams` (ELEMENT-API 3.1); `result: "enum"` has `choices` and `enum` of the same length; `contentID` names an existing parameter;
   - `V1Syntax` names only existing parameters;
   - **parameters that the element evaluates itself** (retrospective of WI-0043; the warning of the converter comes only in S0008, E0036): if the v1 file of the class (`v1/Source_Elements/<package>/`, as long as `v1/` exists) calls `x_EvaluateExpression` or `x_EvaluateScript` on a parameter, that parameter has an expression content type or is named in `V1Syntax`. Known case in the core set: `Loop_Condition`. If the parameter cannot be found in the v1 code with certainty, the test names the class as "check by hand" instead of passing silently;
   - `GenerateName("", defaults)` with the defaults of `Parameters` gives a non-empty text;
   - the language keys used in `Name`, `Category`, `Parameters` and `GenerateName` exist in the English language file (no `f3` entry during the test);
   - the methods match the mode: `Run` for inline and worker, `Enable`/`Disable`/`TriggerVariables` for triggers.
2. The output names the class and the rule, so that a failure is clear without a debugger.
3. The test runs in the fast tier.

## Acceptance criteria

- Green for all elements after WI-0047; a deliberately broken test element (in `tests/`) makes it fail with a clear message (test of the test).

## Docs

`doc/TEST-STRATEGY.md` (L0001 smoke test), `doc/ELEMENT-API-V2.md` (what an element must fulfil).

## Not part of this

Behaviour of the elements (their own packages), `CheckSettings` (S0007).
