# Get pixel color

The action **Get pixel color** retrieves the color of the pixel at the specified coordinates.

## Settings

### Output variables

Name of the variables which will contain the color of the pixel.

You can choose whether a variable should contain the RGB value of the color or whether three variables will contain a value between 0 and 255 for each color. Or both.

### Position

Specify the coordinates of the pixel which color will be retrieved.

You can choose the reference point of the coordinates.

### Method

There are three methods to get the pixel color.

This parameter may be changed if this action does not produce accurate result for the desired application.

## Remarks

The pixel must be visible; in other words, it is not possible to retrieve the pixel color of a window hidden behind another window. By contrast, pixels beneath the mouse cursor can usually be detected. The exception to this is game cursors, which in most cases will hide any pixels beneath them.
