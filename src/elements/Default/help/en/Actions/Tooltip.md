# Tooltip

The action **Tooltip** shows a tooltip with a message for a given time.

## Settings

### Text to show

The message. The text may be an object, which is shown as JSON.

### Duration

How long the tooltip is shown: a number in milliseconds, seconds or minutes (choose the unit next to the field; the default is 2 seconds).

### Follow mouse

If checked, the tooltip moves with the mouse. If not, it stays at its position.

## Remarks

The action ends at once; the tooltip is removed when its duration has run out. A tooltip that is shown when another tooltip is shown replaces it. Stopping the flow does not remove a tooltip that is already shown.
