# Encode string

The action **Encode string** writes a string in an encoded form to a variable. The only format is **URL**: the form that a web address needs for a value in its query, for example a space becomes `%20`.

## Settings

### Output variable name

The variable that receives the encoded string.

### Input string

The string to encode. Variables in the text are replaced first (`%name%`).

### Output format

**URL**: the letters A to Z, a to z, the digits 0 to 9 and the characters `-`, `.`, `_` and `~` stay as they are. Every other character becomes its UTF-8 bytes, each written as `%` and two hexadecimal digits (uppercase). So "ä" becomes `%C3%A4`.

## Examples

"Hello World!" becomes `Hello%20World%21`.

## Remarks

This element is for experienced users (level Advanced).
