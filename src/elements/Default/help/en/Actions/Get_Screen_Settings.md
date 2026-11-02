# Get screen settings

The action **Get screen settings** retrieves some attributes of a screen.

## Settings

### Which screen

Select a screen.

If your computer has only one screen, specify 1.

### Output variables

Name of the variables which will contain the retrieved settings. If a attribute is not needed, the corresponding field can be left empty.

## Remarks

The settings are the brightness, the contrast, the gain and the drive of the red, green and blue channel, and the colour temperature, as the monitor reports them with DDC/CI. Each value is stored with its minimum and maximum where the monitor has them; the colour temperature has only the current value.

Not every monitor supports DDC/CI and these settings. For such a monitor the action ends with an exception that names the setting. The resolution, the colour depth and the orientation are not read.

An output variable whose name is empty is not set (MIGRATION M-0173).
