# Trace point check

The action **Trace point check** tests which trace points (see **Trace point**) have been passed when the action runs. It is used to debug a flow.

You can define which trace points must have been passed and which must not have been passed. You can also leave a trace point out of the test.

## Settings

### Trace points which must have been passed

If **All trace points** is checked, every trace point of the flow must have been passed, except the ones that you select under **Trace points which must not have been passed**. Otherwise, only the selected trace points are checked. Selecting none is allowed.

### Trace points which must not have been passed

If **All trace points** is checked, no trace point may have been passed, except the ones that you select under **Trace points which must have been passed**. Otherwise, only the selected trace points are checked. Selecting none is allowed.

### Result

The action ends with the result **normal** if the test is true. Otherwise it ends with **exception**, and the message names the trace points that were not passed (or were passed, although they must not have been).

Both **All trace points** options together are an error: the action then ends with **exception**.
