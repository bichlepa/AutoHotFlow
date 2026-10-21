# Number is

The condition **Number is** checks whether a number lies close to an expected number. It decides between **Yes** and **No**.

## Settings

### Input number

The number to check.

### Expected number

The number that the input is compared with.

### Absolute difference

A difference that is always allowed, in the unit of the numbers. The default is 0.

### Relative difference

A difference that is allowed relative to the expected number: `0.01` allows 1 percent of the expected number (its absolute value). The default is 0.01.

The allowed difference is the absolute difference plus the relative difference times the absolute value of the expected number. The condition ends with **Yes** if the input lies within the expected number plus and minus this difference (both ends included), otherwise with **No**.

Example: with the expected number 5, an absolute difference of 0 and a relative difference of 0.01, the input 5.04 gives **Yes** (the allowed difference is 0.05), and 5.1 gives **No**.
