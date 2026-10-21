# Hotkey

The trigger **Hotkey** triggers whenever the user presses a specified key or key combination.

## Settings

### Hotkey

Specify one or more keys that should be pressed in order to trigger the flow.

The left field contains the hotkey definition. The right field can be used for quickly retrieving the hotkey definition by pressing the keys (it doesn't work with all key combinations).

A hotkey is defined by its name and optionally some modifiers.

Read more about hotkey definitions in the remarks.

### Options

If **Block key** is checked, the hotkey will not pass though to the active window. For example if the hotkey is `space`, it will not be possible to enter a space anywhere.

If **Trigger even if other keys are held down** is checked, the specified hotkey will fire even if extra modifiers are being held down. For example if the hotkey is `s`, it will also trigger if the user presses the key combination "Control + s".

If **Trigger on release rather than on press** is checked, the specified hotkey will trigger when user releases the hotkey. It will not trigger when the hotkey is pressed and held down.

### Scope

If **Everywhere** is selected, the hotkey will always trigger, regardless on the currently active window.

If one of the other options is selected, the hotkey will only be active when a specific window is active or exists, or otherwise.

### Window identification

**Title of window**: Name of the window title. It can be chosen whether the title starts, contains or ends with the specified string.

**Exclude title**: Windows whose titles include this value will not be considered.

**Text of a control in window**: If present, this parameter must be a substring from a single text element of the target window. It can be specified whether hidden text will be found

**Exclude text of a control in window**: Windows whose text include this value will not be considered

**Window class**: A window class is a set of attributes that the system uses as a template to create a window. In other words, the class name of the window identifies what type of window it is.

**Process name**: The name or path of the executable that created that window.

**Unique window ID**: Each window or control has a unique ID, also known as a HWND (short for handle to window). This ID can be used to identify the window or control even if its title changes.

**Unique process ID**: Use the unique process id to identify a window belonging to a specific process. Each process has its unique ID, even if it has the same executable.

**Hidden window**: If detect hidden window is selected, a window that exists but is not visible will be found.

**Import window identification**: Use a wizard to get parameters of a window.

At least **Title of window**, **Window class**, **Process name**, **Unique window ID** or **Unique process ID** must be set.

## Supplied Variables

### `A_ThisHotkey`

The pressed hotkey as defined in **Hotkey**.

## Remarks

You can use the following modifier symbols to define hotkeys:

| # | Win (Windows logo key). For Windows Vista and later, hotkeys that include the Windows key (e.g. `#a`) will wait for the Windows key to be released before sending any text containing an "L" keystroke. This prevents usages of action **Send Keystrokes** within such a hotkey from locking the PC. This behavior applies to all sending modes except SendPlay (which doesn't need it). |
| --- | --- |
| ! | Alt |
| ^ | Control |
| + | Shift |
| & | An ampersand may be used between any two keys or mouse buttons to combine them into a custom hotkey. |
| < | Use the left key of the pair. e.g. `<!a` is the same as !a except that only the left Alt key will trigger it. |
| > | Use the right key of the pair. |

The available keys are listed in the [key list](../../../../../../assets/help/en/Key_list.md).
