# Random number

The action **Random number** writes a random number into a variable. The number lies between the minimum and the maximum value, both included.

## Settings

### Variable name

Name of the variable which will contain the random number.

### Minimum value and Maximum value

A number, a variable or an expression. If both values are whole numbers, the result is a whole number. If one of them has a decimal point, the result is a decimal number.

If the minimum is greater than the maximum, the two values are used in the other order.

## Remarks

The random number generator has no seed: the same flow gives other numbers at every run.

## Examples

Get a whole number between 1 and 10.

| Parameter | Value |
| --- | --- |
| Minimum value | `1` |
| Maximum value | `10` |

Get a decimal number between -10 and 10.

| Parameter | Value |
| --- | --- |
| Minimum value | `-10.0` |
| Maximum value | `10.0` |
