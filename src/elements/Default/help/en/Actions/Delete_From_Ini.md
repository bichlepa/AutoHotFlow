# Delete from ini

The action **Delete from ini** removes a key or a whole section from an ini file.

## Settings

### Path of an .ini file

The ini file. The file must exist. A relative path is taken from the working directory of the flow.

### Action

- **Delete a key**: the key is removed from the section. An empty key ends the element with an exception.
- **Delete a section**: the section, with all its keys, is removed.

### Section

The section. An empty name ends the element with an exception.

### Key

The key to remove (only for **Delete a key**).

## Behavior

A key or section that does not exist is not an error for Windows. If the file cannot be changed, the element ends with an exception.

## Examples

Remove the key `name` from the section `user`.

| Parameter | Value |
| --- | --- |
| Path of an .ini file | `%A_MyDocuments%\settings.ini` |
| Action | Delete a key |
| Section | `user` |
| Key | `name` |
