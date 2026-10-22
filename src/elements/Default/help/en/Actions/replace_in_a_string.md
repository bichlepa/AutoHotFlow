# Replace in a string

The action **Replace in a string** replaces a text in a string and writes the result to a variable.

## Settings

### Output variable name

The variable that receives the result. It may be the same variable as the input string.

### Input string

The string to change.

### Text to search

The text to search for. An empty text changes nothing.

In the regular expression mode it is a pattern (see **Text mode**).

### Replace by

The text that replaces every found text. If it is empty, the found text is deleted.

In the regular expression mode, `$1`, `$2`, ... stand for the groups of the pattern.

### Number of replacements

**Replace only the first occurence** changes the first found text. **Replace all occurences** changes all of them.

The number of replacements is written to the thread variable `a_numberOfReplacements`.

### Case sensitivity

If **Case insensitive** is selected, the character case is ignored: with the input string "Hello World", the text "world" is found.

### Text mode

**Plain text** searches the text as it is (as in version 1).

**Regular expression** searches with a regular expression of AutoHotkey v2 (PCRE), for example `\d+` for numbers. An invalid pattern ends the action with an exception. The case check is done with `(?i)` in front of the pattern.

## Examples

Replace "World" by "Paul" in "Hello World": the result is "Hello Paul".

Replace every number in "a1 b22" by "#" with **Regular expression** and **Replace all occurences**, search text `\d+`: the result is "a# b#".

## Remarks

A variable that the text names (`%name%`) is replaced before the search, in the search text and in the replacement too.
