# Get file attributes

The action **Get file attributes** stores the attributes of a file or folder in a variable. The attributes are a text of letters: `R` read only, `A` archive, `S` system, `H` hidden, `D` folder, `O` offline, `T` temporary, `C` compressed. A file without attributes gives `X`.

## Settings

### Output Variable name

The name of the variable that gets the attribute text.

### File path

The path of the file or folder. A relative path is taken from the working directory of the flow.

## Behavior

- A file or folder that does not exist ends the element with an exception.
- Wildcard patterns are not checked by this action: the first match is used.

## Examples

Read the attributes of a document into the variable `attr`.

| Parameter | Value |
| --- | --- |
| Output Variable name | `attr` |
| File path | `%A_MyDocuments%\example.txt` |
