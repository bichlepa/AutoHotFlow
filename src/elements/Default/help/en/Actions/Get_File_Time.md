# Get file time

The action **Get file time** stores one of the times of a file in a variable. The time is a text in the form `YYYYMMDDHHMISS` in local time, for example `20200102030405`. Do not calculate with it as with a number; use the time elements to compare or change times.

## Settings

### Output Variable name

The name of the variable that gets the time.

### File path

The path of the file or folder. A relative path is taken from the working directory of the flow.

### Which time

- **Modification time**: the time the file was last changed.
- **Creation time**: the time the file was created.
- **Last access time**: the time the file was last read.

## Behavior

A file that does not exist ends the element with an exception.

## Examples

Store the modification time of a document in the variable `changed`.

| Parameter | Value |
| --- | --- |
| Output Variable name | `changed` |
| File path | `%A_MyDocuments%\example.txt` |
| Which time | Modification time |
