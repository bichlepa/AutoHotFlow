# New variable

The action **New variable** creates a variable and gives it a value. If a variable with this name already exists, its value is replaced, unless **Write only if variable does not exist** is checked.

## Settings

### Variable name

The name of the variable. Variable names are not case sensitive. A name that starts with `A_` cannot be set: the built-in variables (see [Variables and expressions](../../../../../../assets/help/en/Variables.md)) are not written by an action, and the action then ends with the result **exception**.

### Value

The value of the variable. Next to the field, choose whether the value is a **text** or an **expression**:

- A **text** is stored as it is.
- An **expression** is calculated first, and its result is stored. For example `count + 1`, or `"Total: " . sum` for a text together with a variable. Texts in an expression are written in double quotes, and the operator that joins two texts is ` . ` (with a space on both sides).

See [Variables and expressions](../../../../../../assets/help/en/Variables.md) for the rules.

### Write only if variable does not exist

If checked, an existing variable keeps its value. The action then ends with the result **normal** and the message "Variable was not written, because it already exists."
