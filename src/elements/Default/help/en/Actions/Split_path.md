# Split path

The action **Split path** separates a file name or URL into its name, directory, extension, and drive..

## Settings

### File path

The file path to be analyzed.

### Output variables

Names of the variables that will contain the retrieved path components. The fields may be empty, if those informations are not required.

File name: The file name without its path. The file's extension is included.

Directory: The directory of the file, including drive letter or share name (if present). The final backslash is not included even if the file is located in a drive's root directory.

File extension: The file's extension (e.g. TXT, DOC, or EXE). The dot is not included.

File name without extension: The file name without its path, dot and extension.

**Drive**: The drive letter or server name of the file. If the file is on a local or mapped drive, the variable will be set to the drive letter followed by a colon (no backslash). If the file is on a network path (UNC), the variable will be set to the share name, e.g. `\\Workstation01`

## Remarks

If **File path** contains a filename that lacks a drive letter (that is, it has no path or merely a relative path), **Drive** will be made blank but all the other output variables will be set correctly. Similarly, if there is no path present, **Directory** will be made blank; and if there is a path but no file name present, **File name** and **File extension** will be made blank.

Actual files and directories in the file system are not checked by this command. It simply analyzes the string given in InputVar.

Wildcards (\* and ?) and other characters illegal in filenames are treated the same as legal characters, with the exception of colon, backslash, and period (dot), which are processed according to their nature in delimiting the drive letter, directory, and extension of the file.

Support for URLs: If **File path** contains a colon-double-slash, such as `https://domain.com` or `ftp://domain.com`, **Directory** is set to the protocol prefix + domain name + directory (e.g. `https://domain.com/images`) and **Drive** is set to the protocol prefix + domain name (e.g. `https://domain.com`). All other variables are set according to their definitions above.
