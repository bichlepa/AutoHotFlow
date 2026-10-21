# AutoHotkey script

The action **AutoHotkey script** executes an AutoHotkey script in a new AutoHotkey thread.

> **Warning:** Don't use that action if you don't master the AutoHotkey scripting language.

> **Warning:** If the AutoHotkey script crashes, AHF may crash too.

> **Note:** This action has low performance, since a new AutoHotkey thread must be started.

## Settings

### AutoHotkey script

Script that will be executed. Use the function x_trigger() to trigger the trigger.

### Variables that should be imported to script before enabling

Specify a list of variables that should be imported to the AutoHotkey script before it gets enabled.

The list can be separated either by a space, linefeed, comma or tab.

The variables will be available in global scope.

### Variables that should be exported from script on trigger

Specify a list of variables that should be exported from the AutoHotkey when it calls x_trigger().

The list can be separated either by a space, linefeed, comma or tab.

The variables must be available in global scope and will be accessible in the flow with same..

> **Note:** The variables must not start with `A_`.

## Remarks

The script may reach the bottom, there will be a `return` statement. It already contains the command `#persistent`.

The script may be stopped with `exitapp`. If it stops, nothing will happen and the trigger will still appear as active.

Do not use command `onexit`.

Do not use functions `EnterCriticalSection()` and `LeaveCriticalSection()` as well as other AHK_H specific functions.

Do not use variable, function and label names which start with `ahf_`.

Do not use the working directory (variable `a_workingDir` or relative paths). The working directory cannot be set per AHK thread and if AHF or an other AHK script changes it, it will be changed for this script, too. However (even if not userful), since AHF does not use the working directory, it is safe to change the working directory using command `SetWorkingDir`.

The variable `A_FlowWorkingDir` will contain the working directory of the flow.
