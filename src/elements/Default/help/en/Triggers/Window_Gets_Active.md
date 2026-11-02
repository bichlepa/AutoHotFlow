# Window gets active

The trigger **Window gets active** triggers whenever a window that matches the window identification becomes the active window.

The active window is checked at a fixed interval (see **Check interval**). If the matching window is activated and deactivated between two checks, it is not seen.

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

**Do not trigger if a matching window is active when enabling the trigger**: When set (the default), the window that is active when the flow is enabled does not trigger it. When not set, the matching window fires at the first check if it is active then.

**Check interval (ms)**: The time between two checks in milliseconds (default 500). An interval that is not above 0 is refused, and the trigger is not armed.

## Supplied Variables

### `A_WindowID`

The unique ID of the window that became active.
