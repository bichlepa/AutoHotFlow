# Trim a string

The action **Trim a string** removes one or more characters from the beginning and/or end of a string.

## Settings

### Output variable name

Name of the variable which will contain the trimmed string. It can be the same variable as the input string.

### Input string

An input string which will be trimmed.

### Operation

If **Remove a number of characters** is selected, a specified count of characters from left and/or right side of the string will be removed.

If **Remove specific characters** is selected, some specific characters from left and/or right side of the string will be removed.

### Remove from which side

Select whether the characters should be removed from left-hand and/or right-hand side of the string.

### Count of characters

Only accessible if **Remove a number of characters** is selected.

Specify how many characters will be removed.

### Which characters

Only accessible if **Remove specific characters** is selected.

This field contains the characters (case sensitive) to exclude from the beginning and/or end of the input string.

*Examples:*

- `,.:;-!?` *(Omit punctuation characters)*
- `%a_space%%a_tab%%a_lf%%a_cr%` *(omit whitespaces)*

## Examples

Extract the word "Hello" and the space from the string "Hello world!".

| Parameter | Value |
| --- | --- |
| Operation | `◉ Remove a number of characters` |
| Remove from which side | `☑ Left-hand side ☐ Right-hand side` |
| Count of characters | `6` |

Remove the spaces from both sides of the string " Hello world! ".

| Parameter | Value |
| --- | --- |
| Operation | `◉ Remove specific characters` |
| Remove from which side | `☑ Left-hand side ☑ Right-hand side` |
| Which characters | `%a_space%` |
