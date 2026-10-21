# Process starts

The trigger **Process starts** triggers whenever a process starts.

## Settings

### Process name or ID

Name or ID of the process.

This field can be left empty, it will trigger whenever any process starts.

### Options

Specify the check interval in ms.

> **Note:** Be careful if you specify a period smaller than 1000 ms. It might sometimes trigger multiple times when a process starts.

## Supplied Variables

### `A_ProcessID`

ID of the started process.

### `A_ProcessName`

Name of the started process.
