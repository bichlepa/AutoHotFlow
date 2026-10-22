# Set file attributes

The action **Set file attributes** changes the attributes of a file, of several files (a wildcard pattern), or of folders.

## Settings

### File path

The path of the file or folder, or a wildcard pattern such as `%A_MyDocuments%\exampleFolder\*`. A relative path is taken from the working directory of the flow.

### Attributes

Each attribute can be set (checked), cleared (unchecked), or left as it is (grey). Only the attributes that are set or cleared are changed. When no attribute is set or cleared, nothing is changed.

### Options

- **Operate on files**: only files are changed.
- **Operate on files and folders**: files and folders are changed.
- **Operate on folders**: only folders are changed.
- **Recurse into subfolders**: the subfolders are changed as well.

If an attribute cannot be changed, the element ends with an exception. A file that does not exist is reported as such.

## Examples

Hide all files in a folder.

| Parameter | Value |
| --- | --- |
| File path | `%A_MyDocuments%\exampleFolder\*` |
| Attributes | Hidden: set, all others: grey |
| Options | Operate on files, not recursive |
