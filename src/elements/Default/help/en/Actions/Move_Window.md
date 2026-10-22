# Move window

The action **Move window** maximizes, minimizes or restores a specified window, or moves and resizes it.

## Settings

### Event

**Maximize**, **Minimize** and **Restore** change the state of the window. **Move** sets the position and the size.

### Coordinates and size

Only for **Move**: the position (x and y) and the width and height of the window, in screen coordinates. An empty or non-numeric value is an exception, and the window is not changed.

**Grab coordinates from existing window**: The assistant takes the position and size of the window under the mouse (the same way as the window identification).

### Window identification

**Title of window**: The title of the window, compared in the way chosen with the next setting: **Starts with**, **Contains anywhere** or **Exactly**.

**Exclude title**: Windows whose titles include this value are not considered.

**Text of a control in window**: If present, a text of a control of the window (a substring of one text element, compared in the same way as the title). **Detect hidden text** also finds text of hidden controls.

**Exclude text of a control in window**: Windows that have a control with this text are not considered.

**Window class**: The window class that Windows uses to create the window. It tells what type of window it is.

**Process name**: The name of the program that created the window, for example `notepad.exe`.

**Unique window ID**: The handle of the window (HWND). It identifies the window even when its title changes.

**Unique process ID**: The process ID. It identifies the windows of one running program.

**Detect hidden window**: A window that exists but is not visible is found as well.

**Import window identification**: The assistant takes the window under the mouse (click **Import window identification**, then move the mouse over the window and press **OK**). The title, class and process name are filled in; the unique IDs only when the box asks for them.

At least **Title of window**, **Window class**, **Process name**, **Unique window ID** or **Unique process ID** must be set. Without one of them the action ends with an exception.

## Supplied variables

### `A_WindowID`

The unique ID of the found window.
