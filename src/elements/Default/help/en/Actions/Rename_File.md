# Rename file

The action **Rename file** gives one file a new name. The file stays in its folder.

## Settings

### Source file

The path of the file. A relative path is taken from the working directory of the flow. A wildcard is not allowed: one file is renamed.

### New file name

The new name with its extension, without a folder. A file with that name must not exist already; otherwise the element ends with an exception.

## Examples

Rename a file on the desktop.

| Parameter | Value |
| --- | --- |
| Source file | `%A_Desktop%\old.txt` |
| New file name | `new.txt` |
