# Sleep

The action **Sleep** waits for a given time, then ends with the result **normal**. While it waits, other instances of the flow keep running.

## Settings

### Duration

The time to wait, as an expression (see [Variables and expressions](../../../../../../assets/help/en/Variables.md)). It must be a number of 0 or more; otherwise the action ends with an exception.

### Unit

The unit of the duration: **Milliseconds**, **Seconds** (the default) or **Minutes**.
