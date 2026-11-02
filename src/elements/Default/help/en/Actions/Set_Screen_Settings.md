# Set screen settings

The action **Set screen settings** changes some attributes of a screen.

## Settings

### Which monitor

Select a screen.

If your computer has only one screen, specify 1.

### Brightness

If **Change brightness** is checked, the brightness will be set to the specified value.

### Contrast

If **Change contrast** is checked, the contrast will be set to the specified value.

### Color gain

If **Change red gain**, **Change green gain** or **Change blue gain** is checked, the gain value of the chosen color will be specified. For example if the red value is higher than the other values, the screen will become reddish.

> **Warning:** Be careful. If specifying the value 0 for each color, some monitors might become black.

### Color drive

If **Change red drive**, **Change green drive** or **Change blue drive** is checked, the drive value of the chosen color will be specified.

The color drive is similar to the color gain but somehow different.

### Color temperature

If **Change color temperature** is checked, the color temperature will be set to the specified value. If **Color temperature** and **Color gain** are set in one action, first the color gain and drive will be set and then the color temperature. Mostly the color temperature is a preset for each color gain and drive, therefore it will not make sense to set the color gain and drive and the color temperature in one action.

## Remarks

The settings are changed through DDC/CI, the same way as the settings of the action Get screen settings. Not every monitor supports them; for such a monitor the action ends with an exception that names the setting. The monitors are changed one after the other.

The choice "11500 K." is written "115000 K." in v1 (MIGRATION M-0173).
