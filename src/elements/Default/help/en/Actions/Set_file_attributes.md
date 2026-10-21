# Set file attributes

The action **Set file attributes** sets a timestamp of a file or folder.

## Settings

### File path

Name and path of the file. The file path is assumed to be in the working directory if an absolute path isn't specified.

### Attributes

The attributes to change.

### Options

This action can perform on files, forlder or both. It can also iterate in the subfolders.

## Examples

Hide all files in a folder.

| Parameter | Value |
| --- | --- |
| File path | `%A_MyDocuments%\exampleFolder\*` |
| Attributes | `☑ Hidden▣ all others` |
| Options | `◉ Operate on files☐ Recurse into subfolders` |
