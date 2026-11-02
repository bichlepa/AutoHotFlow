# Process closes

The trigger **Process closes** triggers whenever a process closes whose name or ID matches the setting.

## Settings

### Process name or ID

The name of the process (for example `notepad.exe`; not case-sensitive) or its process ID. The name is the base name of the program, without its folder.

This field can be left empty: then the trigger fires for every process that closes.

The processes that the trigger can see are those that AutoHotFlow can open for reading. A process that is protected by Windows is not in the list, so it is neither seen starting nor closing.

### Options

**Check interval (ms)**: The time between two checks in milliseconds (default 1000). An interval that is not above 0 is refused, and the trigger is not armed.

> **Note:** The checks run at the interval below. A process that starts and ends between two checks is not seen.

## Supplied Variables

### `A_ProcessID`

ID of the closed process.

### `A_ProcessName`

Name of the closed process.
