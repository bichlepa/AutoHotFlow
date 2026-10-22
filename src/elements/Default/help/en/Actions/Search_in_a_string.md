# Search in a string

The action **Search in a string** searches for a text in a string and writes the position where it was found. The position counts from the left, the first character is 1.

## Settings

### Output variable

The variable that receives the position. If the text is not found, the variable is empty and the action ends with an exception ("Searched text was not found"), so the flow can continue on that connection.

### Input string

The string to search in.

### Text to search

The text to search for. An empty text is never found.

### Which occurence

The number of the occurrence to find: 1 is the first one, 2 the second one, and so on. The count starts at the side that **Start position** names.

### Start position

**Search from left to right** starts at the position given in the field below and counts to the right.

**Search from right to left** starts at that position counted from the right end: 1 is the last character. The occurrence is then counted from the right. The position written is still counted from the left.

### Case sensitivity

If **Case insensitive** is selected, the character case is ignored: with the input string "Hello World", the search text "world" is found.

If **Case sensitive** is selected, the character case matters.

## Examples

Find the first "World" in "Hello World": the variable gets 7.

| Parameter | Value |
| --- | --- |
| Input string | `Hello World` |
| Text to search | `World` |
| Which occurence | `1` |

Find the last "o" in "Hello World": the variable gets 8.

| Parameter | Value |
| --- | --- |
| Input string | `Hello World` |
| Text to search | `o` |
| Which occurence | `1` |
| Start position | `◉ Search from right to left`, `1` |

## Remarks

The positions are the same as those of AutoHotkey v2 `InStr`. The element is the same as the function `InStr(String, Text, CaseSensitive, Offset, Occurrence)` with a negative offset and occurrence for the search from the right.
