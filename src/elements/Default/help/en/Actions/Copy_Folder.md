# Copy folder

The action **Copy folder** copies a folder with all its subfolders and files.

## Settings

### Source folder

The path of the folder, without a trailing backslash. A relative path is taken from the working directory of the flow.

### Destination folder

The path of the destination. It is created if it does not exist.

### Overwrite

If checked, the files are copied into an existing destination folder and replace the files of the same name. Without it, an existing destination folder ends the element with an exception.

## Examples

Copy a folder to the documents folder.

| Parameter | Value |
| --- | --- |
| Source folder | `G:\exampleFolder` |
| Destination folder | `%A_MyDocuments%\exampleFolder` |
