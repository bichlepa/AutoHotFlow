# Execute flow

The action **Execute flow** starts a manual trigger of a flow, and so runs the flow (or another flow) once more.

## Settings

### Which flow

**This flow** runs the flow that contains the action. Uncheck it to choose another flow in the list.

### Which trigger

- **Default trigger**: the flow's first manual trigger.
- **Specified trigger**: the manual trigger that you choose in the list.

The trigger must be enabled. If it is not, the action ends with an exception, unless **Skip disabled flows without error** is checked.

### Options

- **Send local variables**: the local variables of the calling instance are passed to the called flow (checked by default).
- **Wait for called flow to finish**: the action waits until the called instance has ended. It then ends with the result **normal** if the called flow ended normally, and with **exception** if the called flow ended with an exception or was stopped.
- **Return local variables to the calling flow**: after the called flow has finished, its variables are passed back to the calling flow.
- **Skip disabled flows without error**: a disabled trigger does not end the action with an exception; the action ends with **normal** and does nothing.

Without **Wait for called flow to finish** the action ends with **normal** as soon as the call is started.

The action ends with an exception if the flow does not exist or has no manual trigger.
