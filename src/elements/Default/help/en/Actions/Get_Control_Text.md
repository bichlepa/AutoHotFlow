# Get control text

The action **Get control text** reads the text of a control of a window into a variable.

## Settings

### Output variable name

The name of the variable that gets the text of the control.

### Control identification

**Method for control identification**: How the control is found in the window:

- **Text in control**: by its text. The text is compared in the way chosen with **Control identification** below.
- **Classname and instance number of the control**: by its class name with the number, for example `Edit1` (the first edit control of the window). The name is compared exactly.
- **Unique control ID**: by the handle of the control. The handle is different every time the window is opened. With this method no window identification is needed, and the fields of the window identification are disabled.

**Control identification**: For the text: **Starts with**, **Contains anywhere** or **Exactly**.

**Import control and window identification**: The assistant takes the window under the mouse and one of its controls. Select the control in the list of the controls of the window and choose the method with the radio buttons (the class is the default).

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

The unique ID of the window of the control. Not set when the control was identified by its unique control ID.

### `A_ControlID`

The unique ID (handle) of the control.

If the control is not found, the action ends with an exception: "Error! Seeked window does not exist" when the window is missing, "Error! Seeked control does not exist in the specified window" when the window has no such control.
