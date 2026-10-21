# Execute flow

The action **Execute flow** executes a flow. The target trigger must be enabled.

## Settings

### Which flow

Choose which flow should be executed.

### Which trigger

Choose which trigger should be executed. You can choose any of the manual triggers.

The trigger must be enabled, otherwise the action will throw an exception by default.

### Options

If **Send local variables** is checked, all local variables from the current instance will be sent to the executed flow.

If **Skip disabled flow** is checked, the action will not throw an error if the target flow is not enabled.

If **Wait for called flow to finish** is checked, the action will wait until the target flow has finished.

If **Return variables to the calling flow** is checked, all generated variables in the target flow will be sent back after it finishes.
