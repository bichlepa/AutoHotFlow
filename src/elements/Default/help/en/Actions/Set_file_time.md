# Set file time

The action **Set file time** sets the modification, creation or last access time of a file, of several files (a wildcard pattern), or of folders.

## Settings

### File path

The path of the file or folder, or a wildcard pattern. A relative path is taken from the working directory of the flow.

### New Time

The new time as a text `YYYYMMDDHHMISS` in local time, for example `20210304050607`. A text that the AutoHotkey time check (IsTime) does not accept ends the element with an exception before any file is changed.

### Which time

The time to set: modification, creation or last access time.

### Options

- **Operate on files**, **Operate on files and folders**, **Operate on folders**: what is changed.
- **Recurse into subfolders**: the subfolders are changed as well.

If a file cannot be changed, the element ends with an exception.

## Examples

Set the modification time of all text files of a folder.

| Parameter | Value |
| --- | --- |
| File path | `%A_MyDocuments%\exampleFolder\*.txt` |
| New Time | `20210304050607` |
| Which time | Modification time |
| Options | Operate on files |
