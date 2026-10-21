# Get control text

The action **Get control text** retrieves a text from a control.

## Settings

### Output variable name

Name of the variable which will contain the retrieved control text.

### Control identification

You can choose a **method for control identification**:

If **Text in control** is selected, a control will be identified by its text, which must contain the entered string.

If **Classname and instance number of the control** is selected, the control will be identified by its unique classname and instance number. Usually this identifier is always the same in every instance of the window.

If **Unique control ID** is selected, the control will be identified by it unique ID. This ID is different in every instance of the window. So, if a window is closed and opened again, the ID of the same control is different.

Choose whether the **control identification** start with, contain anywhere oder be exactly the specified value.

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

### `A_WindowID`

The unique ID of the found window.

### `A_ControlID`

The unique ID of the found control.
