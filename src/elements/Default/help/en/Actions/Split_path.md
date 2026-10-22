# Split path

The action **Split path** separates a file path into its parts and writes each part to a variable.

## Settings

### File path

The path to split. It does not have to exist: only the text is analysed. A relative path is taken from the working directory of the flow first, so the directory then shows that folder.

### Output variables

The names of the variables for the parts. Leave a name empty when you do not need that part.

- **File name**: the file name with its extension.
- **Directory**: the folder, with the drive or the server name. No backslash at the end.
- **File extension**: the extension, without the dot.
- **File name without extension**: the file name without the extension.
- **Drive**: the drive letter with a colon, or the server name of a network path.

If the path has no drive, the variable for the drive is empty; if it has no folder, the directory is empty.

## Examples

Split `C:\Users\me\notes.txt`: the file name is `notes.txt`, the directory `C:\Users\me`, the extension `txt`, the name without extension `notes` and the drive `C:`.
