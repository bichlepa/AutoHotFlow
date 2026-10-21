# Substring2

The action **Substring2** retrieves one or more characters from the specified position in a string.

## Settings

### Output variable name

Name of the variable which will contain the substring.

### Input string

A string from which the substring will be extracted.

### Start position

If **Start from left** is selected, the substring will contain characters from the start of the input string.

If **Start from following position** is selected, the substring will start at the specified position.

If **Search for a string and start there** is selected, the substring will start at the first occurence of the specified text. There are two text fields. The text in the first field won't be included in the substring, the text in the second field will be included. At least one field must contain any text. If the **Start position** is greater than 1, the occurences before this position will not be found.

### End position

If **End at the end of the string** is selected, the substring will contain all characters until the end of the input string.

If **End after a count of characters** is selected, the substring will contain the specified count of characters.

If **End at following position** is selected, the substring will contain all characters until the specified position.

If **Search for a string and end there** is selected, the substring will end at the specified text. There are two text fields. The text in the first field will be included in the substring, the text in the second field won't be included.

## Examples

Extract the word "Hello" from the string "Hello world!".

| Parameter | Value |
| --- | --- |
| Start position | `◉ Start from left` |
| End position | `◉ End after a count of characters` |
| End position - Count of characters | `5` |

Extract the content of a the first header in a HTML page.

| Parameter | Value |
| --- | --- |
| Start position | `◉ Search for a string and start there` |
| Start position - Text (excluding and including) | `<h1> and empty` |
| End position | `◉ Search for a string and end there` |
| End position - Text (including and excluding) | `empty and </h1>` |

## Remarks

There action "Substring" is similar but has different parametrers. The combination of all parameters in one element was too complicated therefore I created two elements.
