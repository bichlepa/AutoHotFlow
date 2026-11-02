# Input box

The action **Input box** shows a window that asks the user for a text or a number. The text goes into the output variable. The action ends when the user has pressed a button, has closed the window, or when the timeout has run out.

## Settings

### Output variable name

The name of the variable that receives the text the user typed. It is empty when the user did not press OK (see Results below).

### Title and message

The title of the window and the text above the input field. The message may be an object, which is shown as JSON.

### Edit field

- **Only allow numbers**: the user can type digits only. Pasting other characters is still possible.
- **Mask user's input**: the typed characters are hidden, for example for a password. This does not work together with **Only allow numbers** or **Use a multiline edit field**; the settings disable the one that does not apply.
- **Use a multiline edit field**: the field has several lines. **Count of lines** sets how many lines the field has.
- **Default value**: the text the field contains when the window opens.

### Button Text

The text of the **OK** button.

### Timeout

- **No timeout**: the window stays open until the user closes it.
- **Define timeout**: the window closes after the given time (in seconds, minutes or hours). The window shows the seconds that are left. The result for a timeout is set under **Result on timeout**: **Normal** or **Throw exception** (exception: "Timeout reached").

### Width and height

The size of the window, in pixels (default 300 by 250). Make sure that the window is not too small for its text.

### Cancelling

If **Show cancel button** is checked, a second button is shown; its text is set under **Button text**. **Result if cancelled** sets what happens when it is pressed: **Normal**, or **Throw exception** (exception: "User cancelled the dialog").

Closing the window with its close button or with Esc is set by **Result if closed**: **Normal** or **Throw exception** (exception: "User closed the dialog").

## Results

- **OK**: the output variable holds the text of the field, and the action ends normally.
- **Cancel button, close button or Esc, timeout**: the output variable is empty. The action ends normally or with an exception, as set above.

## Supplied Variables

### `A_UserAction`

The way the window was ended, as a text in lower case:

- **ok**: the user pressed the OK button
- **timeout**: the timeout has run out
- **cancel**: the user pressed the cancel button
- **close**: the user closed the window or pressed Esc

Compare it with `=`, which ignores the case. The comparison with `==` is case sensitive: `A_UserAction == "OK"` is never true.
