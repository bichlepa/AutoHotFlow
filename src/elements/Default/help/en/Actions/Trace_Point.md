# Trace point

The action **Trace point** marks a place in the flow. It is used to debug a flow: the action **Trace point check** can later test which trace points have been passed.

A trace point can also write a log message, and it can stop the instance when a condition is true.

## Settings

### ID

The ID of the trace point. Choose any text: the action **Trace point check** lists the trace points by this ID and the ID of their element.

### Log message

A message that is written to the log when the trace point is passed. This field can be left empty.

### Stop condition

An expression. If it is true when the trace point is passed, the instance is stopped with all its threads, and the log names the condition as it is written. This field can be left empty.
