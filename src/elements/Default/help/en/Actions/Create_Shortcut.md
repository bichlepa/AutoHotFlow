# Create shortcut

The action **Create shortcut** writes a shortcut file (`.lnk`) that starts a target file.

## Settings

### Shortcut path

The path of the shortcut file, including `.lnk`. A relative path is taken from the working directory of the flow. The folder must exist.

### Target path

The file that the shortcut starts.

### Target arguments

The arguments that are passed to the target. The text can be an expression or a raw string, as the field says.

### Working directory

The folder in which the target starts. It is left empty when not set.

### Description

The text that Windows shows as the description of the shortcut.

### Icon path

A file with icons (`.ico`, `.exe` or `.dll`).

### Set icon number

Only with an icon path: the number of the icon in the file, counted from 1. Without it, the first icon is used.

### Run mode

- **Run normally**: the window opens as usual.
- **Run maximized**: the window opens maximized.
- **Run minimized**: the window opens minimized.

## Behavior

If the shortcut cannot be written, the element ends with an exception that names the shortcut.

## Examples

Write a shortcut to a document, which opens maximized.

| Parameter | Value |
| --- | --- |
| Shortcut path | `%A_MyDocuments%\example.lnk` |
| Target path | `%A_MyDocuments%\example.txt` |
| Run mode | Run maximized |
