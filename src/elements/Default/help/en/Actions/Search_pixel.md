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

There are two searching methods.

If **Fast method** is selected, this action uses a faster searching method that in most cases dramatically reduces the amount of CPU time used by the search. Although color depths as low as 8-bit (256-color) are supported, the fast mode performs much better in 24-bit or 32-bit color.

If the screen's color depth is 16-bit or lower, the Variation parameter might behave slightly differently in fast mode than it does in slow mode.

Finally, the fast mode searches the screen row by row (top down) instead of column by column. Therefore, it might find a different pixel than that of the slow mode if there is more than one matching pixel.

Slow mode only: By default, the search starts at the upper-left pixel of the region and checks all pixels vertically beneath it for a match. If no match is found there, the search continues to the right, column by column, until it finds a matching pixel. The default left-to-right search order can be inverted by swapping X1 and X2 in the parameter list. In other words, if X1 is greater than X2, the search will be conducted from right to left, starting at column X1. Similarly, if Y1 is greater than Y2, each column of pixels to be searched starting at the bottom rather than the top. Finally, if the region to be searched is large and the search is repeated with high frequency, it may consume a lot of CPU time. To alleviate this, keep the size of the area to a minimum.
