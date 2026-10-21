# Confirmation dialog

The condition **Confirmation dialog** shows a window with a question and the buttons **Yes** and **No**. The result of the button decides the branch.

## Settings

### Title and message

The title and the question. The text may be an object, which is shown as JSON.

### Button text

The texts of the **Yes** and **No** buttons.

### Timeout

If **Define timeout** is checked, the window closes after the given time. **Result on timeout** then sets the result: **Yes**, **No** or **Throw exception** (exception: "Timeout reached").

### Width and height

The size of the window, in pixels.

### Cancelling

If **Show cancel button** is checked, a third button is shown; its text can be changed. **Result if cancelled** sets the result when it is pressed, or when the window is closed: **Yes**, **No** or **Throw exception** (exception: "User cancelled the dialog", or "User closed the dialog" for the close button and Esc).

### Default button

The button that is highlighted and focused when the window opens.
