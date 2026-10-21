# Message box

The action **Message box** displays a window with a message.

## Settings

### Title *and* Message

Message shown to the user.

### Button Text

Enter the text which will be shown as the **OK** button.

### Timeout

If **Define timeout** is selected, the dialog will automatically close after the specified amount of time.

**Result on timeout**: If timeout reaches zero, the action will end with the specified result.

### Width and height

Specify the size of the window that will be shown. Make sure, that the window is not too small.

### Cancelling

If **Show cancel button** is selected, a second button near to the OK button will be shown. The text can be specified.

**Result if cancelled**: If uses either closes the window or clicks on the cancel button, the action will end with the specified result.

## Supplied Variables

### `A_UserAction`

The operation used to close the dialog. Can be one of:

**ok**: when the user pressed the OK-button

**timeout**: when the dialog was closed by a timeout

**cancel**: when the user pressed the back key and the appropriate option is set
