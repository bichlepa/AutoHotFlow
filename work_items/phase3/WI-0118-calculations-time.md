# WI-0118 Calculations, script, date and time

Size: M · Depends on: WI-0116 · Blocks: WI-0125 (corpus "file test"), WI-0135

## Goal

The number, script and time elements of v1 exist in v2. They only compute, so they run inline. Requirements: REQ-ELM-200, REQ-ELM-280, REQ-VAR-020 (the element).

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Random_number` | inline | `Random`; no seed (as v1) |
| `Action_Absolute_number` | inline | |
| `Action_Square_Root` | inline | a negative number: the v1 error |
| `Action_Trigonometry` | inline | degrees and radians as in v1 |
| `Action_Rounding_A_Number` | inline | the methods of v1 (round, floor, ceil, decimal places) |
| `Action_Exponentiation` | inline | |
| `Action_Script` | inline | `ctx.EvaluateScript` (EXPRESSION-LANGUAGE 8); the script parameter in `V1Syntax` |
| `Action_New_Time` | inline | `YYYYMMDDHH24MISS` as in v1 |
| `Action_Time_Calculation` | inline | `DateAdd` |
| `Action_Time_Difference` | inline | `DateDiff` |

## Read first

The common part of the element packages (README S0008); `doc/EXPRESSION-LANGUAGE.md` 8, 17, 18.4 (the number types, E0029); `src/elements/Default/Actions/Action_New_variable.ahk`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **Numbers:** integer and float results follow the number rules of the expression language (E0029: `4/2` is an Integer); a text that is not a number gives the v1 error in both type modes.
2. **Time:** the time formats of v1 and the units of `DateAdd`/`DateDiff`; an invalid time stamp is an error, not an empty result.
3. **Corpus:** "maths test" (`Flow 1087828277`).

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

Formatting of times as text (`FormatTime`): not a v1 element.
