# AutoHotkey script

The trigger **AutoHotkey script** runs an AutoHotkey v2 script in a process of its own while the trigger is armed. Each call of `x_trigger()` in the script fires the trigger.

> **Warning:** Don't use that trigger if you don't master the AutoHotkey scripting language.

> **Warning:** The script runs with the rights of AutoHotFlow. It can change files, start programs and send keys.

## Settings

### AutoHotkey script

The AutoHotkey v2 code that is run while the trigger is armed. The default code calls `x_trigger()` every 10 seconds.

### Variables that should be imported to script prior to execution

A list of flow variables. They are read when the trigger is armed and the script gets them as global variables, with their values.

The list can be separated by a space, a line break, a comma or a vertical bar.

### Variables that should be exported from script after execution

A list of global variables of the script. Each `x_trigger()` sets them as variables of the flow instance that the trigger starts.

The list can be separated by a space, a line break, a comma or a vertical bar. The names must not start with `A_`.

## Remarks

If the script ends by itself, the trigger reports an error and stays armed without effect. Disarming the trigger ends the script at once.

An error in the script (a syntax error, or an error while the script runs) is reported as an error of the trigger; the trigger stays armed.

Do not use names that start with `ahf`: the element uses them.
