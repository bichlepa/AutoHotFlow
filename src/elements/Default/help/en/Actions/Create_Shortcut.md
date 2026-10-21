# Create shortcut

The action **Create shortcut** creates a shortcut (.lnk) file.

## Settings

### Shortcut path

The path of the shortcut file. Be sure to include the `.lnk` extension.

The destination directory must already exist. If the file already exists, it will be overwritten.

### Target path

Name of the file that the shortcut refers to, which should include an absolute path unless the file is integrated with the system (e.g. Notepad.exe).

The file does not have to exist at the time the shortcut is created; however, if it does not, some systems might alter the path in unexpected ways.

### Target arguments

Parameters that will be passed to target when it is launched. Separate parameters with spaces. If a parameter contains spaces, enclose it in double quotes.

### Working directory

Directory that will become target's current working directory when the shortcut is launched. If blank or omitted, the shortcut will have a blank "Start in" field and the system will provide a default working directory when the shortcut is launched.

### Description

Comments that describe the shortcut (used by the OS to display a tooltip, etc.)

### Icon path

The full path and name of the icon to be displayed for LinkFile. It must either be an ico file, an EXE or DLL.

To use an icon in IconFile other than the first, check **Set icon number** and specify that number. For example, 2 is the second icon.

### Run mode

Launch Target may be launched minimized or maximized.
