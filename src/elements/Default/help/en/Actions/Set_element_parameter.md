# Set element parameter

The action **Set element parameter** changes one parameter of an element while the flow runs. The element can belong to the flow of this action or to another flow.

## Settings

### Which flow

Tick **This flow** to change an element of the flow that contains this action. Untick it to choose another flow.

### Which element

Choose the element whose parameter should change. Every element of the flow is listed with its ID and its name.

### Which parameter

Choose the parameter of that element. The list shows the parameters of the element's class.

### New value

After the parameter is chosen, the one control of the new value that fits the parameter is enabled. The value is evaluated the same way as the value of any other parameter, and then stored.

## Remarks

- The change is an edit of the flow. It is saved automatically, and an open editor of that flow shows it.
- The new value takes effect the next time the changed element starts. An instance that is running keeps the value it started with.
- If a trigger is changed, it is armed again with the new parameter, as far as it was enabled.
- If the element has its standard name, its name is generated again.
- The action ends with an exception when the flow, the element or the parameter does not exist.
- Differences from AutoHotFlow v1 are listed in `doc/MIGRATION.md` (M-0160 to M-0162).
