# Shortcut

The trigger **Shortcut** creates a shortcut file. Started, the shortcut starts AutoHotFlow and runs this flow at this trigger.

## Settings

### Path of the shortcut

The path of the shortcut file. It must be an absolute path (for example `C:\Users\you\Desktop\Start my flow.lnk`) and end with `.lnk`. The folder must exist. The default is a file on the desktop.

### Options

If "Remove shortcut when disabling" is selected, the shortcut file is deleted when you switch the trigger off or change its path. It is kept when AutoHotFlow closes.

## Remarks

The shortcut file is written when the trigger is enabled. If the file cannot be written, the trigger shows the error and stays enabled.

A shortcut does nothing while its trigger is switched off. AutoHotFlow then logs the reason.

If AutoHotFlow is not running, the shortcut starts it. The flow starts as soon as AutoHotFlow is ready. The manager window does not open in this case.

If AutoHotFlow is already running, the shortcut passes its command to the running instance, and that instance starts the flow.
