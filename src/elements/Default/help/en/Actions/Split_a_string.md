# Split a string

The action **Split a string** splits a string into a list of substrings using the specified delimiters.

## Settings

### Output list name

Name of the variable which will contain the list with the results.

### Input string

A string whose contents will be read from.

### Delimiter characters

This field contains the separator characters (case sensitive). On every appearance of one of those characters the input text will be split into substrings.

If this field is blank, each character of the input string will be treated as a separate substring.

Each letter is a delimiter. Don't separate the delimiters by a comma or space, unless you want the comma or space to be a delimiter.

*Examples:*

- `,` *(Use comma as delimiter)*
- `%a_space%%a_tab%%a_lf%%a_cr%` *(separate by whitespaces)*
- `%delimiters%` *(variable that contains the delimiters)*
- `ab c` *(use the letters **a**, **b**, **c** and a **space** as delimiter)*

### Omit characters

This field contains the characters (case sensitive) to exclude from the beginning and end of each substring.

This field can be blank.

*Examples:*

- `,.:;-!?` *(Omit punctuation characters)*
- `%a_space%%a_tab%%a_lf%%a_cr%` *(omit whitespaces)*
