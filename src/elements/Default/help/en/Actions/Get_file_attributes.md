# Get file attributes

The action **Get file attributes** retrieves the attributes (read-only, hidden, etc) of a file.

## Settings

### Output variable name

Name of the variable which will contain the result.

### File path

Name and path of the file. The file path is assumed to be in the working directory if an absolute path isn't specified.

## Remarks

The result string will contain a subset of the letters in the string RASHNDOCT:

- `R` = READONLY
- `A` = ARCHIVE
- `S` = SYSTEM
- `H` = HIDDEN
- `N` = NORMAL
- `D` = DIRECTORY
- `O` = OFFLINE
- `C` = COMPRESSED
- `T` = TEMPORARY
