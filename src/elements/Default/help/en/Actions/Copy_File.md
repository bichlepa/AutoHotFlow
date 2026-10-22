# Copy file

The action **Copy file** copies one file, or all files that match a wildcard pattern.

## Settings

### Source file

The path of a file, or a wildcard pattern. `*` matches any number of characters and `?` one character, for example `G:\*` or `C:\Temp\*.txt`. A relative path is taken from the working directory of the flow.

If the source is neither a file nor a pattern that matches a file, the element ends with an exception.

### Destination file or folder

The path of the destination. To keep the file names, give only the folder; the folder must exist. Otherwise give the new file name.

### Overwrite

If checked, existing files are overwritten. Without it, a destination file that exists ends the element with an exception.

If some of the files of a pattern cannot be copied, the exception tells how many.

## Examples

Copy one file to the documents folder.

| Parameter | Value |
| --- | --- |
| Source file | `G:\example.txt` |
| Destination file or folder | `%A_MyDocuments%` |

Copy all files of a folder to another drive.

| Parameter | Value |
| --- | --- |
| Source file | `G:\*` |
| Destination file or folder | `H:\*` |

Copy a file from the desktop to the working directory and rename it.

| Parameter | Value |
| --- | --- |
| Source file | `%A_Desktop%\example.txt` |
| Destination file or folder | `RenamedExample.txt` |
