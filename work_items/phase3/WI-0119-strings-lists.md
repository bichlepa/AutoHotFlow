# WI-0119 Strings and list conversions

Size: M · Depends on: WI-0116 · Blocks: WI-0122, WI-0128 (corpus), WI-0134, WI-0135

## Goal

The string elements and the remaining list elements of v1 exist in v2, inline. Requirements: REQ-ELM-220, REQ-ELM-230.

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Search_in_a_string` | inline | |
| `Action_Substring` | inline | |
| `Action_Substring2` | inline | used by the demo flows (WI-0134) |
| `Action_Get_String_Length` | inline | |
| `Action_replace_in_a_string` | inline | plain and RegEx (v2 PCRE; a pattern that differs from v1 is a MIGRATION entry) |
| `Action_Trim_a_string` | inline | the help names `%a_space%`-style examples (WI-0112 list) |
| `Action_Split_a_string` | inline | the same |
| `Action_Change_character_case` | inline | |
| `Action_Encode_string` | inline | the encodings of v1 (URI and the others); check whether one needs `DllCall` (then a lib function, still inline if it does not block) |
| `Condition_String_Contains_Text` | inline | |
| `Action_Get_From_List` | inline | `lib/ListOps.ahk` |
| `Action_Convert_list_to_string` | inline | `lib/ListOps.ahk` |
| `Action_Convert_string_to_list` | inline | `lib/ListOps.ahk` |

## Read first

The common part of the element packages (README S0008); `src/elements/Default/lib/ListOps.ahk` and the list elements of the core set; `doc/MIGRATION.md` M-0057, M-0058 (lists); AutoHotkey docs: `RegExMatch`, `RegExReplace`, `StrSplit`, `InStr`, `SubStr`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **Text and case:** the case sensitivity options of v1; texts with characters outside ASCII and with line breaks.
2. **Corpus:** "string test" (`Flow 369404488`).

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

A JSON element (REQ-ELM-310, later).
