# Delete file

The action **Delete file** deletes one file, or all files that match a wildcard pattern. Be careful with this action: data can be lost.

## Settings

### Source file

The path of a file, or a wildcard pattern such as `G:\*` or `*.txt`. A relative path is taken from the working directory of the flow.

### Delete method

- **Delete**: the file is deleted.
- **Recycle**: the file is sent to the recycle bin. Where Windows has no recycle bin for the file, it is deleted.

A read-only file is not deleted. Change its attribute first.

## Examples

Delete one file from the documents folder.

| Parameter | Value |
| --- | --- |
| Source file | `%A_MyDocuments%\example.txt` |
| Delete method | Recycle |

Delete all text files of the working directory.

| Parameter | Value |
| --- | --- |
| Source file | `*.txt` |
| Delete method | Delete |
