# Write to ini

The action **Write to ini** writes a value to a key of a section of an ini file. A file that does not exist is created. The value replaces an existing value of the same key.

## Settings

### Value

The text to write. It can contain variables as text fields do.

### Path of .ini file

The ini file. A relative path is taken from the working directory of the flow. The path must not be a folder.

### Section

The section in which the key is written. An empty name ends the element with an exception.

### Key

The key that gets the value. An empty name ends the element with an exception.

## Behavior

A new file is written as UTF-16 with a byte order mark, as Windows writes ini files. An existing file keeps its encoding. If the file cannot be written, the element ends with an exception.

## Examples

Write the value `Paul` to the key `name` of the section `user`.

| Parameter | Value |
| --- | --- |
| Value | `Paul` |
| Path of .ini file | `%A_MyDocuments%\settings.ini` |
| Section | `user` |
| Key | `name` |
