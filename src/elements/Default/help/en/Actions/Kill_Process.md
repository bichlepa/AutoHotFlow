# Kill process

The action **Kill process** ends a process at once. The process does not get the chance to save its data.

> **Warning:** Be careful using that action. It may cause loss of data.

## Settings

### Process name or ID

The name of the process, for example `notepad.exe`, or its process ID (a number). With a name, the first process of that name is ended. The name is not case-sensitive.

An empty field is an exception: the action does not end any process.

If the process still runs after the action (for example because Windows denies access), the action ends with an exception.

## Supplied variables

### `A_Pid`

The process ID of the ended process.

## Examples

End the process with the ID that an earlier Run action stored in `A_Pid`.

| Parameter | Value |
| --- | --- |
| Process name or ID | `%A_Pid%` |
