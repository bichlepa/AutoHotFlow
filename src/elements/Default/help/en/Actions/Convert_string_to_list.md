# Convert string to list

The action **Convert string to list** reads a text in JSON format and writes it as a list to a variable.

## Settings

### Output list name

The variable that receives the list.

### Input string

The text to read. It must be a JSON object or a JSON array; the values of the object or array become the values of the list (an array gets the keys 1, 2, ...).

### Input format

**JSON** is the only format of this version. **YAML** is not available yet: the action ends with an exception.

## Remarks

If the text is not valid JSON, the action ends with an exception that names the error. A JSON text that is a number, a text or `true` is not a list: the action ends with an exception too (MIGRATION M-0110).
