# Search pixel

The action **Search pixel** searches a region of the screen for a pixel of the specified color.

## Settings

### Screen region

Specify the rectangle region where the pixel should be found.

The position can be specified relatively to screen, window or window client. This setting affects both, the coordinates of the screen region and the result coordinates.

Optionally the whole screen or window can be specified as search area.

The region to be searched must be visible; in other words, it is not possible to search a region of a window hidden behind another window. By contrast, pixels that lie partially beneath the mouse cursor can usually be detected. The exception to this is game cursors, which in most cases will obstruct any images beneath them.

### Pixel color

The decimal or hexadecimal color ID to search for, in Red-Green-Blue (RGB) format. For example: 0x9d6346.

The color ID can be determined either by using wizard **Choose color** or **Get color from screen**.

### Variation

Specify a number between 0 and 255 to indicate the allowed number of shades of variation in either direction for the intensity of the red, green, and blue components of the pixel's color. For example, 2 would allow two shades of variation.

This parameter is helpful to find a pixel which has not exact the same color as the specified one.

If you specify 255 shades of variation, all colors will match. The default is 0 shades.

### Method

**Fast method** has no effect in AutoHotFlow v2: AutoHotkey v2 has no fast mode. The checkbox is kept so that flows keep their setting (MIGRATION M-0169).

The search starts at the upper left corner of the region and goes row by row, from left to right, down to the lower right corner (AutoHotkey v2). If there are several matching pixels, the first one in this order is found. The v1 slow mode searched column by column, so with several matches a different pixel may be found than in v1.

The region must be visible on the screen. Keep it as small as the task allows, because a large region that is searched often uses much CPU time.
