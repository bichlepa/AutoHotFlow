# Send keystrokes to control

The action **Send keystrokes to control** sends keys and text to one control of a window. The window does not need the keyboard focus, and the mouse is not moved.

## Settings

### Keys or text to send

The keys and the text to send. The key names are those of **Send keystrokes** (the key list of AutoHotkey v2).

**Raw mode**: the text is sent as it is. The characters `^ + ! # { }` are then sent as text and not as keys.

### Window identification

The window that holds the control: its title (**Title of window** with **Starts with**, **Contains anywhere** or **Exactly**), its class, its process name, or its unique ID. **Detect hidden window** also finds hidden windows. The fields and their meaning are the same as in the other window actions. **Import window identification** takes the window under the mouse.

### Method for control identification

**Text in control**: the control whose text matches (**Start with**, **Contain anywhere** or **Exactly**).

**Classname and instance number of the control**: the class name of the control, with its number, for example `Edit1`.

**Unique control ID**: the handle of the control. The window fields are not needed then.

**Import control and window identification** (the control assistant) takes the window and the control under the mouse.

## Supplied variables

### `A_WindowID` and `A_ControlID`

The unique IDs of the window and of the control, set when the action has found the control.

## Remarks

If the window or the control is not found, the action ends with an error and sends nothing.
