# Create folder

The action **Create folder** creates a folder. Missing folders above it are created too.

## Settings

### Folder path

The path of the folder. A relative path is taken from the working directory of the flow.

### Throw exception if folder already exists

If checked, an existing folder ends the element with an exception. If not checked, nothing happens when the folder exists. A file with the same name always ends the element with an exception.

## Examples

Create a folder in the documents folder.

| Parameter | Value |
| --- | --- |
| Folder path | `%A_MyDocuments%\ExampleFolder` |
