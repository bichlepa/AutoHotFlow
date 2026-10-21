# Delete folder

The action **Delete folder** deletes a folder.

> **Warning:** Be careful using that action. It may cause loss of data.

## Settings

### Folder path

Path of the directory to delete.

The folder path is assumed to be in the working directory if an absolute path isn't specified.

### Options

If **Remove only if the folder is empty** is selected, the folder will not be deleted, if it contains any file or folder.

### Error handling

If **Throw exception if folder does not exist** is not selected, nothing will happen, if the folder doesn't exists.

## Examples

Delete one folder from MyDocuments folder.

| Parameter | Value |
| --- | --- |
| Folder path | `%A_MyDocuments%\ExampleFolder` |
