# Copy folder

The action **Copy folder** copies a folder along with all its sub-folders and files.

## Settings

### Source folder

Path of the source directory (with no trailing backslash).

The folder path is assumed to be in the working directory if an absolute path isn't specified.

### Destination folder

Name of the destination, which is assumed to be in the working directory if an absolute path isn't specified.

If the folder does not exist, it will be created.

### Overwrite

If Overwrite is checked, existing files will be overwritten.

> **Warning:** Be careful using that option. It may cause loss of data.

## Examples

Copy a folder from one drive to MyDocuments folder.

| Parameter | Value |
| --- | --- |
| Source | `G:\exampleFolder` |
| Destination | `%A_MyDocuments%\exampleFolder` |

Copy one folder from desktop to the working directory and rename it.

| Parameter | Value |
| --- | --- |
| Source | `%A_Desktop%\exampleFolder` |
| Destination | `RenamedExampleFolder` |
