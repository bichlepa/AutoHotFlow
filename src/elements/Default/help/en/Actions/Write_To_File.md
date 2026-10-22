# Write to file

The action **Write to file** writes a text to a file. The file is created if it does not exist.

## Settings

### Text to write

The text that is written. It may be a string or an expression.

### File path

The path of the file. A relative path is taken from the working directory of the flow.

### Append or overwrite

- **Append**: the text is written at the end of the existing file.
- **Overwrite**: an existing file is deleted first, then the text is written. Use it with care: data can be lost.

### Encoding

- **UTF-8** is recommended.
- **System default ANSI codepage**, **Unicode UTF-16** and **Other** (the code page number below).

### Add byte order mark (BOM)

For UTF-8 and UTF-16 only: writes a byte order mark when the file is created.

### Linefeed

If enabled, every linefeed in the text is written as a carriage return and a linefeed (the Windows line break). A carriage return and a linefeed that are already in the text stay one line break.

## Examples

Write a line of text to a log file and append it.

| Parameter | Value |
| --- | --- |
| Text to write | `Started` |
| File path | `%A_MyDocuments%\log.txt` |
| Append or overwrite | Append |
| Encoding | Unicode UTF-8 |
