# Get shortcut information

The action **Get shortcut information** retrieves information about a shortcut (.lnk) file, such as its target file.

## Settings

### Shortcut path

The path of the shortcut file to be analyzed. Be sure to include the `.lnk` extension.

### Output variables

Names of the variables that will contain the retrieved informations. The fields may be empty, if those informations are not required.

Target path: The shortcut's target (not including any arguments it might have)

Target arguments: The shortcut's parameters (blank if none).

Working directory: The shortcut's working directory.

Description: The shortcut's comments (blank if none).

Icon path: The filename of the shortcut's icon (blank if none).

Icon number: The the shortcut's icon number within the icon file (blank if none). This value is most often 1, which means the first icon.

**Run mode**: The shortcut's initial launch state, which is one of the following strings: `Normal`, `Maximized`, `Minimized`.
