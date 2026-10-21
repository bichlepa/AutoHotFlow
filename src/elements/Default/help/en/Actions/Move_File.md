# Move file

The action **Move file** moves one or more files.

## Settings

### Source file

The name of a single file or folder, or a wildcard pattern.

Both asterisks and question marks are supported as wildcards. A match occurs when the pattern appears in either the file's long/normal name or its 8.3 short name.

The file path is assumed to be in the working directory if an absolute path isn't specified.

### Destination file or folder

The path of the destination. To perform a simple copy -- retaining the existing file name(s) -- specify only the folder path.

The file path is assumed to be in the working directory if an absolute path isn't specified.

### Overwrite

If Overwrite is checked, existing files will be overwritten.

> **Warning:** Be careful using that option. It may cause loss of data.

## Examples

Move one file from one drive to MyDocuments folder.

| Parameter | Value |
| --- | --- |
| Source | `G:\example.txt` |
| Destination | `%A_MyDocuments%` |

Move all files from one drive to other drive.

| Parameter | Value |
| --- | --- |
| Source | `G:\*` |
| Destination | `H:\*` |

Move one file from desktop to the working directory and rename it.

| Parameter | Value |
| --- | --- |
| Source | `%A_Desktop%\example.txt` |
| Destination | `RenamedExample.txt` |
