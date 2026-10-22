# Substring

The action **Substring** writes a part of a string to a variable: the leftmost or rightmost characters, or the characters from a position to the right or to the left of it.

## Settings

### Output variable name

The variable that receives the part.

### Input string

The string the part is taken from.

### Start position

**Start from left** takes the leftmost characters, **Start from right** the rightmost ones (the count below).

**Start from following position** takes the characters from the position given in the field below. Then choose the direction with the radio buttons under **Count of characters**: the characters to the right of the position, or to the left of it (the characters that end at the position, the position included).

### Count of characters

The number of characters. With **Until the end** the part goes to the end of the string (to the right) or to the start of the string (to the left).

A count of 0 or less gives the empty text.

## Examples

Take "Hello" from "Hello world!":

| Parameter | Value |
| --- | --- |
| Start position | `◉ Start from left` |
| Count of characters | `5` |

Take "Paul" from "Hello Paul" (the text starts at position 7):

| Parameter | Value |
| --- | --- |
| Start position | `◉ Start from following position`, `7` |
| Count of characters | `☑ Until the end`, `◉ Go right` |

## Remarks

The element **Substring 2** takes its start and end from texts or positions and is easier to use for those cases. The two elements stay apart because the settings of one would be too many for one form.

Variables in the input string are replaced before the text is cut (`%name%`). A text that is an expression is written as an expression.
