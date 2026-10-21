# AutoHotkey script

The trigger **AutoHotkey script** executes an AutoHotkey script in a new AutoHotkey thread. If the funciton x_trigger() will be called in the AutoHotkey script, it will trigger the trigger.

> **Warning:** Don't use that action if you don't master the AutoHotkey scripting language.

> **Warning:** If the AutoHotkey script crashes, AHF may crash too.

## Settings

### AutoHotkey script

Script that will be executed.

### Variables that should be imported to script prior to execution

Specify a list of variables that should be imported to the AutoHotkey script prior to execution.

The list can be separated either by a space, linefeed, comma or tab.

The variables will be available in global scope.

### Variables that should be exported from script after execution

Specify a list of variables that should be exported from the AutoHotkey script after execution.

The list can be separated either by a space, linefeed, comma or tab.

The variables must be available in global scope and will be accessible in the flow with same.

> **Note:** The variables must not start with `A_`.

## Supplied Variables

### `A_ManualTriggerID`

The **ID** of the manual trigger.

## Remarks

If the script reaches the bottom, it will end and won't be able to trigger, even if it is persistent.

The script may be stopped with `exitapp`.

Do not use command `onexit`.

Do not use functions `EnterCriticalSection()` and `LeaveCriticalSection()` as well as other AHK_H specific functions.

Do not use variable, function and label names which start with `ahf_`.
