# Shortcut

The trigger **Shortcut** reates a shortcut file which can be launched to trigger the flow.

## Settings

### Path of the shortcut

Path of the shortcut file. The file path is assumed to be in the working directory if an absolute path isn't specified. The shortcut must have the extension `.lnk`

### Options

If Remove shortcut when disabling is selected, the shortcut will be deleted, when the trigger is disabled.

## Remarks

The shortcut will not trigger the flow if it is disabled.

If AutoHotFlow is not running, the shortcut will start it. After start, it will trigger the flow, if the trigger is enabled.
