# Get shortcut information

The action **Get shortcut information** reads a shortcut file (`.lnk`) and stores its parts in variables: the target, the arguments, the working folder, the description, the icon, the icon number and the run mode.

## Settings

### Shortcut path

The path of the shortcut file. A relative path is taken from the working directory of the flow.

### Output variables

One variable name for each part. A part whose name is empty is not stored.

- **Target path**: the file that the shortcut starts (without the arguments).
- **Target arguments**, **Working directory**, **Description**, **Icon path**, **Icon number**.
- **Run mode**: the text `Normal`, `Maximized` or `Minimized`; another value is shown as `Unknown (n)`.

## Behavior

A shortcut that cannot be read, or a file that is not a shortcut, ends the element with an exception.

## Examples

Read the target of a shortcut into the variable `target`.

| Parameter | Value |
| --- | --- |
| Shortcut path | `%A_MyDocuments%\example.lnk` |
| Target path | `target` |
