# Delete folder

The action **Delete folder** deletes a folder. Be careful with this action: data can be lost.

## Settings

### Folder path

The path of the folder. A relative path is taken from the working directory of the flow.

### Remove only if the folder is empty

If checked, the folder is deleted only when it contains no file and no folder. If not checked, the folder is deleted with everything in it.

### Throw exception if folder does not exist

If checked, a folder that does not exist ends the element with an exception. If not checked, the element ends normally with a message.

## Examples

Delete a folder with its contents from the documents folder.

| Parameter | Value |
| --- | --- |
| Folder path | `%A_MyDocuments%\ExampleFolder` |
| Remove only if the folder is empty | off |
