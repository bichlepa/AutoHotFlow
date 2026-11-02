# Time of day

The trigger **Time of day** triggers at a specified time of day, on the selected week days.

## Settings

### Weekdays

Weekdays on which the flow will start. If no week day is selected, the trigger is not enabled: the setting says that the parameter is empty.

### Time of day

Time when the flow will start. Only the time is used; the date of the value is ignored.

## Remarks

The next time is computed when the trigger is enabled and after every start. A change of the clock of the computer is taken into account when the time comes: a time that is reached early (the clock was set back) waits for the rest, and a time that is reached late (the clock was set forward, or the computer was in standby) still starts the flow. A time that was missed in standby is not started afterwards (MIGRATION M-0164).
