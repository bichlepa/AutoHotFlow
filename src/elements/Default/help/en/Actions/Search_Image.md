# Search image

The action **Search image** searches a region of the screen for an image.

This action can be used to detect graphical objects on the screen that either lack text or whose text cannot be easily retrieved. For example, it can be used to discover the position of picture buttons, icons, web page links, or game objects.

Once located, such objects can be clicked via action Click.

## Settings

### Output variables

Name of the variables which will contain the position (upper left corner) of the found image.

The coordinates are affected by the setting **Screen region → Relative to**.

### Screen region

Specify the rectangle region where the image should be found.

The position can be specified relatively to screen, window or window client. This setting affects both, the coordinates of the screen region and the result coordinates.

Optionally the whole screen or window can be specified as search area.

The region to be searched must be visible; in other words, it is not possible to search a region of a window hidden behind another window. By contrast, images that lie partially beneath the mouse cursor can usually be detected. The exception to this is game cursors, which in most cases will obstruct any images beneath them.

### Image file path

Name and path of the file which contains an image.

The file path is assumed to be in the working directory if an absolute path isn't specified.

Supported file formats are GIF, JPG, BMP, ICO, CUR, ANI, PNG, TIF, Exif, WMF, and EMF images (BMP images must be 16-bit or higher). Other sources of icons include the following types of files: EXE, DLL, CPL, SCR, and other types that contain icon resources.

### File with multiple icons

This option can be used if a file is used, which contains more than one icon. Enter here the icon number.

### Variation

Specify a number between 0 and 255 to indicate the allowed number of shades of variation in either direction for the intensity of the red, green, and blue components of each pixel's color. For example, 2 would allow two shades of variation.

This parameter is helpful if the coloring of the image varies slightly or if the image file uses a format such as GIF or JPG that does not accurately represent an image on the screen.

If you specify 255 shades of variation, all colors will match. The default is 0 shades.

### Transparent color

This option makes it easier to find a match by specifying one color within the image that will match any color on the screen.

It is most commonly used to find PNG, GIF, and TIF files that have some transparent areas (however, icons do not need this option because their transparency is automatically supported).

For GIF files, White might be most likely to work. For PNG and TIF files, Black might be best. Otherwise, specify some other color name or RGB value (see the color chart for guidance, use action Get pixel color or click on Choose color). Examples: Black, FFFFAA, 0xFFFFAA.

### Scale image

Width and height to which to scale the image (this width and height also determines which icon to load from a multi-icon .ICO file).

If **Scale image** is not selected, icons loaded from ICO, DLL, or EXE files are scaled to the system's default small-icon size, which is usually 16 by 16 (you can force the actual/internal size to be used by specifying the width and height).

Images that are not icons are loaded at their actual size.

To shrink or enlarge the image while preserving its aspect ratio, select **Preserve aspect ratio** and specify either the width or the height.

## Remarks

To be a match, an image on the screen must be the same size as the one loaded from file and the Scale image options.

Since the search starts at the top row of the region and moves downward, if there is more than one match, the one closest to the top will be found.

Icons containing a transparent color automatically allow that color to match any color on the screen. Therefore, the color of what lies behind the icon does not matter.

The search behavior may vary depending on the display adapter's color depth (especially for GIF and JPG files). Therefore, if a script will run under multiple color depths, it is best to test it on each depth setting. You can use the Variation option to help make the behavior consistent across multiple color depths.

If the image on the screen is translucent, ImageSearch will probably fail to find it. To work around this, try the **Variation** option.
