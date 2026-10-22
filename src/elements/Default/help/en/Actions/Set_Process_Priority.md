# Set process priority

The action **Set process priority** sets the priority class of a process. The priority decides how much processor time Windows gives the process compared with others.

## Settings

### Process name or ID

The name of the process, for example `notepad.exe`, or its process ID (a number). With a name, the first process of that name is changed. An empty field is an exception.

### Priority

The priority to set: Low, Below normal, Normal, Above normal, High or Realtime.

> **Warning:** A process that is not designed for Realtime priority may reduce the stability of the system if it is set to that level. Realtime needs rights that a normal user may not have; the action then ends with an exception.

## Supplied variables

### `A_Pid`

The process ID of the process.

## Examples

Give the process with a known ID a higher priority.

| Parameter | Value |
| --- | --- |
| Process name or ID | `1234` |
| Priority | High |
