# Condition

The loop **Condition** repeats the elements of its **head** connection as long as an expression is true. The connection to **tail** continues after the loop.

## Settings

### Condition

The expression that is checked before every repetition (see [Variables and expressions](../../../../../../assets/help/en/Variables.md)). It is repeated while the result is true.

If **Evaluate on first iteration** is checked (the default), the condition is checked before the first repetition too, so the body may run zero times. If it is not checked, the first repetition always runs, and the condition is checked from the second repetition on.

Examples:

- `A_Index <= 10`: ten repetitions
- `not stop`: repeats as long as the variable `stop` is 0

## Supplied Variables

### `A_Index`

The index of the current repetition. It starts with 1 and increases with every repetition. The condition can use it: the check sees the value of `A_Index` that belongs to the repetition that it decides. It is removed after the last repetition.
