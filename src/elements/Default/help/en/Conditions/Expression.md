# Expression

The condition **Expression** calculates an expression and decides between **Yes** and **No**. It is similar to an `if` statement in other programming languages.

## Settings

### Expression

The expression to calculate, in the expression language of AutoHotFlow (see [Variables and expressions](../../../../../../assets/help/en/Variables.md)). The condition ends with **Yes** if the result is true, and with **No** if it is false. A number that is not 0 is true, 0 is false.

Examples:

- `count >= 10 and name = "Paul"`: yes if the variable `count` is at least 10 and the variable `name` is `Paul`
- `not done`: yes if the variable `done` is 0
- `(x + 1) // 2 = 3`: yes if `x` is 5 or 6 (`//` divides and keeps the whole part)

If the expression cannot be read or calculated, the condition ends with **exception**. An empty expression is an error too.
