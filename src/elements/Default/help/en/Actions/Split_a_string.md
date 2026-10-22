# Split a string

The action **Split a string** splits a string at its delimiter characters into a list. Each part becomes one value of the list, with the keys 1, 2, 3, ...

## Settings

### Output list name

The variable that receives the list. An empty input gives an empty list.

### Input string

The string to split.

### Delimiter characters

Every character of this field separates two parts (case sensitive). Each character is a delimiter of its own: do not separate them with commas or spaces, unless these should be delimiters too.

If the field is blank, every character of the input string is a part of its own.

*Examples:*

- `,` *(comma as the delimiter)*
- `%a_space%%a_tab%%a_lf%%a_cr%` *(whitespace)*
- `%delimiters%` *(a variable that holds the delimiters)*
- `ab c` *(the letters a, b and c and the space are delimiters)*

### Omit characters

Characters (case sensitive) that are removed from the start and the end of every part. A part that consists of omitted characters only stays as an empty part. The field can be blank.

*Examples:*

- `,.:;-!?` *(omit punctuation)*
- `%a_space%%a_tab%%a_lf%%a_cr%` *(omit whitespace)*

## Examples

"Hello real world, Hello virtual world" with the delimiter `,` and the default omit characters gives the two values "Hello real world" and "Hello virtual world".

## Remarks

Two delimiters next to each other give an empty part between them.
