# Loop through files

The loop **Loop through files** retrieves the specified files or folders, one at a time.

## Settings

### File path

The path of a single file or folder, or a wildcard pattern.

Both asterisks and question marks are supported as wildcards. A match occurs when the pattern appears in either the file's long/normal name or its 8.3 short name.

The file path is assumed to be in the working directory if an absolute path isn't specified.

### Options

This action can perform on files, forlder or both. It can also iterate in the subfolders.

## Supplied Variables

### `A_Index`

Index of the current iteration. It starts with the value 1 and increases on every loop.

### `A_LoopFileName`

The name of the file or folder currently retrieved (without the path).

### `A_LoopFileNameNoExt`

>The name of the file or folder without extension.

### `A_LoopFileExt`

The file's extension (e.g. TXT, DOC, or EXE). The period (.) is not included.

### `A_LoopFilePath`

The path and name of the file/folder currently retrieved. If **File path** contains a relative path rather than an absolute path, the path here will also be relative. In addition, any short (8.3) folder names in **File path** will still be short (see next item to get the long version).

### `A_LoopFileLongPath`

This is different than A_LoopFileFullPath in the following ways: 1) It always contains the absolute/complete path of the file even if **File path** contains a relative path; 2) Any short (8.3) folder names in **File path** itself are converted to their long names; 3) Characters in **File path** are converted to uppercase or lowercase to match the case stored in the file system. This is useful for converting file names -- such as those passed into a script as command line parameters -- to their exact path names as shown by Explorer.

### `A_LoopFileShortPath`

The 8.3 short path and name of the file/folder currently retrieved. For example: C:\\MYDOCU~1\\ADDRES~1.txt. If File path contains a relative path rather than an absolute path, the path here will also be relative.

> **Note:** This variable will be blank if the file does not have a short name, which can happen on systems where NtfsDisable8dot3NameCreation has been set in the registry. It will also be blank if File path contains a relative path and the body of the loop uses SetWorkingDir to switch away from the working directory in effect for the loop itself.

### `A_LoopFileShortName`

The 8.3 short name, or alternate name of the file. If the file doesn't have one (due to the long name being shorter than 8.3 or perhaps because short-name generation is disabled on an NTFS file system), A_LoopFileName will be retrieved instead.

### `A_LoopFileDir`

The path of the directory in which A_LoopFileName resides. If File path contains a relative path rather than an absolute path, the path here will also be relative. A root directory will not contain a trailing backslash. For example: C:

### `A_LoopFileTimeModified`

The time the file was last modified. Format YYYYMMDDHH24MISS.

### `A_LoopFileTimeCreated`

The time the file was created. Format YYYYMMDDHH24MISS.

### `A_LoopFileTimeAccessed`

The time the file was last accessed. Format YYYYMMDDHH24MISS.

### `A_LoopFileAttrib`

The attributes of the file currently retrieved.

### `A_LoopFileSize`

The size in bytes of the file currently retrieved. Files larger than 4 gigabytes are also supported.

### `A_LoopFileSizeKB`

The size in Kbytes of the file currently retrieved, rounded down to the nearest integer.

### `A_LoopFileSizeMB`

The size in Mbytes of the file currently retrieved, rounded down to the nearest integer.

## Remarks

All supplied variables will be removed after last iteration.
