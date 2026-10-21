# Delete file

The action **Delete file** deletes one or more files.

> **Warning:** Be careful using that action. It may cause loss of data.

## Settings

### File path

The name of a single file or folder, or a wildcard pattern.

Both asterisks and question marks are supported as wildcards.

The file path is assumed to be in the working directory if an absolute path isn't specified.

## Examples

Delete one file from MyDocuments folder..

| Parameter | Value |
| --- | --- |
| File path | `A_MyDocuments%\Example.txt` |

Delete all files from a drive.

| Parameter | Value |
| --- | --- |
| File path | `G:\*` |

Delete all text files from the working directory.

| Parameter | Value |
| --- | --- |
| File path | `*.txt` |
