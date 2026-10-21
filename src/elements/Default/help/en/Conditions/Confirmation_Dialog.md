# Confirmation dialog

The condition **Confirmation dialog** displays a dialog window with a message and the buttons "Yes" and "No".

## Settings

### **Title and **Message**>**

Message shown to the user.

### Button text

You may change the text in the **Yes** and **No** buttons.

### Timeout

If **Define timeout** is selected, the dialog will automatically close after the specified amount of time.

You can select the result if the timer runs out.

### Width and height

Specify the size of the window that will be shown. Make sure, that the window is not too small.

### Cancelling

If **Show cancel button** is selected, a third button will be shown. The text can be modified.

You can select the result if the cancels or closes the dialog.

### Default button

You can specify which button should be the default one.

The default button will be highlighted and focused when the dialog opens.

## Supplied Variables

### `A_UserAction`

The operation used to close the dialog. Can be one of:

**yes**: when the user pressed the Yes-button

**no**: when the user pressed the No-button

**timeout**: when the dialog was closed by a timeout

**cancel**: when the user pressed the back key and the appropriate option is set
