# File has attribute

The condition **File has attribute** checks whether a file or folder has one attribute. The result is **yes** when it has the attribute and **no** when it has not.

## Settings

### File path

The path of the file or folder. A relative path is taken from the working directory of the flow.

### Which attribute

The attribute to look for: normal, read only, archive, system, hidden, directory, offline, compressed or temporary.

## Behavior

A file or folder that does not exist ends the element with an exception.

## Examples

Continue only when a file is read only.

| Parameter | Value |
| --- | --- |
| File path | `%A_MyDocuments%\example.txt` |
| Which attribute | Read only |

Connect the **yes** result to the steps for a read-only file, and the **no** result to the others.
