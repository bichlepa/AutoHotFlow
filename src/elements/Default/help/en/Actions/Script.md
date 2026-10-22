# Script

The action **Script** runs a few statements of the expression language. It is for what a chain of elements would make long: setting several variables, or a small calculation with a condition.

> **Warning:** This action is experimental. The scripting language is not complete: there are no loops, no error handling and no own functions yet. Changes that break existing scripts are possible in later versions.

## Settings

### Script

The statements, one per line. The variables of the script are the variables of the flow, named as everywhere else: a name with the prefix `global_` is global, `static_` is static, any other name belongs to the running instance (see the help page "Variables").

The statements are:

- an assignment, for example `x := 2 * 3` or `list.1 := "first"`;
- a call of a function, for example `y := round(x / 3, 2)`;
- an `if` with a statement or a block `{ ... }` behind it, optionally an `else`.

```
total := price * count
if total > 100 {
    discount := 10
} else {
    discount := 0
}
```

A line with only a value (`1 + 1`) is an error: the script has no result. The action ends with an exception when the script cannot be read or a statement fails. The text `%name%` is not replaced in the script.

## Remarks

The action sets variables only through assignments in the script. The value of the last line is not stored anywhere.

Within a script a calculation that fails (for example a division by zero) is a warning and does not stop the action, unless the flow is in strict mode: then it ends with an exception. A variable that does not exist is empty.
