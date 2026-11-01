# Get mouse position

The action **Get mouse position** stores the position of the mouse in two variables. It can also store the window and the control under the mouse.

## Settings

### Output variables

**Coordinates**: the names of the variables for the x and the y coordinate.

**Mouse position**: the reference point of the coordinates: the screen, the active window (its position) or the client area of the active window.

### Additional information

**Get window ID beneath the mouse**: the handle of the window under the mouse is stored in the variable of the next field.

**Get control ID beneath the mouse**: the handle of the control under the mouse is stored in the variable of the next field. The handle is a number; it can be used with the actions for controls of a window.

## Remarks

The action reads the position only. It does not move the mouse.
