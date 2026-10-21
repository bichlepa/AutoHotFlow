# Substring

The action **Substring** retrieves one or more characters from the specified position in a string.

## Settings

### Output variable name

Name of the variable which will contain the substring.

### Input string

A string from which the substring will be extracted.

### Start position

If **Start from left** or **Start from right** is selected, the leftmost or rightmost characters of the input string will be written to the substring.

If **Start in following position** is selected, specify the start position.

### Count of characters

Specify how many characters will be retrieved.

If **Start in following position** is selected, it is possible to choose whether the characters that will be extracted lie left or right from the start position. It is also possible to extract all remaining characters from the specified position until the end.

## Examples

Extract the word "Hello" from the string "Hello world!".

| Parameter | Value |
| --- | --- |
| Start position | `◉ Start from left` |
| Count of characters | `5` |

Extract the name from the string "Hello Paul".

| Parameter | Value |
| --- | --- |
| Start position | `◉ Start in following position 7` |
| Count of characters | `☑ Until the end◉ Go right` |

## Remarks

There action "Substring" is similar but has different parametrers. The combination of all parameters in one element was too complicated therefore I created two elements.
