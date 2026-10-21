# Parse a string

The loop **Parse a string** runs over the fields of a text, one field after the other. The text is split at the delimiter characters.

## Settings

### Input string

The text to split: a text, or an expression, as chosen next to the field (see [Variables and expressions](../../../../../../assets/help/en/Variables.md)). An empty text is an error.

### Delimiter characters

Each character in this field is a delimiter; the comparison is case sensitive. Do not separate the delimiters with commas or spaces, unless these are delimiters too.

If the field is empty, each character of the text is a field of its own: `abc` gives the fields `a`, `b` and `c`.

Examples:

- `,`: fields separated by commas
- `%a_space%%a_tab%%a_lf%%a_cr%`: fields separated by spaces, tabs and line breaks (a variable written as `%name%` is replaced by its value in this field)
- `ab c`: the letters `a` and `b`, and the space, are delimiters

### Omit characters

Characters that are removed from the beginning and the end of every field, for example `,.:;-!?` to remove punctuation, or `%a_space%%a_tab%%a_lf%%a_cr%` to remove whitespace. The field may be empty.

## Supplied Variables

### `A_Index`

The index of the current repetition. It starts with 1 and increases with every repetition.

### `A_LoopField`

The current field.

All supplied variables are removed after the last repetition.
