# Screenshot

The action **Screenshot** makes a screenshot of the screen, a screen region or a window.

## Settings

### Output

Name and path of the file which will contain the screenshot image. The file path is assumed to be in the working directory if an absolute path isn't specified.

Supported file formats are BMP, DIB, RLE, JPG, JPEG, JPE, JFIF, GIF, TIF, TIFF and PNG. The extension must be set.

### Screen region

The screenshot can contain either the whole screen, a defined region or a specified window.

### Which screen

If screen region **Whole screen** is selected, this will be the screen. Specify, whether the screenshot should contain all screens or only one.

### Coordinates

If screen region **Whole screen** is selected, this will be the screen. Specify the rectangle region which the screenshot should contain.

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

### Method

When making a screenshot of a window, there are three different methods. If a method does not work, try an other one.

**Method 1** and **Method 2** can make a screenshot of them even if they are behind an other window.

**Method 3** captures the screen region where the window currently is. Windows which are in front of the specified one will be visible in the screenshot.

## Supplied Variables

### `A_WindowID`

Only if **Screen region → Specified window** is selected. It contains the unique ID of the found window.
