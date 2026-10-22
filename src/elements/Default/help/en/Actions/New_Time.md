# New time

The action **New time** writes a time stamp into a variable: the current time or a time that you specify.

## Settings

### Variable name

Name of the variable which will contain the time stamp.

### Time

Choose **Current time** or **Specified time**. For a specified time, enter the time stamp in the field. The time stamp has the form `YYYYMMDDHH24MISS` (year, month, day, hour, minute, second); a shorter form such as `20150101` is accepted too. A time stamp that is not valid ends the action with an exception.

## Remarks

The current time is always available in the built-in variable `A_Now`, which has the same form.
