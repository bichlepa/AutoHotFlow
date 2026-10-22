# Time difference

The action **Time difference** calculates the time between two time stamps.

## Settings

### Output variable name

Name of the variable which will contain the result: the difference as a whole number in the unit below.

### First input time

The first time stamp, a text or an expression. The default is the built-in variable `A_Now`, the current time.

### Second input time

The second time stamp, a text or an expression.

### Which unit

Seconds, Minutes, Hours or Days.

## Remarks

The result is the first time stamp minus the second one: a positive result means that the first time is later. Both time stamps must be valid; otherwise the action ends with an exception.
