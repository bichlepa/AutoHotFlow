# Condition

The loop **Condition** evaluates an expression on each iteraction and continues only if the condition result is true.

## Settings

### Condition

Expression to evaluate on each iteration.

If **Evaluate on first iteration** is checked, the condition will be checked before first iteration. If it is not checked, the first iteration will be always performed, with no regard whether the condition is true or not.

*Examples:*

- `a_index <= 10` *(performs 10 iterations)*
- `VariableContainingBreakCondition` *(continues as long as the variable is not false)*

## Supplied Variables

### `A_Index`

Index of the current iteration. It starts with the value 1 and increases on every loop.

## Remarks

The supplied variable will be removed after last iteration.

Read more about expressions in the chapter [Variables](../../../../../../assets/help/en/Variables.md).
