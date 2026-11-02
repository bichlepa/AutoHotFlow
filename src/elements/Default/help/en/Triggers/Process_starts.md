# Process starts

The trigger **Process starts** triggers whenever a process starts whose name or ID matches the setting.

## Settings

### Process name or ID

The name of the process (for example `notepad.exe`; not case-sensitive) or its process ID. The name is the base name of the program, without its folder.

This field can be left empty: then the trigger fires for every process that starts.

### Options

**Do not trigger if a matching window exists when enabling the trigger**: The label is the one of AutoHotFlow 1.x and says "window", but it means a matching process. When set (the default), the processes that run when the flow is enabled do not trigger it. When not set, every matching process fires at the first check.

**Check interval (ms)**: The time between two checks in milliseconds (default 1000). An interval that is not above 0 is refused, and the trigger is not armed.

> **Note:** The checks run at the interval below. A process that starts and ends between two checks is not seen.

## Supplied Variables

### `A_ProcessID`

ID of the started process.

### `A_ProcessName`

Name of the started process.
