# Rename folder

The action **Rename folder** gives a folder a new name. The folder stays in its parent folder.

## Settings

### Source folder

The path of the folder. A relative path is taken from the working directory of the flow.

### New folder name

The new name, without a path. A folder with that name must not exist already. A wildcard is not allowed.

## Examples

Rename a folder on the desktop.

| Parameter | Value |
| --- | --- |
| Source folder | `%A_Desktop%\old folder` |
| New folder name | `new folder` |
