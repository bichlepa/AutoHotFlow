# Substring2

The action **Substring2** writes the part of a string between a start and an end to a variable. The start and the end are positions or texts.

## Settings

### Output variable name

The variable that receives the part.

### Input string

The string the part is taken from.

### Start position

**Start from left** starts at the first character.

**Start from following position** starts at the position given in the field below.

**Search for a string and start there** starts at the first occurrence of a text, searched from the position given in the field below. There are two text fields: the text in the first field is **not** part of the result, the text in the second field **is**. At least one field must hold a text.

### End position

**End at the end of the string** takes everything up to the end.

**End after a count of characters** takes the number of characters given below.

**End at following position** takes everything up to the position given below (the position is included).

**Search for a string and end there** ends at the first occurrence of a text after the start. There are two text fields: the text in the first field **is** part of the result, the text in the second field is **not**.

### Case sensitive

Each text search has its own check box for the case.

## Examples

Take "Hello" from "Hello world!":

| Parameter | Value |
| --- | --- |
| Start position | `◉ Start from left` |
| End position | `◉ End after a count of characters`, `5` |

Take the text of the first header in an HTML page:

| Parameter | Value |
| --- | --- |
| Start position | `◉ Search for a string and start there`, first text field `<h1>` (not included), second text field empty |
| End position | `◉ Search for a string and end there`, first text field empty, second text field `</h1>` (not included) |

## Remarks

If a text is not found, the output variable gets the empty text and the action ends normally: check the variable with a condition. The thread variables `a_startPos` (0 if the start text was not found) and `a_length` (the empty text if the end is not known) are set after each run.

If **End at following position** is before the start position, the action ends with an exception.
