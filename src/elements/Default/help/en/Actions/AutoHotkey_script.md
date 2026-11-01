# AutoHotkey script

The action **AutoHotkey script** runs an AutoHotkey v2 script in a process of its own and waits until the script ends.

> **Warning:** Don't use that action if you don't master the AutoHotkey scripting language.

> **Warning:** The script runs with the rights of AutoHotFlow. It can change files, start programs and send keys.

## Settings

### AutoHotkey script

The AutoHotkey v2 code that is run. The code does not need `#Requires AutoHotkey v2.0`.

### Variables that should be imported to script prior to execution

A list of flow variables. The script gets them as global variables when it starts, with their values (texts, numbers, lists and objects).

The list can be separated by a space, a line break, a comma or a vertical bar.

### Variables that should be exported from script after execution

A list of global variables of the script. When the script ends, their values are set as variables of the flow.

The list can be separated by a space, a line break, a comma or a vertical bar. The names must not start with `A_`.

## Remarks

The script sets the result with the variables `result` and `resultmessage`, as in v1: `result := "exception"` ends the element with the text of `resultmessage`. Without a result the element ends normally.

An error in the script (a syntax error, or an error while the script runs) ends the element with an exception. The line number of the error is the line of your code.

Stopping the flow ends the script at once, and the processes that the script started with it. When the script ends by itself, the processes it started keep running, as in v1.

Do not use names that start with `ahf`: the element uses them.

## Examples

Set the variable `Greeting` in the flow.

| Parameter | Value |
| --- | --- |
| AutoHotkey script | `Greeting := "Hello from AutoHotkey"` |
| Variables that should be exported from script after execution | `Greeting` |
