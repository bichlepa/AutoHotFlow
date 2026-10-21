# Message box

The action **Message box** shows a window with a message and a button. The action ends when the user has closed the window, or when the timeout has run out.

## Settings

### Title and message

The title and the text of the window. The text may be an object, which is shown as JSON.

### Button text

The text of the **OK** button.

### Timeout

- **No timeout**: the window stays open until the user closes it.
- **Define timeout**: the window closes after the given time (in seconds, minutes or hours). The result for a timeout is set under **Result on timeout**: **Normal** or **Throw exception** (exception: "Timeout reached").

### Width and height

The size of the window, in pixels (default 300 by 200). Make sure that the window is not too small for its text.

### Cancelling

If **Show cancel button** is checked, a second button is shown; its text is set under **Button text**. **Result if cancelled** sets what happens when it is pressed: **Normal**, or **Throw exception** (exception: "User cancelled the dialog").

Closing the window with its close button or with Esc is set by **Result if closed**: **Normal** or **Throw exception** (exception: "User closed the dialog").

## Supplied Variables

### `A_UserAction`

The way the window was closed, as a text in lower case:

- **ok**: the user pressed the OK button
- **timeout**: the timeout has run out
- **cancel**: the user pressed the cancel button
- **close**: the user closed the window or pressed Esc

Compare it with `=`, which ignores the case. The comparison with `==` is case sensitive: `A_UserAction == "OK"` is never true.
