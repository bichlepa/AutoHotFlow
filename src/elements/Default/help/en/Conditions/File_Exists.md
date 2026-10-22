# File exists

The condition **File exists** checks whether a file or a folder exists at the path. The connection **yes** is taken when it exists, **no** when it does not.

## Settings

### File path

The path to check. A relative path is taken from the working directory of the flow. A wildcard pattern is "yes" when at least one file matches.

## Examples

Check whether a file exists in the documents folder and write a message only if it does.

| Parameter | Value |
| --- | --- |
| File path | `%A_MyDocuments%\notes.txt` |
