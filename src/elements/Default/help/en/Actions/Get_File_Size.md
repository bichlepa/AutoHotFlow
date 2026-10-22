# Get file size

The action **Get file size** stores the size of a file in a variable: in bytes, kilobytes or megabytes. Kilobytes and megabytes are rounded down to whole units.

## Settings

### Output Variable name

The name of the variable that gets the size.

### File path

The path of the file. A relative path is taken from the working directory of the flow.

### Unit

- **Bytes**: the size in bytes.
- **Kilobytes**: the size in kilobytes (1024 bytes), rounded down.
- **Megabytes**: the size in megabytes (1024 kilobytes), rounded down.

## Behavior

A file that does not exist, and a folder, end the element with an exception.

## Examples

Store the size of a file in megabytes in the variable `size`.

| Parameter | Value |
| --- | --- |
| Output Variable name | `size` |
| File path | `%A_MyDocuments%\example.zip` |
| Unit | Megabytes |
