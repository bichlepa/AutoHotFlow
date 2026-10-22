# Loop through files

The loop **Loop through files** runs its body once for each file, folder or both that a path or wildcard pattern finds. In every pass the variables of the file are set, so the body can use them.

## Settings

### File path

The path or wildcard pattern, such as `%A_MyDocuments%\exampleFolder\*.txt`. A relative path is taken from the working directory of the flow.

### Options

- **Operate on files**: only files are passed.
- **Operate on files and folders**: files and folders are passed.
- **Operate on folders**: only folders are passed.
- **Recurse into subfolders**: the subfolders are searched as well.

## Variables in the body

| Variable | Content |
| --- | --- |
| `A_LoopFileName` | the name of the file or folder |
| `A_LoopFileNameNoExt` | the name without the extension |
| `A_LoopFileExt` | the extension, without the dot |
| `A_LoopFilePath` | the path as the pattern gives it |
| `A_LoopFileLongPath` | the full path |
| `A_LoopFileShortPath`, `A_LoopFileShortName` | the 8.3 path and name (may be empty) |
| `A_LoopFileDir` | the folder that contains the file |
| `A_LoopFileTimeModified`, `A_LoopFileTimeCreated`, `A_LoopFileTimeAccessed` | the times (`YYYYMMDDHHMISS`) |
| `A_LoopFileAttrib` | the attributes |
| `A_LoopFileSize`, `A_LoopFileSizeKB`, `A_LoopFileSizeMB` | the size in bytes, kilobytes and megabytes |
| `A_Index` | the number of the pass, from 1 |

## Behavior

The list of files is made once, at the start of the loop. A file that the body creates or deletes does not change the passes. A pattern without a match gives no pass at all.

## Examples

Write the name of every text file of a folder to a list, one pass per file.

| Parameter | Value |
| --- | --- |
| File path | `%A_MyDocuments%\exampleFolder\*.txt` |
| Options | Operate on files |

The body of the loop adds `%A_LoopFileName%` to a list.
