# Hotstring

The trigger **Hotstring** triggers whenever the user presses a specified text. It may also replace the entered text with another text.

## Settings

### Hotstring

Specify the text that should be entered in order to trigger the flow.

### Options

If **Require an ending character** is checked, the hotstring must be finished by an ending character. Ending characters are `-()[]{}':;"/\,.?!`, a linefeed, a space and a tabulator. If it is not checked, it will trigger immediately after the text was entered.

If **Omit the ending character after replacement** is checked, the ending character will be blocked. Otherwise it will be sent after the replacement.

If **Trigger inside another word** is checked, the hotstring will be detected even if it is inside another word. For example, the **Hotstring** `al` will be triggered if user enters `practical`.

If **Case sensitive** is not checked, the hotstring will be triggered even if the case of the entered text is different.

If **Backspace automatically the entered hotstring** is checked, the text will be backspaced before the **Replace text** is entered.

If **Reset hotstring recognizer after each triggering** is checked, the hotsring recognition will be reset after each trigger. For example, if the **Hotstring** is `aa`, typing `aaa` will trigger twice.

### Replace text

Specify the text or keys that will be sent.

If **Raw mode** is selected, the entered string will be sent as is.

If **Raw mode** is not selected, some keys can be declared as described in the section Remarks.

### Method

There are different methods to simulate keyboard events. If the sent keys are not recognized by the application using the default method, you may try to change it.

**Input mode** has best performance and is the recommended one in most cases.

**Event mode** has lower performance.

**Play mode** may require to disable the UAC to work. It may work better in games.

**Input mode** can only be used in one AutoHotFlow instance. If you run multiple AutoHotFlow instances simultanously, the second instance will not be able to use it. Also other applications and AutoHotkey scripts may block the input mode. If **Input mode** is blocked, it will automatically fall back to **Event mode**.

### Scope

If **Everywhere** is selected, the hotstring will always trigger, regardless on the currently active window.

If one of the other options is selected, the hotstring will only be active when a specific window is active or exists, or otherwise.

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

### `A_ThisHotstring`

The pressed hotstring as defined in **Hotstring**.

### `A_EndChar`

The pressed end character.

## Remarks

The available keys are listed in the [key list](../../../../../../assets/help/en/Key_list.md).
