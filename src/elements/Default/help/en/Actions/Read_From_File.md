# Read from file

The action **Read from file** reads the content of a file into a variable.

## Settings

### Output variable name

The variable that receives the text of the file.

### File path

The path of the file. A relative path is taken from the working directory of the flow. `%name%` variables in the path are replaced first.

### Encoding

The encoding of the text in the file. If it is not set correctly, some characters cannot be read.

- **Raw data**: the bytes of the file, one character per byte (ISO-8859-1). Use it for binary files; the variable holds no binary buffer, and a byte with the value 0 ends the text.
- **System default ANSI codepage**: the codepage of the Windows language setting.
- **Unicode UTF-8** and **Unicode UTF-16**: a byte order mark in the file decides over the choice.
- **Other**: the code page with the number that you enter in the field below.

### Size limit

If enabled, only the first bytes of the file are read. The number must be a positive whole number.

### Linefeed

If enabled, Windows line breaks (carriage return and linefeed) become single linefeeds. Not used with raw data.

## Examples

Read a text file that is written with UTF-8 into the variable `FileText`, with the default settings.

| Parameter | Value |
| --- | --- |
| Output variable name | `FileText` |
| File path | `%A_MyDocuments%\notes.txt` |
| Encoding | Unicode UTF-8 |
