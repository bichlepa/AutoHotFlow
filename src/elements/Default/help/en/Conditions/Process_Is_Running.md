# Process is running

The condition **Process is running** checks whether a process is running. It answers **yes** when a process with the name or the ID exists and **no** otherwise.

## Settings

### Process name or ID

The name of the process, for example `notepad.exe`, or its process ID (a number). The name is not case-sensitive. An empty field is an exception.

## Supplied variables

### `A_Pid`

The process ID of the first matching process (only when the answer is yes).
