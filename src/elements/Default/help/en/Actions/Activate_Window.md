# Activate window

The action **Activate window** brings a window to the front and makes it the active window. The action waits up to two seconds for the window to become active, then it goes on in any case. A window that Windows does not let come to the front stays inactive, and that is not an exception.

If no window matches the identification, the action ends with the exception "Error! Seeked window does not exist".

## Settings

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
