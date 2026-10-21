# Send keystrokes

The action **Send keystrokes** sends simulated keystrokes and mouse clicks to the active window.

## Settings

### Keys or text to send

Specify the keys that will be sent.

If **Raw mode** is selected, the entered string will be sent as is.

If **Raw mode** is not selected, some keys can be declared as described in the section Remarks.

### Method

There are different methods to simulate keyboard events. If the sent keys are not recognized by the application using the default method, you may try to change it.

**Input mode** has best performance and is the recommended one in most cases.

**Event mode** has lower performance.

**Play mode** may require to disable the UAC to work. It may work better in games.

**Input mode** can only be used in one AutoHotFlow instance. If you run multiple AutoHotFlow instances simultanously, the second instance will not be able to use it. Also other applications and AutoHotkey scripts may block the input mode. If **Input mode** is blocked, it will automatically fall back to **Event mode**.

## Remarks

The available keys are listed in the [key list](../../../../../../assets/help/en/Key_list.md).
