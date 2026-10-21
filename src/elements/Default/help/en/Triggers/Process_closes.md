# Process closes

The trigger **Process closes** triggers whenever a process closes.

## Settings

### Process name or ID

Name or ID of the process.

This field can be left empty, it will trigger whenever any process closes.

### Options

Specify the check interval in ms.

> **Note:** Be careful if you specify a period smaller than 1000 ms. It might sometimes trigger multiple times when a process closes.

## Supplied Variables

### `A_ProcessID`

ID of the closed process.

### `A_ProcessName`

Name of the closed process.
