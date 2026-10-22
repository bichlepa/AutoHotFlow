# Move file

The action **Move file** moves one file, or all files that match a wildcard pattern, to another folder or to a new name.

## Settings

### Source file

The path of a file, or a wildcard pattern (`*` and `?`, as in Copy file). A relative path is taken from the working directory of the flow.

### Destination file or folder

The path of the destination. To keep the file names, give only the folder; the folder must exist. Otherwise give the new file name.

### Overwrite

If checked, existing files are overwritten. Without it, a destination file that exists ends the element with an exception.

If some of the files of a pattern cannot be moved, the exception tells how many.

## Examples

Move one file to the documents folder.

| Parameter | Value |
| --- | --- |
| Source file | `G:\example.txt` |
| Destination file or folder | `%A_MyDocuments%` |

Move a file from the desktop to the working directory and rename it.

| Parameter | Value |
| --- | --- |
| Source file | `%A_Desktop%\example.txt` |
| Destination file or folder | `RenamedExample.txt` |
