# Write to file

The action **Write to file** writes some text to a file.

## Settings

### Text to write

Text that will be written to the file.

### File path

Path of the file. The file path is assumed to be in the working directory if an absolute path isn't specified.

### Encoding

The text in the files may be encoded differently.

UTF-8 is the recommended encoding.

### Append or overwrite

If **Append** is selected and the specified file exists, the existing file will remain and text will be written to the end of the file.

If **Overwrite** is selected and the specified file exists, the file will be overwritten.

### Linefeed

A line break can be represented either by a single linefeed character or by the two characters linefeed and carriage return.

Standard text files in windows use both characters, a linefeed and a carriage return, when there is a line break.
