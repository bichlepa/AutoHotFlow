# Trace point check

The action **Trace point check** is used to debug the flow.

Trace points can be added anywhere in the flow with the action **Trace point**. With this action it is possible to check which trace points have passed.

You can define freely which trace points must have beed passed and which mustn't have been passed. You can also ignore any trace point.

## Settings

### Trace points which must have been passed

If **All trace points** is checked, all trace points will be checked.

You may exclude some trace points under **Trace points which must not have been passed**.

If **All trace points** is not checked, you can select which trace point will be checked. It is allowed not to select any trace point.

The action will throw an exception if any of the selected tracepoints have not passed until the moment when this action is executed.

### Trace points which must not have been passed

If **All trace points** is checked, all trace points will be checked.

You may exclude some trace points under **Trace points which must have been passed**.

If **All trace points** is not checked, you can select which trace point will be checked. It is allowed not to select any trace point.

The action will throw an exception if any of the selected tracepoints have passed until the moment when this action is executed.
