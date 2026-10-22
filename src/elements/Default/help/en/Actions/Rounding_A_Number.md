# Rounding a number

The action **Rounding a number** rounds a number to a number of digits after the decimal point, or to a multiple of a power of ten.

## Settings

### Output variable name

Name of the variable which will contain the result.

### Input number

The input number.

### Places after comma

If this field contains 0, the result is rounded to a whole number and is a whole number.

If it contains a positive whole number, that many digits after the decimal point remain.

If it contains a negative whole number, that many digits before the decimal point become zero (`-2` rounds `1234` to `1200`). A decimal fraction in this field is cut off.

### Operation

Round normally gives the nearest value.

Round up gives the next value towards plus infinity at that place (`1.21` at one place is `1.3`, `-1.29` is `-1.2`).

Round down gives the next value towards minus infinity at that place (`1.29` at one place is `1.2`, `-1.21` is `-1.3`).
