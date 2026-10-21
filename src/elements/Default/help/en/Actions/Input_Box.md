# Input box

The action **Input box** displays an input box to ask the user to enter a string or number.

## Settings

### Output variable name

Name of the variable which will contain the user input.

### Title *and* Message

Message shown to the user.

### Edit field

If **Only allow numbers** is selected, it will prevent the user from typing anything other than digits into the field (however, it is still possible to paste non-digits into it).

If **Mask user's input** is selected, it will hide the user's input (such as for password entry) by substituting masking characters for what the user types

If **Use a multiline edit field** is selected, the edit field will have multiple lines. The count of lines may be specified.

If **Default value** contains some text, the edit field will contain that text when the dialog first appears.

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
