# Move folder

The action **Move folder** moves a folder with all its subfolders and files.

## Settings

### Source folder

The path of the folder, without a trailing backslash. A relative path is taken from the working directory of the flow.

### Destination folder

The path of the destination, the new location of the folder.

### Overwrite

If checked, an existing destination is replaced. Without it, an existing destination folder ends the element with an exception.

## Examples

Move a folder to the documents folder.

| Parameter | Value |
| --- | --- |
| Source folder | `G:\exampleFolder` |
| Destination folder | `%A_MyDocuments%\exampleFolder` |
