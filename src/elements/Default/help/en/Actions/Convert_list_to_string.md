# Convert list to string

The action **Convert list to string** writes a list as a text in JSON format. The list is not changed.

## Settings

### Output variable name

The variable that receives the text.

### Input list

The list (an expression that gives a list, usually the name of a variable).

A list whose keys are 1, 2, ..., n is written as a JSON array, every other list as a JSON object with its keys as text.

### Output format

**JSON** is the only format of this version. **YAML** is not available yet: the action ends with an exception.

### Options

**Compact mode** writes the JSON text on one line. Otherwise every value is on its own line, indented by the **Indentation length** (the number of spaces per level).

## Remarks

The keys of a JSON object are written in alphabetical order. The text can be read back with the action **Convert string to list**.
