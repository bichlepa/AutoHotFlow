# Trim a string

The action **Trim a string** removes characters from the beginning and/or the end of a string and writes the result to a variable.

## Settings

### Output variable name

The variable that receives the trimmed string. It may be the same variable as the input string.

### Input string

The string to trim.

### Operation

**Remove a number of characters** removes the count given below from the left and/or the right side.

**Remove Specified caracters** removes every character of the list in **Which characters** from the left and/or the right side, as long as they are there.

### Remove from which side

The sides to trim. At least one side is always ticked. With no side ticked the text is written unchanged.

### Count of characters

Only with **Remove a number of characters**: how many characters are removed. A count of 0 or less removes nothing.

### Which characters

Only with **Remove Specified caracters**: the characters to remove (case sensitive). Every character of the text is one entry, there are no separators.

The default is the whitespace: `%a_space%%a_tab%%a_lf%%a_cr%` (space, tab, line feed and carriage return).

## Examples

Remove the last 6 characters ("world!") from "Hello world!", which leaves "Hello " with its space:

| Parameter | Value |
| --- | --- |
| Operation | `◉ Remove a number of characters` |
| Remove from which side | `☐ Left-hand side`, `☑ Right-hand side` |
| Count of characters | `6` |

Remove the spaces from both sides of " Hello world! ":

| Parameter | Value |
| --- | --- |
| Operation | `◉ Remove Specified caracters` |
| Remove from which side | `☑ Left-hand side`, `☑ Right-hand side` |
| Which characters | `%a_space%` |
