# Window gets inactive

The trigger **Window gets inactive** triggers whenever a window that matches the window identification stops being the active window, because another window or no window is active.

The window that is active when the flow is enabled is the starting point. The active window is checked at a fixed interval (see **Check interval**).

## Settings

### Window identification

**Title of window**: The window title, compared as chosen next to it: it starts with, contains or is exactly the specified text.

**Exclude title**: Windows whose titles include this text are not considered.

**Text of a control in window**: A text of one control of the window. It can be chosen whether hidden text is found.

**Exclude text of a control in window**: Windows whose controls include this text are not considered.

**Window class**: The class name of the window. It tells what kind of window it is.

**Process name**: The name of the executable that created the window.

**Unique window ID**: The handle of the window. It stays the same when the title changes.

**Unique process ID**: The ID of the process that owns the window.

**Hidden window**: If detect hidden window is selected, a window that exists but is not visible is found too.

**Import window identification**: Uses a wizard to take the parameters of a window.

At least the **Title of window**, the **Window class**, the **Process name**, the **Unique window ID** or the **Unique process ID** must be set. Otherwise the trigger is not armed and says that no window is specified.

### Options

**Check interval (ms)**: The time between two checks in milliseconds (default 500). An interval that is not above 0 is refused, and the trigger is not armed.

## Supplied Variables

### `A_WindowID`

The unique ID of the window that lost the focus.
