# Select file

The action **Select file** shows the standard file dialog. The user chooses one file, or several files when **Allow to select multiple files** is checked. The chosen path goes into the output variable.

## Settings

### Output variable name

The name of the variable that receives the result: the full path of the file. With **Allow to select multiple files** the result is a list of the full paths.

### Prompt

The text of the window title.

### Root directory

The file or folder that is preselected when the dialog appears. A relative path is taken from the working directory of AutoHotFlow.

### Filter

The types of files the dialog shows, for example `Documents (*.txt)`. The default shows all files.

### Options

- **Allow to select multiple files**: the user can choose several files. The result is a list. A Save button is then not possible, so **'Save' button** is disabled.
- **'Save' button instead of an 'Open' button**: the dialog offers Save instead of Open.
- **File must exist**: the chosen file must exist. Disabled together with the Save button.
- **Path must exist**: the folder of the chosen file must exist.
- **Prompt to create new file**: the user is asked when a file that does not exist is chosen.
- **Prompt to overwrite file**: the user is asked before an existing file is replaced.
- **Don't resolve shortcuts to their targets**: a shortcut file is returned as it is, not as its target.

## Results

- The user chooses a file: the output variable holds its path, and the action ends normally.
- The user cancels the dialog: the action ends with the exception "User dismissed the dialog without selecting a file or system refused to show the dialog."

The output variable is not changed in that case.
